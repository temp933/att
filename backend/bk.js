require("dotenv").config();
const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const multer = require("multer");
const Anthropic = require("@anthropic-ai/sdk");
const NodeCache = require("node-cache");
const storage = multer.memoryStorage();
const axios = require("axios");
const FormData = require("form-data");
const cron = require("node-cron");
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });
const NGROK_URL =
  process.env.NGROK_URL || "https://unrivaled-headset-unmanaged.ngrok-free.dev";

const allowedOrigins = [NGROK_URL].filter(Boolean);
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const app = express();
app.use(express.json());

app.use(
  cors({
    origin: function (origin, callback) {
      if (!origin) return callback(null, true);
      if (
        origin.startsWith("http://localhost") ||
        origin.startsWith("http://127.0.0.1")
      ) {
        return callback(null, true);
      }
      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error("CORS not allowed: " + origin));
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "ngrok-skip-browser-warning",
    ],
  }),
);

// ─── DATABASE ─────────────────────────────────────────
const db = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASS || "2026",
  database: process.env.DB_NAME || "kavidhan",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

function dbRun(sql, params = []) {
  return new Promise((resolve, reject) =>
    db.query(sql, params, (err, result) =>
      err ? reject(err) : resolve(result),
    ),
  );
}
function dbGet(sql, params = []) {
  return new Promise((resolve, reject) =>
    db.query(sql, params, (err, rows) =>
      err ? reject(err) : resolve(rows[0] || null),
    ),
  );
}
function dbAll(sql, params = []) {
  return new Promise((resolve, reject) =>
    db.query(sql, params, (err, rows) => (err ? reject(err) : resolve(rows))),
  );
}

db.getConnection((err) => {
  if (err) {
    console.error("DB connection error:", err);
    process.exit(1);
  }
  console.log("MySQL connected!");
});

// ─── HEALTH CHECK ─────────────────────────────────────────────────────────────
app.get("/", (req, res) => res.json({ ok: true, time: new Date() }));

// ─── UPLOAD EMPLOYEE PHOTO ────────────────────────────────────────────────────
app.post(
  "/employees/:empId/photo",
  upload.single("photo"),
  async (req, res) => {
    if (!req.file)
      return res
        .status(400)
        .json({ success: false, message: "No file uploaded" });
    try {
      const result = await dbRun(
        `UPDATE employee_master SET profile_photo = ?, profile_photo_mime = ? WHERE emp_id = ?`,
        [req.file.buffer, req.file.mimetype, req.params.empId],
      );
      if (result.affectedRows === 0)
        return res
          .status(404)
          .json({ success: false, message: "Employee not found" });
      res.json({ success: true, message: "Photo saved to employee record" });
    } catch (err) {
      res.status(500).json({ success: false, message: err.message });
    }
  },
);

// ─── GET EMPLOYEE PHOTO ───────────────────────────────────────────────────────
app.get("/employees/:empId/photo", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT profile_photo, profile_photo_mime FROM employee_master WHERE emp_id = ?`,
      [req.params.empId],
    );
    if (!row || !row.profile_photo)
      return res
        .status(404)
        .json({ success: false, message: "No photo found" });
    res.set("Content-Type", row.profile_photo_mime || "image/jpeg");
    res.send(row.profile_photo);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── UPLOAD PHOTO FOR PENDING REQUEST ────────────────────────────────────────
app.post(
  "/pending-request/:requestId/photo",
  upload.single("photo"),
  async (req, res) => {
    if (!req.file)
      return res
        .status(400)
        .json({ success: false, message: "No file uploaded" });
    try {
      await dbRun(
        `UPDATE employee_pending_request 
         SET profile_photo = ?, profile_photo_mime = ? 
         WHERE request_id = ?`,
        [req.file.buffer, req.file.mimetype, req.params.requestId],
      );
      res.json({ success: true, message: "Photo saved to pending request" });
    } catch (err) {
      res.status(500).json({ success: false, message: err.message });
    }
  },
);

// ─── GET PHOTO FROM PENDING REQUEST ──────────────────────────────────────────
app.get("/pending-request/:requestId/photo", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT profile_photo, profile_photo_mime 
       FROM employee_pending_request 
       WHERE request_id = ?`,
      [req.params.requestId],
    );
    if (!row || !row.profile_photo) {
      return res.status(404).json({ message: "No photo found" });
    }
    res.set("Content-Type", row.profile_photo_mime || "image/jpeg");
    res.send(row.profile_photo);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ─── VERIFY FACE FOR ATTENDANCE ───────────────────────────────────────────────
app.post(
  "/attendance/verify-face",
  upload.single("photo"),
  async (req, res) => {
    const { employee_id } = req.body;
    if (!employee_id || !req.file)
      return res
        .status(400)
        .json({ success: false, message: "employee_id and photo required" });

    try {
      // ✅ Send emp_id + live photo to Python /compare
      // Python will fetch the stored embedding from DB by emp_id itself
      const form = new FormData();
      form.append("file", req.file.buffer, {
        filename: "live.jpg",
        contentType: req.file.mimetype || "image/jpeg",
      });
      form.append("emp_id", employee_id.toString());

      const response = await axios.post("http://127.0.0.1:8000/compare", form, {
        headers: form.getHeaders(),
        timeout: 15000,
      });

      const result = response.data;

      res.json({
        success: true,
        match: result.match ?? false,
        confidence: result.confidence ?? 0,
        distance: result.distance ?? null,
        emp_name: result.emp_name ?? "",
        reason: result.reason ?? "",
      });
    } catch (err) {
      console.error("[verify-face]", err.message);
      res.status(500).json({ success: false, message: err.message });
    }
  },
);

// ─── CANCEL SESSION ───────────────────────────────────────────────────────────
app.delete("/attendance/cancel-session", async (req, res) => {
  const { employee_id, session_id } = req.body;
  if (!employee_id || !session_id)
    return res
      .status(400)
      .json({ message: "employee_id and session_id required" });

  try {
    await dbRun(
      `UPDATE employee_site_attendance
       SET out_time = NOW(), updated_at = NOW(), status = 'cancelled'
       WHERE employee_id = ? AND session_id = ? AND out_time IS NULL`,
      [employee_id, session_id],
    );
    await dbRun(
      `DELETE FROM tracking_sessions
       WHERE id = ? AND employee_id = ? AND ended_at IS NULL`,
      [session_id, employee_id],
    );
    res.json({ success: true, message: "Session cancelled and deleted" });
  } catch (err) {
    console.error("[cancel-session]", err);
    res.status(500).json({ message: "Database error" });
  }
});

// ─── LATE ENTRY CALCULATION ───────────────────────────────────────────────────
function calcLateEntry(startedAt) {
  const date = new Date(startedAt);
  const istDate = new Date(
    date.toLocaleString("en-US", { timeZone: "Asia/Kolkata" }),
  );
  const cutoff = new Date(istDate);
  cutoff.setHours(9, 0, 0, 0);

  if (istDate <= cutoff) {
    return {
      isLate: false,
      lateMinutes: 0,
      lateHoursDecimal: 0,
      lateHoursFormatted: null,
    };
  }

  const lateMinutes = Math.floor((istDate - cutoff) / (1000 * 60));
  const lateHoursDecimal = +(lateMinutes / 60).toFixed(2);
  const hours = Math.floor(lateMinutes / 60);
  const mins = lateMinutes % 60;
  let lateHoursFormatted =
    lateMinutes < 60
      ? `${lateMinutes} min`
      : mins === 0
        ? `${hours}hr`
        : `${hours}hr ${mins}min`;

  return { isLate: true, lateMinutes, lateHoursDecimal, lateHoursFormatted };
}

// ─── AUTH ─────────────────────────────────────────────────────────────────────
app.post("/auth/login", handleLogin);
app.post("/login", handleLogin);

async function handleLogin(req, res) {
  try {
    const loginId = req.body.login_id || req.body.username;
    const { password, device_id, device_info } = req.body;
    const ip =
      (req.headers["x-forwarded-for"] || "").split(",")[0].trim() ||
      req.socket?.remoteAddress ||
      "unknown";

    if (!loginId || !password)
      return res.status(400).json({
        success: false,
        message: "Username and password are required",
      });

    const user = await dbGet(
      `SELECT login_id, emp_id, role_id, username, password,
              is_first_login, status, session_token, session_device,
              device_logged_in, failed_attempts, locked_until, last_login_at
       FROM login_master
       WHERE TRIM(LOWER(username)) = TRIM(LOWER(?))`,
      [loginId],
    );

    if (!user) {
      await _auditLog(
        null,
        loginId,
        "FAILED",
        ip,
        device_info,
        "Unknown username",
      );
      return res
        .status(401)
        .json({ success: false, message: "Invalid username or password" });
    }

    if (user.status !== "Active") {
      await _auditLog(
        user.emp_id,
        loginId,
        "FAILED",
        ip,
        device_info,
        "Account inactive",
      );
      return res.status(403).json({
        success: false,
        message: "Account is inactive. Contact your admin.",
      });
    }

    if (user.locked_until && new Date(user.locked_until) > new Date()) {
      const mins = Math.ceil(
        (new Date(user.locked_until) - new Date()) / 60000,
      );
      await _auditLog(
        user.emp_id,
        loginId,
        "FAILED",
        ip,
        device_info,
        "Account locked",
      );
      return res.status(403).json({
        success: false,
        message: `Account locked. Try again in ${mins} minute(s).`,
      });
    }

    const passwordOk = user.password.startsWith("$2")
      ? await bcrypt.compare(password, user.password)
      : password === user.password;

    if (!passwordOk) {
      const attempts = (user.failed_attempts || 0) + 1;
      const MAX = 5,
        LOCK_MIN = 15;
      if (attempts >= MAX) {
        const lockUntil = new Date(Date.now() + LOCK_MIN * 60000);
        await dbRun(
          `UPDATE login_master SET failed_attempts=?, locked_until=?, updated_at=NOW() WHERE login_id=?`,
          [attempts, lockUntil, user.login_id],
        );
        await _auditLog(
          user.emp_id,
          loginId,
          "FAILED",
          ip,
          device_info,
          `Wrong password – locked ${LOCK_MIN}m`,
        );
        return res.status(403).json({
          success: false,
          message: `Too many failed attempts. Account locked for ${LOCK_MIN} minutes.`,
        });
      }
      await dbRun(
        `UPDATE login_master SET failed_attempts=?, updated_at=NOW() WHERE login_id=?`,
        [attempts, user.login_id],
      );
      await _auditLog(
        user.emp_id,
        loginId,
        "FAILED",
        ip,
        device_info,
        `Wrong password (${attempts}/${MAX})`,
      );
      return res.status(401).json({
        success: false,
        message: `Invalid username or password. ${MAX - attempts} attempt(s) remaining.`,
        attemptsRemaining: MAX - attempts,
      });
    }

    const incomingDeviceId = device_info?.deviceId || device_id || "unknown";
    let existingDeviceId = null;
    if (user.session_device) {
      try {
        existingDeviceId = JSON.parse(user.session_device).deviceId || null;
      } catch {
        existingDeviceId = user.session_device;
      }
    }

    if (
      user.session_token &&
      user.device_logged_in === 1 &&
      existingDeviceId &&
      existingDeviceId !== incomingDeviceId
    ) {
      const ageHours = user.last_login_at
        ? (Date.now() - new Date(user.last_login_at).getTime()) / 3600000
        : 0;
      if (ageHours < 8) {
        let display = "another device";
        try {
          const d = JSON.parse(user.session_device);
          display = `${d.brand || ""} ${d.model || ""}`.trim() || display;
        } catch {}
        await _auditLog(
          user.emp_id,
          loginId,
          "FAILED",
          ip,
          device_info,
          `Already logged in on ${display}`,
        );
        return res.status(403).json({
          success: false,
          alreadyLoggedIn: true,
          message:
            "You are already logged in on another device. Please logout first.",
          deviceInfo: display,
        });
      }
    }

    let finalHash = user.password;
    if (!user.password.startsWith("$2")) {
      finalHash = await bcrypt.hash(password, 10);
    }

    const sessionToken = crypto.randomUUID();
    const deviceJson = device_info
      ? JSON.stringify({
          brand: device_info.brand || "Unknown",
          model: device_info.model || "Unknown",
          os: device_info.os || "Unknown",
          osVersion: device_info.osVersion || "",
          deviceId: incomingDeviceId,
        })
      : incomingDeviceId;

    await dbRun(
      `UPDATE login_master
       SET session_token=?, session_device=?, device_logged_in=1,
           last_login_at=NOW(), failed_attempts=0, locked_until=NULL,
           password=?, updated_at=NOW()
       WHERE login_id=?`,
      [sessionToken, deviceJson, finalHash, user.login_id],
    );

    await _auditLog(
      user.emp_id,
      user.username,
      "SUCCESS",
      ip,
      device_info,
      null,
    );

    if (user.is_first_login) {
      return res.json({
        success: true,
        firstLogin: true,
        message: "Please change your password before continuing.",
        loginId: user.login_id,
        empId: user.emp_id,
        roleId: user.role_id,
        username: user.username.trim(),
      });
    }

    return res.json({
      success: true,
      firstLogin: false,
      loginId: user.login_id,
      empId: user.emp_id,
      roleId: user.role_id,
      username: user.username.trim(),
      sessionToken,
    });
  } catch (err) {
    console.error("[Login]", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
}

function parseDeviceInfo(raw) {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return {
      brand: parsed.brand || "Unknown",
      model: parsed.model || "Unknown",
      os: parsed.os || "Unknown",
      osVersion: parsed.osVersion || "",
      deviceId: parsed.deviceId || raw,
      displayName:
        [
          parsed.brand && parsed.brand !== "Unknown" ? parsed.brand : null,
          parsed.model && parsed.model !== "Unknown" ? parsed.model : null,
        ]
          .filter(Boolean)
          .join(" ") || "Unknown Device",
      osDisplay:
        [
          parsed.os && parsed.os !== "Unknown" ? parsed.os : null,
          parsed.osVersion || null,
        ]
          .filter(Boolean)
          .join(" ") || null,
    };
  } catch {
    return {
      brand: "Unknown",
      model: raw,
      os: "Unknown",
      osVersion: "",
      deviceId: raw,
      displayName: raw,
      osDisplay: null,
    };
  }
}

// ─── LOGOUT ──────────────────────────────────────────────────────────────────
app.post("/auth/logout", async (req, res) => {
  const { login_id } = req.body;
  if (!login_id) return res.status(400).json({ message: "login_id required" });
  try {
    const user = await dbGet(
      `SELECT emp_id, username FROM login_master WHERE login_id=?`,
      [login_id],
    );
    await dbRun(
      `UPDATE login_master
       SET session_token=NULL, session_device=NULL, device_logged_in=0, updated_at=NOW()
       WHERE login_id=?`,
      [login_id],
    );
    if (user)
      await _auditLog(
        user.emp_id,
        user.username,
        "LOGOUT",
        "manual",
        null,
        null,
      );
    res.json({ success: true, message: "Logged out successfully" });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
});

// ─── VALIDATE SESSION ─────────────────────────────────────────────────────────
app.post("/auth/validate-session", async (req, res) => {
  const { login_id, session_token } = req.body;
  if (!login_id || !session_token)
    return res.json({ valid: false, expired: true });

  try {
    const user = await dbGet(
      `SELECT session_token, session_device, device_logged_in, locked_until, status
       FROM login_master WHERE login_id = ?`,
      [login_id],
    );

    if (!user || user.status !== "Active")
      return res.json({ valid: false, expired: true });

    if (!user.session_token || user.device_logged_in === 0)
      return res.json({ valid: false, force_logout: true });

    if (user.session_token !== session_token)
      return res.json({ valid: false, expired: true });

    res.json({ valid: true });
  } catch (err) {
    res.status(500).json({ valid: false, message: err.message });
  }
});

app.get("/login", (req, res) =>
  res.send("Login API is live. Use POST method."),
);

app.get("/login-user/:loginId", async (req, res) => {
  try {
    const u = await dbGet(
      `SELECT lm.emp_id, lm.username, r.role_name,
          CONCAT(e.first_name,
            CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != ''
              THEN CONCAT(' ', e.mid_name) ELSE '' END,
            ' ', e.last_name) AS full_name
       FROM login_master lm
       LEFT JOIN employee_master e  ON lm.emp_id  = e.emp_id
       LEFT JOIN role_master     r  ON lm.role_id = r.role_id
       WHERE lm.login_id = ?`,
      [req.params.loginId],
    );
    if (!u)
      return res.status(404).json({ success: false, message: "Not found" });
    res.json({
      success: true,
      login_id: req.params.loginId,
      emp_id: u.emp_id,
      full_name: u.full_name?.trim() || u.username,
      role_name: u.role_name || "-",
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── ROLES ────────────────────────────────────────────────────────────────────
app.get("/roles", async (req, res) => {
  try {
    const rows = await dbAll(
      "SELECT role_id AS id, role_name AS name FROM role_master ORDER BY role_name ASC",
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── EMPLOYEE ─────────────────────────────────────────────────────────────────
app.get("/employees/:empId", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT e.*, d.department_name, r.role_name,
      TRIM(CONCAT(tl.first_name, ' ', IFNULL(tl.mid_name, ''), ' ', tl.last_name)) AS tl_name,
      DATE_FORMAT(e.date_of_birth,     '%Y-%m-%d') AS date_of_birth,
      DATE_FORMAT(e.date_of_joining,   '%Y-%m-%d') AS date_of_joining,
      DATE_FORMAT(e.date_of_relieving, '%Y-%m-%d') AS date_of_relieving
   FROM employee_master e
   LEFT JOIN department_master d  ON e.department_id = d.department_id
   LEFT JOIN role_master r        ON e.role_id       = r.role_id
   LEFT JOIN employee_master tl   ON e.tl_id         = tl.emp_id
   WHERE e.emp_id = ?`,
      [req.params.empId],
    );
    if (!row) return res.status(404).json({ error: "Employee not found" });
    res.json(row);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── LEAVE ────────────────────────────────────────────────────────────────────
app.get("/employees/:empId/leaves", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT leave_id, emp_id, leave_type,
          DATE_FORMAT(leave_start_date, '%Y-%m-%d') AS leave_start_date,
          DATE_FORMAT(leave_end_date,   '%Y-%m-%d') AS leave_end_date,
          number_of_days, recommended_by,
          DATE_FORMAT(recommended_at, '%Y-%m-%d %H:%i:%s') AS recommended_at,
          approved_by, status, reason, cancel_reason, rejection_reason,
          DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
          DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
       FROM leave_master WHERE emp_id = ? ORDER BY leave_start_date DESC`,
      [req.params.empId],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/leave/:leaveId", async (req, res) => {
  const { leave_type, leave_start_date, leave_end_date, reason } = req.body;
  if (!leave_type || !leave_start_date || !leave_end_date)
    return res
      .status(400)
      .json({ success: false, message: "Leave type and dates required" });
  try {
    const result = await dbRun(
      `UPDATE leave_master SET leave_type=?, leave_start_date=?, leave_end_date=?,
          reason=?, updated_at=NOW()
       WHERE leave_id=? AND status='Pending_TL'`,
      [
        leave_type,
        leave_start_date,
        leave_end_date,
        reason || "",
        req.params.leaveId,
      ],
    );
    if (result.affectedRows === 0)
      return res.status(400).json({
        success: false,
        message: "Only Pending_TL leaves can be edited",
      });
    res.json({ success: true, message: "Leave updated" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/leave/:leaveId/cancel", async (req, res) => {
  const { cancel_reason } = req.body;
  if (!cancel_reason?.trim())
    return res
      .status(400)
      .json({ success: false, message: "Cancel reason required" });
  try {
    const result = await dbRun(
      `UPDATE leave_master SET status='Cancelled', cancel_reason=?
       WHERE leave_id=? AND status='Pending_TL'`,
      [cancel_reason, req.params.leaveId],
    );
    if (result.affectedRows === 0)
      return res.status(400).json({
        success: false,
        message: "Only Pending_TL leaves can be cancelled",
      });
    res.json({ success: true, message: "Leave cancelled" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

async function getCompoffBalance(empId) {
  const earned = await dbGet(
    `SELECT IFNULL(SUM(days_earned), 0) AS total 
     FROM compoff_transactions 
     WHERE emp_id = ? AND status = 'Approved' 
       AND (expiry_date IS NULL OR expiry_date >= CURDATE())`,
    [empId],
  );
  const used = await dbGet(
    `SELECT IFNULL(SUM(days_used), 0) AS total 
     FROM compoff_availed 
     WHERE emp_id = ? AND status = 'Approved'`,
    [empId],
  );
  // ✅ Also count leave_master Comp-Off usage
  const leaveUsed = await dbGet(
    `SELECT IFNULL(SUM(number_of_days), 0) AS total
     FROM leave_master
     WHERE emp_id = ? AND leave_type = 'Comp-Off' AND status = 'Approved'`,
    [empId],
  );
  const totalEarned = parseFloat(earned.total) || 0;
  const totalUsed = parseFloat(used.total) || 0;
  const totalLeaveUsed = parseFloat(leaveUsed.total) || 0;
  return {
    totalEarned,
    totalUsed: totalUsed + totalLeaveUsed,
    available: +(totalEarned - totalUsed - totalLeaveUsed).toFixed(1),
  };
}

app.post("/employees/:empId/apply-leave", async (req, res) => {
  const { empId } = req.params;
  const {
    leave_type,
    leave_start_date,
    leave_end_date,
    reason,
    is_half_day = false,
    half_day_period,
  } = req.body;

  if (!leave_type || !leave_start_date || !leave_end_date) {
    return res.status(400).json({
      success: false,
      message: "leave_type, leave_start_date, leave_end_date are required",
    });
  }

  try {
    const policy = await dbGet(
      `SELECT * FROM leave_policy WHERE leave_type = ? AND is_active = 1`,
      [leave_type],
    );

    if (!policy) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid leave type" });
    }

    const employee = await dbGet(
      `SELECT role_id FROM employee_master WHERE emp_id = ? AND status = 'Active'`,
      [empId],
    );
    if (!employee) {
      return res
        .status(404)
        .json({ success: false, message: "Employee not found" });
    }

    // ── Calculate days requested ───────────────────────────────────────────
    const requestedDays = is_half_day
      ? 0.5
      : await countWorkingDays(leave_start_date, leave_end_date);

    if (!is_half_day && requestedDays === 0) {
      return res.status(400).json({
        success: false,
        message: "Selected dates have no working days (weekends/holidays only)",
      });
    }

    // ── CASUAL / SICK: max 1 day per month ────────────────────────────────
    if (leave_type === "Casual" || leave_type === "Sick") {
      // Only 1 day (or 0.5) per month allowed
      const monthlyLimit = parseFloat(policy.monthly_limit ?? 1);

      const usedThisMonth = await dbGet(
        `SELECT IFNULL(SUM(number_of_days), 0) AS used
         FROM leave_master
         WHERE emp_id = ?
           AND leave_type = ?
           AND YEAR(leave_start_date) = YEAR(CURDATE())
           AND MONTH(leave_start_date) = MONTH(CURDATE())
           AND status NOT IN ('Cancelled', 'Rejected_By_Manager')`,
        [empId, leave_type],
      );
      const alreadyUsed = parseFloat(usedThisMonth?.used ?? 0);

      if (alreadyUsed + requestedDays > monthlyLimit) {
        return res.json({
          success: false,
          message: `Only ${monthlyLimit} day(s) of ${leave_type} leave allowed per month. You have already used ${alreadyUsed} day(s) this month.`,
          monthly_limit: monthlyLimit,
          already_used: alreadyUsed,
          requested: requestedDays,
          remaining: Math.max(monthlyLimit - alreadyUsed, 0),
        });
      }

      // Cannot apply for more than monthly limit in one shot
      if (requestedDays > monthlyLimit) {
        return res.json({
          success: false,
          message: `Cannot apply more than ${monthlyLimit} day(s) of ${leave_type} leave at once.`,
        });
      }
    }

    // ── PAID: unlimited but max 1 day per application ─────────────────────
    if (leave_type === "Paid") {
      // Paid is unlimited but restrict single application to reasonable days
      // No hard cap — just allow it through
    }

    // ── COMP-OFF: strictly cannot exceed available balance ────────────────
    if (leave_type === "Comp-Off") {
      const balRow = await dbGet(
        `SELECT IFNULL(SUM(days), 0) AS earned
         FROM compoff_transactions
         WHERE emp_id = ?
           AND type = 'EARNED'
           AND status = 'Approved'
           AND use_date IS NULL
           AND expiry_date >= CURDATE()`,
        [empId],
      );
      const available = parseFloat(balRow?.earned ?? 0);

      if (available <= 0) {
        return res.json({
          success: false,
          message: "You have no comp-off balance available.",
          available: 0,
        });
      }

      if (requestedDays > available) {
        return res.json({
          success: false,
          message: `Cannot apply for ${requestedDays} comp-off day(s). You only have ${available} day(s) available.`,
          available: available,
          requested: requestedDays,
        });
      }
    }

    // ── Determine approval status based on role ───────────────────────────
    let status;
    switch (employee.role_id) {
      case 2:
      case 3:
        status = "Pending_Manager";
        break;
      case 8:
        status = "Approved";
        break;
      default:
        status = "Pending_TL";
    }

    // ── Insert leave (number_of_days is STORED GENERATED — do not insert) ─
    await dbRun(
      `INSERT INTO leave_master
         (emp_id, leave_type, leave_start_date, leave_end_date,
          is_half_day, half_day_period, reason, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        empId,
        leave_type,
        leave_start_date,
        leave_end_date,
        is_half_day ? 1 : 0,
        is_half_day && half_day_period ? half_day_period : null,
        reason || "",
        status,
      ],
    );

    return res.json({
      success: true,
      status,
      requested_days: requestedDays,
      message:
        status === "Approved"
          ? "Leave approved successfully"
          : status === "Pending_Manager"
            ? "Leave sent to Manager for approval"
            : "Leave submitted to Team Lead for review",
    });
  } catch (err) {
    console.error("[apply-leave]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});
// ─── LEAVE PENDING TL ─────────────────────────────────────────────────────────
app.get("/leaves/pending-tl", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });

  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id = ?`,
      [login_id],
    );
    if (!tlUser || !tlUser.emp_id)
      return res
        .status(404)
        .json({ success: false, message: "TL user not found" });

    const tlEmpId = tlUser.emp_id;
    const rows = await dbAll(
      `SELECT
      l.leave_id,
      l.emp_id,
      CONCAT(e.first_name,' ',e.last_name) AS employee_name,
      d.department_name,
      r.role_name,
      l.leave_type,
      DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS leave_start_date,
      DATE_FORMAT(l.leave_end_date, '%Y-%m-%d') AS leave_end_date,
      l.number_of_days,
      l.reason,
      l.status,
      (
        SELECT IFNULL(SUM(lm2.number_of_days), 0)
        FROM leave_master lm2
        WHERE lm2.emp_id = l.emp_id
          AND lm2.leave_type = l.leave_type
          AND lm2.status = 'Approved'
      ) AS taken_days
   FROM leave_master l
   JOIN employee_master e ON l.emp_id = e.emp_id
   LEFT JOIN department_master d ON e.department_id = d.department_id
   LEFT JOIN role_master r ON e.role_id = r.role_id
   WHERE l.status = 'Pending_TL'
     AND e.tl_id = ?
   ORDER BY l.created_at ASC`,
      [tlEmpId],
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── TL ACTION ────────────────────────────────────────────────────────────────
app.put("/leave/:leaveId/tl-action", async (req, res) => {
  const { action, rejection_reason, login_id } = req.body;

  if (!action || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "action and login_id required" });
  if (!["recommend", "not_recommend"].includes(action))
    return res.status(400).json({ success: false, message: "Invalid action" });

  try {
    const user = await dbGet(
      `SELECT lm.login_id, r.role_name
       FROM login_master lm
       JOIN role_master r ON lm.role_id = r.role_id
       WHERE lm.login_id=? AND lm.status='Active'`,
      [login_id],
    );

    if (!user)
      return res.status(404).json({ success: false, message: "Invalid user" });

    const tlRoles = ["TL", "Team Lead", "Team_Lead", "TeamLead"];
    if (!tlRoles.includes(user.role_name))
      return res
        .status(403)
        .json({ success: false, message: "Only TL can action" });

    const newStatus =
      action === "recommend" ? "Pending_Manager" : "Not_Recommended_By_TL";

    await dbRun(
      `UPDATE leave_master
       SET status=?, rejection_reason=?, recommended_by=?, recommended_at=?,
           approved_by=?, updated_at=NOW()
       WHERE leave_id=? AND status='Pending_TL'`,
      [
        newStatus,
        action === "not_recommend" ? rejection_reason?.trim() : null,
        login_id,
        new Date(),
        login_id,
        req.params.leaveId,
      ],
    );

    res.json({ success: true, message: newStatus });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/leaves/pending-manager", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          l.leave_id, l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          d.department_name, r.role_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS leave_start_date,
          DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS leave_end_date,
          l.number_of_days, l.reason, l.status,
          l.recommended_by, l.recommended_at,
          IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0) AS taken_days
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       LEFT JOIN department_master d ON e.department_id = d.department_id
       LEFT JOIN role_master r       ON e.role_id       = r.role_id
       LEFT JOIN leave_master lm2
         ON lm2.emp_id = l.emp_id
        AND lm2.leave_type = l.leave_type
        AND lm2.status = 'Approved'
       WHERE l.status IN ('Pending_Manager', 'Pending_HR')
       GROUP BY l.leave_id
       ORDER BY l.created_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/leaves/pending-hr", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          l.leave_id, l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          d.department_name, r.role_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS leave_start_date,
          DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS leave_end_date,
          l.number_of_days, l.reason, l.status,
          l.recommended_by, l.recommended_at,
          IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0) AS taken_days
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       LEFT JOIN department_master d ON e.department_id = d.department_id
       LEFT JOIN role_master r       ON e.role_id       = r.role_id
       LEFT JOIN leave_master lm2
         ON lm2.emp_id = l.emp_id
        AND lm2.leave_type = l.leave_type
        AND lm2.status = 'Approved'
       WHERE l.status IN ('Pending_HR', 'Pending_Manager')
       GROUP BY l.leave_id
       ORDER BY l.recommended_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── MANAGER ACTION ───────────────────────────────────────────────────────────
app.put("/leave/:id/manager-action", async (req, res) => {
  const { status, login_id, rejection_reason } = req.body;

  if (!status || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "status and login_id required" });
  if (!["Approved", "Rejected_By_Manager"].includes(status))
    return res
      .status(400)
      .json({ success: false, message: "Invalid manager action" });
  if (
    status === "Rejected_By_Manager" &&
    (!rejection_reason || rejection_reason.trim() === "")
  )
    return res
      .status(400)
      .json({ success: false, message: "rejection_reason required" });

  try {
    const result = await dbRun(
      `UPDATE leave_master
       SET status = ?, approved_by = ?, rejection_reason = ?, updated_at = NOW()
       WHERE leave_id = ? AND status IN ('Pending_Manager', 'Pending_HR')`,
      [status, login_id, rejection_reason || null, req.params.id],
    );

    if (result.affectedRows === 0)
      return res.status(400).json({
        success: false,
        message: "Leave not found or not in pending state",
      });

    res.json({
      success: true,
      message:
        status === "Approved"
          ? "Leave approved by Manager"
          : "Leave rejected by Manager",
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── HR ACTION ────────────────────────────────────────────────────────────────
app.put("/leave/:leaveId/hr-action", async (req, res) => {
  const { status, rejection_reason, login_id } = req.body;
  if (!status || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "status and login_id required" });
  if (!["Approved", "Rejected_By_HR"].includes(status))
    return res.status(400).json({ success: false, message: "Invalid status" });

  try {
    const user = await dbGet(
      `SELECT lm.role_id FROM login_master lm WHERE lm.login_id=? AND lm.status='Active'`,
      [login_id],
    );
    if (!user)
      return res.status(404).json({ success: false, message: "Invalid user" });

    const hrRoles = await dbAll(
      `SELECT role_id FROM role_master WHERE LOWER(role_name) LIKE '%manager%' OR LOWER(role_name) LIKE '%admin%'`,
    );
    if (!hrRoles.some((r) => r.role_id === user.role_id))
      return res
        .status(403)
        .json({ success: false, message: "Only Manager/Admin can action" });

    const result = await dbRun(
      `UPDATE leave_master
       SET status=?, approved_by=?, rejection_reason=?, updated_at=NOW()
       WHERE leave_id=? AND status IN ('Pending_HR', 'Pending_Manager')`,
      [status, login_id, rejection_reason || null, req.params.leaveId],
    );
    if (result.affectedRows === 0)
      return res
        .status(400)
        .json({ success: false, message: "Leave not in pending state" });
    res.json({ success: true, message: status });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ALL PENDING LEAVES ───────────────────────────────────────────────────────
app.get("/leaves/all-pending", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          l.leave_id, l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          d.department_name, r.role_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS leave_start_date,
          DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS leave_end_date,
          CAST(l.number_of_days AS DECIMAL(4,1)) AS number_of_days,
          l.reason, l.status,
          l.recommended_by, l.recommended_at,
          lp.monthly_limit,
          lp.is_unlimited,
          CAST(IFNULL(SUM(CASE WHEN lm2.status='Approved' 
            THEN lm2.number_of_days END), 0) AS DECIMAL(4,1)) AS taken_days
       FROM leave_master l
       JOIN employee_master e      ON l.emp_id        = e.emp_id
       LEFT JOIN department_master d  ON e.department_id = d.department_id
       LEFT JOIN role_master r        ON e.role_id       = r.role_id
       LEFT JOIN leave_policy lp      ON l.leave_type    = lp.leave_type 
                                     AND lp.is_active    = 1
       LEFT JOIN leave_master lm2
         ON lm2.emp_id     = l.emp_id
        AND lm2.leave_type = l.leave_type
        AND lm2.status     = 'Approved'
       WHERE l.status IN ('Pending_TL', 'Pending_Manager')
       GROUP BY l.leave_id, lp.monthly_limit, lp.is_unlimited
       ORDER BY l.created_at ASC`,
    );

    // Parse decimals safely
    const data = rows.map((r) => ({
      ...r,
      number_of_days: parseFloat(r.number_of_days ?? 0),
      taken_days: parseFloat(r.taken_days ?? 0),
      monthly_limit: parseFloat(r.monthly_limit ?? 0),
      is_unlimited: r.is_unlimited === 1,
    }));

    res.json({ success: true, data });
  } catch (err) {
    console.error("[all-pending]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ADD THIS ENDPOINT TO YOUR server.js ─────────────────────────────────────
app.get("/attendance/month-report/:empId", async (req, res) => {
  const { empId } = req.params;
  const year = parseInt(req.query.year || new Date().getFullYear());
  const month = parseInt(req.query.month || new Date().getMonth() + 1);

  if (!empId || isNaN(year) || isNaN(month)) {
    return res
      .status(400)
      .json({ success: false, message: "empId, year, month required" });
  }

  try {
    // ── 1. All tracking sessions for the month (single query) ────────────
    const sessions = await dbAll(
      `SELECT
          ts.id            AS session_id,
          ts.work_date,
          ts.session_number,
          DATE_FORMAT(ts.started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
          DATE_FORMAT(ts.ended_at,   '%Y-%m-%d %H:%i:%s') AS ended_at,
          ts.is_late,
          ts.late_minutes,
          ts.late_hours_text,
          TIMESTAMPDIFF(MINUTE, ts.started_at, IFNULL(ts.ended_at, NOW())) AS session_minutes
       FROM tracking_sessions ts
       WHERE ts.employee_id = ?
         AND YEAR(ts.work_date)  = ?
         AND MONTH(ts.work_date) = ?
       ORDER BY ts.work_date ASC, ts.session_number ASC`,
      [empId, year, month],
    );

    // ── 2. All site visits for the month (single query) ──────────────────
    const visits = await dbAll(
      `SELECT
          a.id         AS visit_id,
          a.session_id,
          a.site_id,
          s.site_name,
          DATE_FORMAT(a.work_date,  '%Y-%m-%d')          AS work_date,
          DATE_FORMAT(a.in_time,    '%Y-%m-%d %H:%i:%s') AS in_time,
          DATE_FORMAT(a.out_time,   '%Y-%m-%d %H:%i:%s') AS out_time,
          a.status,
          TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS worked_minutes
       FROM employee_site_attendance a
       JOIN sites s ON a.site_id = s.id
       WHERE a.employee_id = ?
         AND YEAR(a.work_date)  = ?
         AND MONTH(a.work_date) = ?
       ORDER BY a.work_date ASC, a.in_time ASC`,
      [empId, year, month],
    );

    // ── 3. Holidays for the month ─────────────────────────────────────────
    const holidays = await dbAll(
      `SELECT
          DATE_FORMAT(holiday_date, '%Y-%m-%d') AS date,
          holiday_name,
          holiday_type
       FROM holiday_master
       WHERE YEAR(holiday_date)  = ?
         AND MONTH(holiday_date) = ?
       ORDER BY holiday_date ASC`,
      [year, month],
    );

    // ── 4. Approved/Pending leaves overlapping this month ────────────────
    const leaves = await dbAll(
      `SELECT
          DATE_FORMAT(leave_start_date, '%Y-%m-%d') AS from_date,
          DATE_FORMAT(leave_end_date,   '%Y-%m-%d') AS to_date,
          leave_type,
          number_of_days,
          status,
          is_half_day,
          half_day_period
       FROM leave_master
       WHERE emp_id = ?
         AND status IN ('Approved', 'Pending_TL', 'Pending_Manager')
         AND leave_start_date <= LAST_DAY(CONCAT(?, '-', LPAD(?, 2, '0'), '-01'))
         AND leave_end_date   >= CONCAT(?, '-', LPAD(?, 2, '0'), '-01')
       ORDER BY leave_start_date ASC`,
      [empId, year, month, year, month],
    );

    // ── 5. Comp-offs earned this month ────────────────────────────────────
    const compoffs = await dbAll(
      `SELECT
          DATE_FORMAT(work_date, '%Y-%m-%d') AS date,
          reason,
          status,
          days AS days_earned
       FROM compoff_transactions
       WHERE emp_id  = ?
         AND type    = 'EARNED'
         AND YEAR(work_date)  = ?
         AND MONTH(work_date) = ?
         AND status  = 'Approved'
       ORDER BY work_date ASC`,
      [empId, year, month],
    );

    // ── 6. Aggregate per day ──────────────────────────────────────────────
    // Group visits by session_id
    const visitsBySession = {};
    for (const v of visits) {
      const key = v.session_id ?? `nosession`;
      if (!visitsBySession[key]) visitsBySession[key] = [];
      visitsBySession[key].push(v);
    }

    // Group sessions by work_date
    const sessionsByDate = {};
    for (const s of sessions) {
      const d = String(s.started_at).slice(0, 10);
      if (!sessionsByDate[d]) sessionsByDate[d] = [];
      const sessVisits = visitsBySession[s.session_id] || [];
      const siteMinutes = sessVisits.reduce(
        (sum, v) => sum + (v.worked_minutes || 0),
        0,
      );
      sessionsByDate[d].push({
        session_id: s.session_id,
        session_number: s.session_number,
        started_at: s.started_at,
        ended_at: s.ended_at,
        session_minutes: s.session_minutes,
        site_minutes: siteMinutes,
        is_late: s.is_late === 1,
        late_minutes: s.late_minutes || 0,
        late_text: s.late_hours_text || null,
        visits: sessVisits,
      });
    }

    // Build holiday/leave/compoff maps
    const holidayMap = {};
    for (const h of holidays) holidayMap[h.date] = h;

    const compoffMap = {};
    for (const c of compoffs) compoffMap[c.date] = c;

    // Helper: check if date is in a leave range
    function getLeaveForDate(dateStr) {
      for (const l of leaves) {
        if (dateStr >= l.from_date && dateStr <= l.to_date) return l;
      }
      return null;
    }

    // ── 7. Build daily summary for entire month ───────────────────────────
    const daysInMonth = new Date(year, month, 0).getDate();
    const today = new Date().toISOString().slice(0, 10);
    const days = [];

    let presentCount = 0,
      absentCount = 0,
      lateCount = 0,
      totalOnSiteMinutes = 0,
      leaveCount = 0,
      holidayCount = 0,
      compoffCount = 0,
      weekendCount = 0;

    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = `${year}-${String(month).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
      const dayOfWeek = new Date(dateStr + "T00:00:00").getDay(); // 0=Sun
      const isSunday = dayOfWeek === 0;
      const isSaturday = dayOfWeek === 6;
      const isWeekend = isSunday;
      const isFuture = dateStr > today;
      const isToday = dateStr === today;

      const holiday = holidayMap[dateStr] || null;
      const leave = getLeaveForDate(dateStr);
      const compoff = compoffMap[dateStr] || null;
      const daySession = sessionsByDate[dateStr] || [];
      const isPresent = daySession.length > 0;

      // Calculate totals for the day
      const dayTotalMinutes = daySession.reduce(
        (s, sess) => s + (sess.site_minutes || 0),
        0,
      );
      const isLate = daySession.some((s) => s.is_late);
      const lateText = daySession.find((s) => s.late_text)?.late_text || null;
      const firstIn = daySession[0]?.started_at || null;
      const lastOut = daySession[daySession.length - 1]?.ended_at || null;

      // Determine status label
      let status;
      if (isFuture) status = "future";
      else if (compoff) status = "compoff";
      else if (isPresent) status = isLate ? "late" : "present";
      else if (isWeekend) status = "weekend";
      else if (holiday) status = "holiday";
      else if (leave) status = "leave";
      else status = "absent";

      // Count for summary (only past/today non-future days)
      if (!isFuture) {
        if (status === "present" || status === "late") {
          presentCount++;
          totalOnSiteMinutes += dayTotalMinutes;
          if (isLate) lateCount++;
        } else if (status === "absent") {
          absentCount++;
        } else if (status === "leave") {
          leaveCount++;
        } else if (status === "holiday") {
          holidayCount++;
        } else if (status === "compoff") {
          compoffCount++;
        } else if (status === "weekend") {
          weekendCount++;
        }
      }

      days.push({
        date: dateStr,
        day: d,
        day_of_week: dayOfWeek,
        is_today: isToday,
        is_future: isFuture,
        is_weekend: isWeekend,
        is_sunday: isSunday,
        is_saturday: isSaturday,
        status,
        is_present: isPresent,
        is_late: isLate,
        late_text: lateText,
        total_minutes: dayTotalMinutes,
        first_in: firstIn,
        last_out: lastOut,
        sessions: daySession,
        holiday: holiday,
        leave: leave,
        compoff: compoff,
      });
    }

    const workingDaysInMonth = days.filter(
      (d) => !d.is_future && !d.is_weekend && !d.holiday,
    ).length;

    const attendanceRate =
      presentCount + leaveCount + holidayCount + compoffCount > 0
        ? Math.round(
            (presentCount / Math.max(presentCount + absentCount, 1)) * 100,
          )
        : 0;

    res.json({
      success: true,
      year,
      month,
      summary: {
        present_days: presentCount,
        absent_days: absentCount,
        late_days: lateCount,
        leave_days: leaveCount,
        holiday_days: holidayCount,
        compoff_days: compoffCount,
        weekend_days: weekendCount,
        total_on_site_minutes: totalOnSiteMinutes,
        working_days_in_month: workingDaysInMonth,
        attendance_rate: attendanceRate,
      },
      days,
    });
  } catch (err) {
    console.error("[month-report]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});
// ─── ALL LEAVE HISTORY ────────────────────────────────────────────────────────
app.get("/leaves/all-history", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          l.leave_id, l.emp_id,
          CONCAT(e.first_name,' ',e.last_name) AS employee_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date,'%Y-%m-%d') AS from_date,
          DATE_FORMAT(l.leave_end_date,'%Y-%m-%d') AS to_date,
          l.number_of_days AS total_days,
          l.status, l.reason, l.rejection_reason, l.cancel_reason,
          DATE_FORMAT(l.created_at, '%d-%m-%Y %h:%i %p') AS created_at,
          DATE_FORMAT(l.updated_at, '%d-%m-%Y %h:%i %p') AS updated_at,
          CASE WHEN l.recommended_by IS NOT NULL
            THEN CONCAT(tl_emp.first_name,' ',tl_emp.last_name)
            ELSE NULL
          END AS recommended_by_name,
          CASE WHEN l.approved_by IS NOT NULL
            THEN CONCAT(hr_emp.first_name,' ',hr_emp.last_name)
            ELSE NULL
          END AS approved_by_name
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       LEFT JOIN login_master tl_lm   ON l.recommended_by = tl_lm.login_id
       LEFT JOIN employee_master tl_emp ON tl_lm.emp_id = tl_emp.emp_id
       LEFT JOIN login_master hr_lm   ON l.approved_by = hr_lm.login_id
       LEFT JOIN employee_master hr_emp ON hr_lm.emp_id = hr_emp.emp_id
       ORDER BY l.updated_at DESC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── LEAVE HISTORY FOR EMPLOYEE ───────────────────────────────────────────────
app.get("/leave-history", async (req, res) => {
  const { emp_id } = req.query;
  if (!emp_id)
    return res
      .status(400)
      .json({ success: false, message: "emp_id is required" });
  try {
    const rows = await dbAll(
      `SELECT l.leave_id, l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS from_date,
          DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS to_date,
          l.number_of_days AS total_days,
          l.recommended_by, l.approved_by, l.status, l.reason,
          l.rejection_reason, l.cancel_reason
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       WHERE l.emp_id = ?
       ORDER BY l.updated_at DESC`,
      [emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── TL LEAVE HISTORY ─────────────────────────────────────────────────────────
app.get("/leaves/tl-history", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });

  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id = ?`,
      [login_id],
    );
    if (!tlUser || !tlUser.emp_id)
      return res.status(404).json({ success: false, message: "TL not found" });

    const rows = await dbAll(
      `SELECT
          l.leave_id, l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          d.department_name, r.role_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS from_date,
          DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS to_date,
          l.number_of_days AS total_days,
          l.status, l.reason, l.rejection_reason, l.cancel_reason,
          CASE WHEN l.recommended_by IS NOT NULL
            THEN CONCAT(tl_emp.first_name, ' ', tl_emp.last_name)
            ELSE NULL END AS recommended_by_name,
          CASE WHEN l.approved_by IS NOT NULL
            THEN CONCAT(mgr_emp.first_name, ' ', mgr_emp.last_name)
            ELSE NULL END AS approved_by_name
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       LEFT JOIN department_master d ON e.department_id = d.department_id
       LEFT JOIN role_master r ON e.role_id = r.role_id
       LEFT JOIN login_master tl_lm ON l.recommended_by = tl_lm.login_id
       LEFT JOIN employee_master tl_emp ON tl_lm.emp_id = tl_emp.emp_id
       LEFT JOIN login_master mgr_lm ON l.approved_by = mgr_lm.login_id
       LEFT JOIN employee_master mgr_emp ON mgr_lm.emp_id = mgr_emp.emp_id
       WHERE e.tl_id = ?
       ORDER BY l.updated_at DESC`,
      [tlUser.emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── LEAVE STATUS SUMMARY ────────────────────────────────────────────────────
app.get("/leave-status-summary", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT status, COUNT(*) AS count
       FROM leave_master
       WHERE status != 'Cancelled'
       GROUP BY status`,
    );
    res.json(rows.map((r) => ({ status: r.status, count: r.count })));
  } catch (err) {
    res.status(500).json({ error: "Database error" });
  }
});

async function _autoCreateCompoff(empId, workDate) {
  try {
    // 1. Check if weekend or holiday
    const d = new Date(workDate + "T00:00:00");
    const dow = d.getDay();
    const isWeekend = dow === 0 || dow === 6;

    const holiday = await dbGet(
      `SELECT holiday_name FROM holiday_master WHERE holiday_date = ?`,
      [workDate],
    );
    const isHoliday = !!holiday;

    // Not a special day - exit
    if (!isWeekend && !isHoliday) return;

    // 2. Check if already exists (IMPORTANT!)
    const existing = await dbGet(
      `SELECT compoff_id FROM compoff_transactions 
       WHERE emp_id = ? AND worked_date = ?`,
      [empId, workDate],
    );
    if (existing) return; // Already created

    // 3. Calculate worked hours
    const hoursWorked = await dbGet(
      `SELECT SUM(TIMESTAMPDIFF(MINUTE, started_at, IFNULL(ended_at, NOW()))) / 60.0 AS hours
       FROM tracking_sessions 
       WHERE employee_id = ? AND work_date = ?`,
      [empId, workDate],
    );

    const totalHours = hoursWorked?.hours || 0;

    // 4. Check minimum hours from policy
    const policy = await getCompoffPolicy();

    let daysEarned = 0;
    if (totalHours >= policy.min_hours_for_full) {
      daysEarned = 1.0;
    } else if (totalHours >= policy.min_hours_for_half) {
      daysEarned = 0.5;
    } else {
      return; // Not enough hours worked
    }

    // 5. Determine day type
    let dayType = "Weekend";
    if (isWeekend && isHoliday) dayType = "Both";
    else if (isHoliday) dayType = "Holiday";

    // 6. Create comp-off (auto-approved)
    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + policy.expiry_days);
    const expiryStr = expiryDate.toISOString().slice(0, 10);

    const reason = isHoliday
      ? `Worked on holiday: ${holiday.holiday_name}`
      : "Worked on weekend";

    await dbRun(
      `INSERT INTO compoff_transactions
       (emp_id, worked_date, worked_hours, reason, day_type, days_earned, 
        status, expiry_date, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'Approved', ?, NOW(), NOW())`,
      [empId, workDate, totalHours, reason, dayType, daysEarned, expiryStr],
    );

    console.log(
      `[compoff] Auto-created ${daysEarned} day(s) for emp ${empId} ` +
        `on ${workDate} (${dayType}), expires ${expiryStr}`,
    );
  } catch (err) {
    console.error("[compoff] Auto-create failed:", err.message);
  }
}

// ─── TL DASHBOARD ─────────────────────────────────────────────────────────────
app.get("/dashboard/tl/:loginId", async (req, res) => {
  const today = new Date().toISOString().split("T")[0];
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id = ?`,
      [req.params.loginId],
    );
    if (!tlUser) return res.status(404).json({ error: "TL not found" });
    const tlEmpId = tlUser.emp_id;

    const [
      [{ v: totalEmployees }],
      [{ v: present }],
      [{ v: absent }],
      [{ v: onSiteToday }],
      [{ v: pendingLeaveReq }],
    ] = await Promise.all([
      dbAll(
        `SELECT COUNT(*) AS v FROM employee_master WHERE tl_id = ? AND status = 'Active'`,
        [tlEmpId],
      ),
      dbAll(
        `SELECT COUNT(DISTINCT ts.employee_id) AS v FROM tracking_sessions ts
         JOIN employee_master e ON ts.employee_id = e.emp_id
         WHERE ts.work_date = ? AND e.tl_id = ?`,
        [today, tlEmpId],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM employee_master e
         LEFT JOIN tracking_sessions ts ON e.emp_id = ts.employee_id AND ts.work_date = ?
         WHERE e.tl_id = ? AND e.status = 'Active' AND ts.id IS NULL`,
        [today, tlEmpId],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM sites WHERE start_date <= ? AND end_date >= ?`,
        [today, today],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM leave_master l
         JOIN employee_master e ON l.emp_id = e.emp_id
         WHERE l.status = 'Pending_TL' AND e.tl_id = ?`,
        [tlEmpId],
      ),
    ]);

    res.json({
      totalEmployees,
      present,
      absent,
      lateEntry: 0,
      onSiteToday,
      pendingRequests: pendingLeaveReq,
    });
  } catch (err) {
    console.error("[tl-dashboard]", err);
    res.status(500).json({ error: err.message });
  }
});

// ─── DASHBOARD ────────────────────────────────────────────────────────────────
app.get("/dashboard", async (req, res) => {
  const today = new Date().toISOString().split("T")[0];

  try {
    const [
      [{ v: totalEmployees }],
      [{ v: present }],
      [{ v: onSiteToday }],
      [{ v: pendingEmpReq }],
      [{ v: pendingLeaveReq }],
      [{ v: absent }],
      [{ v: activeSites }],
    ] = await Promise.all([
      dbAll(`SELECT COUNT(*) AS v FROM employee_master WHERE status='Active'`),
      dbAll(
        `SELECT COUNT(DISTINCT employee_id) AS v FROM employee_site_attendance WHERE work_date=?`,
        [today],
      ),
      dbAll(
        `SELECT COUNT(DISTINCT emp_id) AS v FROM employee_location_assignment
         WHERE start_date<=? AND (end_date IS NULL OR end_date>=?) AND status IN ('Active','Extended')`,
        [today, today],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM employee_pending_request WHERE admin_approve='PENDING'`,
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM leave_master
         WHERE status IN ('Pending_TL','Pending_HR','Pending_Manager') AND leave_start_date >= ?`,
        [today],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM employee_master e
         LEFT JOIN employee_site_attendance a ON e.emp_id=a.employee_id AND a.work_date=?
         WHERE e.status='Active' AND a.id IS NULL`,
        [today],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM sites WHERE start_date <= ? AND (end_date IS NULL OR end_date >= ?)`,
        [today, today],
      ),
    ]);

    res.json({
      totalEmployees,
      present,
      absent,
      onSiteToday,
      activeSites,
      pendingRequests: pendingEmpReq + pendingLeaveReq,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DEPARTMENTS ──────────────────────────────────────────────────────────────
app.get("/departments", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT department_id AS id, department_name AS name FROM department_master WHERE status='Active'`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/departments", async (req, res) => {
  const { department_name } = req.body;
  if (!department_name)
    return res
      .status(400)
      .json({ success: false, message: "Department name required" });
  try {
    const result = await dbRun(
      `INSERT INTO department_master (department_name, status, created_at, updated_at)
       VALUES (?, 'Active', NOW(), NOW())`,
      [department_name],
    );
    res.json({
      success: true,
      message: "Department added",
      department_id: result.insertId,
    });
  } catch (err) {
    if (err.code === "ER_DUP_ENTRY")
      return res
        .status(400)
        .json({ success: false, message: "Department already exists" });
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/departments/:id/status", async (req, res) => {
  const { status } = req.body;
  if (!["Active", "Inactive"].includes(status))
    return res.status(400).json({ success: false, message: "Invalid status" });
  try {
    await dbRun(
      `UPDATE department_master SET status=?, updated_at=NOW() WHERE department_id=?`,
      [status, req.params.id],
    );
    res.json({ success: true, message: `Department ${status.toLowerCase()}` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── LOCATIONS ────────────────────────────────────────────────────────────────
app.get("/locations", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT location_id, latitude, longitude, start_date, end_date,
          contact_person_name, contact_person_number, location_nick_name
       FROM location_master ORDER BY created_at DESC`,
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/locations", async (req, res) => {
  let {
    nick_name,
    latitude,
    longitude,
    start_date,
    end_date,
    contact_person_name,
    contact_person_number,
  } = req.body;

  if (!nick_name || !latitude || !longitude || !start_date)
    return res
      .status(400)
      .json({ error: "nick_name, lat, lng, start_date required" });

  latitude = parseFloat(latitude);
  longitude = parseFloat(longitude);
  if (isNaN(latitude) || latitude < -90 || latitude > 90)
    return res.status(400).json({ error: "Invalid latitude" });
  if (isNaN(longitude) || longitude < -180 || longitude > 180)
    return res.status(400).json({ error: "Invalid longitude" });

  try {
    const result = await dbRun(
      `INSERT INTO location_master
         (location_nick_name, latitude, longitude, start_date, end_date, contact_person_name, contact_person_number)
       VALUES (?,?,?,?,?,?,?)`,
      [
        nick_name.trim(),
        latitude,
        longitude,
        start_date,
        end_date || null,
        contact_person_name?.trim() || null,
        contact_person_number?.trim() || null,
      ],
    );
    res
      .status(201)
      .json({ message: "Location added", location_id: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── EMPLOYEE LOCATION ASSIGNMENT ────────────────────────────────────────────
app.get("/employee-assignments/:empId", async (req, res) => {
  const empId = parseInt(req.params.empId, 10);
  if (isNaN(empId))
    return res.status(400).json({ error: "empId must be a number" });
  try {
    const rows = await dbAll(
      `SELECT ela.assign_id, ela.emp_id,
          CONCAT(e.first_name,' ',e.last_name) AS emp_name,
          lm.location_nick_name AS location_name,
          DATE(CONVERT_TZ(ela.start_date,'+00:00','+05:30')) AS start_date,
          DATE(CONVERT_TZ(ela.end_date,  '+00:00','+05:30')) AS end_date,
          ela.about_work, ela.status, ela.reason AS extend_reason, ela.done_by,
          CASE
            WHEN ela.status='Completed' THEN 'Completed'
            WHEN ela.status='Relieved'  THEN 'Relieved'
            WHEN ela.status='Extended'  THEN 'Extended'
            WHEN DATE(CONVERT_TZ(ela.start_date,'+00:00','+05:30')) > CURDATE() THEN 'Future'
            WHEN ela.status='Active' AND DATE(CONVERT_TZ(ela.end_date,'+00:00','+05:30')) < CURDATE() THEN 'Not Completed'
            ELSE 'Working'
          END AS work_status
       FROM employee_location_assignment ela
       JOIN employee_master e  ON ela.emp_id      = e.emp_id
       JOIN location_master lm ON ela.location_id = lm.location_id
       WHERE ela.emp_id=? ORDER BY ela.start_date DESC`,
      [empId],
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/assign-location", async (req, res) => {
  const { emp_id, location_id, about_work, start_date, end_date, done_by } =
    req.body;
  try {
    await dbRun(
      `INSERT INTO employee_location_assignment (emp_id, location_id, about_work, start_date, end_date, status, done_by)
       VALUES (?,?,?,?,?,'Active',?)`,
      [emp_id, location_id, about_work, start_date, end_date, done_by],
    );
    res.json({ success: true, message: "Location assigned" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/update-work-status", async (req, res) => {
  const { empId, status, updatedBy, reason, endDate } = req.body;
  if (!empId || !status)
    return res.status(400).json({ error: "empId and status required" });

  const allowed = ["Completed", "Relieved", "Extended", "Active"];
  if (!allowed.includes(status))
    return res.status(400).json({ error: `Invalid status: ${status}` });

  let sql = `UPDATE employee_location_assignment SET status=?, reason=?, done_by=?, updated_at=NOW()`;
  const params = [status, reason || null, updatedBy || null];

  if (status === "Extended") {
    if (!endDate) return res.status(400).json({ error: "endDate required" });
    sql += `, end_date=?`;
    params.push(endDate);
  }
  sql += ` WHERE emp_id=? ORDER BY assign_id DESC LIMIT 1`;
  params.push(empId);

  try {
    const result = await dbRun(sql, params);
    if (result.affectedRows === 0)
      return res.status(404).json({ error: "No active assignment found" });
    res.json({ success: true, message: `Status updated to ${status}` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/working-today-and-future", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT a.assign_id, e.emp_id,
          CONCAT(e.first_name,' ',e.last_name) AS emp_name,
          l.location_nick_name AS location_name,
          DATE_FORMAT(a.start_date,'%Y-%m-%d') AS start_date,
          DATE_FORMAT(a.end_date,  '%Y-%m-%d') AS end_date,
          a.about_work, a.status, a.reason AS extend_reason, a.done_by,
          CASE
            WHEN a.status='Completed' THEN 'Completed'
            WHEN a.status='Relieved'  THEN 'Relieved'
            WHEN a.status='Extended'  THEN 'Extended'
            WHEN a.start_date > CURDATE() THEN 'Future'
            WHEN a.status='Active' AND a.end_date < CURDATE() THEN 'Not Completed'
            ELSE 'Working'
          END AS work_status
       FROM employee_location_assignment a
       JOIN employee_master e  ON a.emp_id      = e.emp_id
       JOIN location_master l  ON a.location_id = l.location_id
       WHERE a.status IN ('Active','Extended')
          OR (a.status='Relieved' AND a.end_date >= CURDATE())
       ORDER BY a.start_date ASC`,
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── SITES ────────────────────────────────────────────────────────────────────
app.get("/sites", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT id, site_name, polygon_json,
          DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
          DATE_FORMAT(end_date,   '%Y-%m-%d') AS end_date,
          created_at
       FROM sites`,
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.get("/on-site-today", async (req, res) => {
  try {
    const today = new Date().toISOString().split("T")[0];
    const rows = await dbAll(
      `SELECT COUNT(*) AS count FROM sites WHERE start_date <= ? AND end_date >= ?`,
      [today, today],
    );
    res.json({ onSiteToday: rows[0].count });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/sites", async (req, res) => {
  const { site_name, polygon_json, start_date, end_date } = req.body;
  if (!site_name || !polygon_json || !start_date || !end_date)
    return res.status(400).json({ message: "Missing required fields" });
  try {
    const result = await dbRun(
      `INSERT INTO sites (site_name, polygon_json, start_date, end_date) VALUES (?, ?, ?, ?)`,
      [site_name, JSON.stringify(polygon_json), start_date, end_date],
    );
    res.json({ message: "Site saved", id: result.insertId });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.put("/sites/:id", async (req, res) => {
  const { site_name, polygon_json, start_date, end_date } = req.body;
  if (!site_name || !polygon_json || !start_date || !end_date)
    return res.status(400).json({ message: "Missing required fields" });
  try {
    await dbRun(
      `UPDATE sites SET site_name=?, polygon_json=?, start_date=?, end_date=? WHERE id=?`,
      [
        site_name,
        JSON.stringify(polygon_json),
        start_date,
        end_date,
        req.params.id,
      ],
    );
    res.json({ message: "Site updated" });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.get("/sites/:id/location", async (req, res) => {
  try {
    const site = await dbGet(
      `SELECT id, site_name, polygon_json FROM sites WHERE id = ?`,
      [req.params.id],
    );
    if (!site)
      return res
        .status(404)
        .json({ success: false, message: "Site not found" });

    let lat = null,
      lng = null;
    if (site.polygon_json) {
      try {
        const polygon = JSON.parse(site.polygon_json);
        if (Array.isArray(polygon) && polygon.length > 0) {
          let sumLat = 0,
            sumLng = 0;
          polygon.forEach((point) => {
            sumLat += point.lat;
            sumLng += point.lng;
          });
          lat = sumLat / polygon.length;
          lng = sumLng / polygon.length;
        }
      } catch (parseErr) {
        console.error("[site-location] polygon parse error:", parseErr);
      }
    }

    res.json({
      success: true,
      site_id: site.id,
      site_name: site.site_name,
      lat,
      lng,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ATTENDANCE ───────────────────────────────────────────────────────────────
app.get("/attendance/status/:empId", async (req, res) => {
  try {
    const empId = parseInt(req.params.empId);
    const activeSession = await dbGet(
      `SELECT id, session_number, location_verified FROM tracking_sessions
       WHERE employee_id = ? AND work_date = CURDATE() AND ended_at IS NULL
       ORDER BY id DESC LIMIT 1`,
      [empId],
    );

    if (activeSession) {
      return res.json({
        status: "in_progress",
        session_id: activeSession.id,
        session_number: activeSession.session_number,
        location_verified: activeSession.location_verified,
      });
    }

    const { count } = (await dbGet(
      `SELECT COUNT(*) AS count FROM tracking_sessions WHERE employee_id = ? AND work_date = CURDATE()`,
      [empId],
    )) || { count: 0 };

    return res.json({ status: "not_started", sessions_today: count });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.get("/attendance/today/:empId", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          a.id, a.site_id, s.site_name,
          DATE_FORMAT(a.in_time,  '%H:%i:%s') AS in_time,
          DATE_FORMAT(a.out_time, '%H:%i:%s') AS out_time,
          a.work_date, a.status, a.session_id, ts.session_number,
          TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS duration_minutes
       FROM employee_site_attendance a
       JOIN sites s ON a.site_id = s.id
       LEFT JOIN tracking_sessions ts ON a.session_id = ts.id
       WHERE a.employee_id = ? AND a.work_date = CURDATE()
       ORDER BY a.in_time ASC`,
      [req.params.empId],
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/start-session", async (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id required" });

  try {
    const istDate = new Date(Date.now() + 5.5 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);

    await dbRun(
      `UPDATE tracking_sessions SET ended_at = NOW(), end_reason = 'app_restart'
       WHERE employee_id = ? AND work_date = ? AND ended_at IS NULL`,
      [employee_id, istDate],
    );

    const { count } = (await dbGet(
      `SELECT COUNT(*) AS count FROM tracking_sessions WHERE employee_id = ? AND work_date = ?`,
      [employee_id, istDate],
    )) || { count: 0 };

    const sessionNumber = count + 1;
    const now = new Date();
    const { isLate, lateMinutes, lateHoursDecimal, lateHoursFormatted } =
      sessionNumber === 1
        ? calcLateEntry(now)
        : {
            isLate: false,
            lateMinutes: 0,
            lateHoursDecimal: 0,
            lateHoursFormatted: null,
          };

    const result = await dbRun(
      `INSERT INTO tracking_sessions
       (employee_id, work_date, started_at, session_number, is_late, late_minutes, late_hours_decimal, late_hours_text)
       VALUES (?, ?, NOW(), ?, ?, ?, ?, ?)`,
      [
        employee_id,
        istDate,
        sessionNumber,
        isLate ? 1 : 0,
        lateMinutes,
        lateHoursDecimal,
        lateHoursFormatted,
      ],
    );
    // ✅ AFTER session INSERT (VERY IMPORTANT LOCATION)

    // ─── CHECK HOLIDAY & CREATE COMPOFF ─────────────────────────
    const holiday = await dbGet(
      `SELECT holiday_name FROM holiday_master WHERE holiday_date = ?`,
      [istDate],
    );

    // OPTIONAL: weekend check
    const day = new Date(istDate).getDay();
    const isWeekend = day === 0 || day === 6;

    if (holiday || isWeekend) {
      const dayType =
        holiday && isWeekend ? "Both" : holiday ? "Holiday" : "Weekend";

      // ❗ Prevent duplicate compoff
      const existing = await dbGet(
        `SELECT id FROM compoff_transactions
     WHERE emp_id = ? AND work_date = ? AND type='EARNED'`,
        [employee_id, istDate],
      );

      if (!existing) {
        const policy = await getCompoffPolicy();

        const expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() + policy.expiry_days);
        const expiryStr = expiryDate.toISOString().slice(0, 10);

        await dbRun(
          `INSERT INTO compoff_transactions
       (emp_id, type, days, work_date, reason, day_type, status, expiry_date)
       VALUES (?, 'EARNED', 1.0, ?, ?, ?, 'Approved', ?)`,
          [
            employee_id,
            istDate,
            holiday
              ? `Worked on holiday: ${holiday.holiday_name}`
              : "Worked on weekend",
            dayType,
            expiryStr,
          ],
        );

        console.log(
          `[COMPOFF] Created for emp ${employee_id} on ${istDate} (${dayType})`,
        );
      }
    }
    res.json({
      session_id: result.insertId,
      session_number: sessionNumber,
      location_verified: 0,
      is_late: isLate,
      late_minutes: lateMinutes,
      late_hours: lateHoursDecimal,
      late_text: lateHoursFormatted,
      message: lateHoursFormatted ?? "On time",
    });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/end-session", async (req, res) => {
  const { employee_id, session_id, reason = "manual_end" } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id required" });

  try {
    if (session_id) {
      await dbRun(
        `UPDATE employee_site_attendance
         SET out_time = NOW(), updated_at = NOW(), status = 'completed'
         WHERE employee_id = ? AND session_id = ? AND out_time IS NULL`,
        [employee_id, session_id],
      );
    } else {
      await dbRun(
        `UPDATE employee_site_attendance
         SET out_time = NOW(), updated_at = NOW(), status = 'completed'
         WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
        [employee_id],
      );
    }

    const whereClause = session_id
      ? "id = ? AND employee_id = ?"
      : "employee_id = ? AND work_date = CURDATE() AND ended_at IS NULL";
    const params = session_id
      ? [reason, session_id, employee_id]
      : [reason, employee_id];

    await dbRun(
      `UPDATE tracking_sessions SET ended_at = NOW(), end_reason = ? WHERE ${whereClause}`,
      params,
    );

    res.json({ message: "Session ended", reason });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/in", async (req, res) => {
  const { employee_id, site_id, session_id } = req.body;
  if (!employee_id || !site_id)
    return res
      .status(400)
      .json({ message: "employee_id and site_id required" });

  try {
    const site = await dbGet(
      `SELECT id FROM sites WHERE id = ? AND CURDATE() BETWEEN start_date AND end_date`,
      [site_id],
    );
    if (!site)
      return res.status(400).json({ message: "Site not active today" });

    await dbRun(
      `UPDATE employee_site_attendance
       SET out_time = NOW(), updated_at = NOW(), status = 'completed'
       WHERE employee_id = ? AND site_id != ? AND work_date = CURDATE() AND out_time IS NULL`,
      [employee_id, site_id],
    );

    const existing = session_id
      ? await dbGet(
          `SELECT id, out_time, TIMESTAMPDIFF(MINUTE, out_time, NOW()) AS minutes_since_out
           FROM employee_site_attendance
           WHERE employee_id = ? AND site_id = ? AND session_id = ? AND work_date = CURDATE()
           ORDER BY id DESC LIMIT 1`,
          [employee_id, site_id, session_id],
        )
      : null;

    if (!existing) {
      const r = await dbRun(
        `INSERT INTO employee_site_attendance (employee_id, site_id, session_id, in_time, work_date, status, updated_at)
         VALUES (?, ?, ?, NOW(), CURDATE(), 'active', NOW())`,
        [employee_id, site_id, session_id || null],
      );
      return res.json({ message: "IN marked (new)", id: r.insertId });
    }

    if (existing.out_time === null)
      return res.json({ message: "Already IN at this site", id: existing.id });

    if (
      existing.minutes_since_out !== null &&
      existing.minutes_since_out < 15
    ) {
      await dbRun(
        `UPDATE employee_site_attendance SET out_time = NULL, updated_at = NOW(), status = 'active' WHERE id = ?`,
        [existing.id],
      );
      return res.json({
        message: "IN marked (returned <15m)",
        id: existing.id,
      });
    }

    const r = await dbRun(
      `INSERT INTO employee_site_attendance (employee_id, site_id, session_id, in_time, work_date, status, updated_at)
       VALUES (?, ?, ?, NOW(), CURDATE(), 'active', NOW())`,
      [employee_id, site_id, session_id || null],
    );
    return res.json({ message: "IN marked (new row)", id: r.insertId });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/out", async (req, res) => {
  const { employee_id, session_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id required" });
  try {
    await dbRun(
      `UPDATE employee_site_attendance
       SET out_time = NOW(), updated_at = NOW(), status = 'completed'
       WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL
         ${session_id ? "AND session_id = ?" : ""}`,
      session_id ? [employee_id, session_id] : [employee_id],
    );
    res.json({ message: "OUT marked" });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/end-day", async (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id required" });

  try {
    // 1. Close all open attendance records for today
    await dbRun(
      `UPDATE employee_site_attendance
         SET out_time = NOW(), updated_at = NOW(), status = 'completed'
       WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
      [employee_id],
    );

    // 2. Close all open tracking sessions for today
    await dbRun(
      `UPDATE tracking_sessions
         SET ended_at = NOW(), end_reason = 'manual_end'
       WHERE employee_id = ? AND work_date = CURDATE() AND ended_at IS NULL`,
      [employee_id],
    );

    // 3. Auto-create comp-off if today is a weekend or holiday (IST date)
    const istDate = new Date(Date.now() + 5.5 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);

    await _autoCreateCompoff(employee_id, istDate);

    res.json({ message: "Session ended" });
  } catch (err) {
    console.error("[end-day]", err);
    res.status(500).json({ message: "Database error" });
  }
});

app.put("/attendance/heartbeat", async (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id required" });
  try {
    const result = await dbRun(
      `UPDATE employee_site_attendance
       SET out_time = NOW(), updated_at = NOW()
       WHERE employee_id = ? AND work_date = CURDATE() AND status = 'active'
       ORDER BY id DESC LIMIT 1`,
      [employee_id],
    );
    res.json({ message: "ok", updated: result.affectedRows });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/confirm-location", async (req, res) => {
  const { employee_id, session_id } = req.body;
  if (!employee_id || !session_id)
    return res
      .status(400)
      .json({ message: "employee_id and session_id required" });

  try {
    await dbRun(
      `UPDATE tracking_sessions SET location_verified = 1 WHERE id = ? AND employee_id = ?`,
      [session_id, employee_id],
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/batch-sync", async (req, res) => {
  const { events } = req.body;
  if (!Array.isArray(events) || events.length === 0)
    return res.status(400).json({ message: "events array required" });

  const results = [];

  for (let i = 0; i < events.length; i++) {
    const e = events[i];
    const { type, employee_id, site_id, session_id, timestamp } = e;
    const ts = timestamp || new Date().toISOString();
    const workDate = ts.slice(0, 10);

    try {
      switch (type) {
        case "mark_in": {
          if (!employee_id || !site_id)
            throw new Error("mark_in requires employee_id and site_id");

          await dbRun(
            `UPDATE employee_site_attendance
             SET out_time = ?, updated_at = NOW(), status = 'completed'
             WHERE employee_id = ? AND site_id != ? AND work_date = ? AND out_time IS NULL`,
            [ts, employee_id, site_id, workDate],
          );

          const existing = session_id
            ? await dbGet(
                `SELECT id, out_time, session_id,
                TIMESTAMPDIFF(MINUTE, out_time, ?) AS mins_since_out
             FROM employee_site_attendance
             WHERE employee_id = ? AND site_id = ? AND session_id = ? AND work_date = ?
             ORDER BY id DESC LIMIT 1`,
                [ts, employee_id, site_id, session_id, workDate],
              )
            : null;

          if (!existing) {
            await dbRun(
              `INSERT INTO employee_site_attendance (employee_id, site_id, session_id, in_time, work_date, status, updated_at)
               VALUES (?, ?, ?, ?, ?, 'active', NOW())`,
              [employee_id, site_id, session_id || null, ts, workDate],
            );
          } else if (existing.out_time === null) {
            // Already open — skip
          } else if (
            existing.mins_since_out !== null &&
            existing.mins_since_out < 15
          ) {
            await dbRun(
              `UPDATE employee_site_attendance SET out_time = NULL, updated_at = NOW(), status = 'active' WHERE id = ?`,
              [existing.id],
            );
          } else {
            await dbRun(
              `INSERT INTO employee_site_attendance (employee_id, site_id, session_id, in_time, work_date, status, updated_at)
               VALUES (?, ?, ?, ?, ?, 'active', NOW())`,
              [employee_id, site_id, session_id || null, ts, workDate],
            );
          }
          results.push({ index: i, type, status: "ok" });
          break;
        }
        case "mark_out": {
          if (!employee_id) throw new Error("mark_out requires employee_id");
          await dbRun(
            `UPDATE employee_site_attendance
             SET out_time = ?, updated_at = NOW(), status = 'completed'
             WHERE employee_id = ? AND work_date = ? AND out_time IS NULL
               ${session_id ? "AND session_id = ?" : ""}`,
            session_id
              ? [ts, employee_id, workDate, session_id]
              : [ts, employee_id, workDate],
          );
          results.push({ index: i, type, status: "ok" });
          break;
        }
        case "end_session":
        case "force_end_session": {
          if (!employee_id) throw new Error("requires employee_id");
          const reason = type === "force_end_session" ? "logout" : "manual_end";

          await dbRun(
            `UPDATE employee_site_attendance
             SET out_time = ?, updated_at = NOW(), status = 'completed'
             WHERE employee_id = ? AND work_date = ? AND out_time IS NULL
               ${session_id ? "AND session_id = ?" : ""}`,
            session_id
              ? [ts, employee_id, workDate, session_id]
              : [ts, employee_id, workDate],
          );

          if (session_id) {
            await dbRun(
              `UPDATE tracking_sessions SET ended_at = ?, end_reason = ? WHERE id = ? AND ended_at IS NULL`,
              [ts, reason, session_id],
            );
          } else {
            await dbRun(
              `UPDATE tracking_sessions SET ended_at = ?, end_reason = ?
               WHERE employee_id = ? AND work_date = ? AND ended_at IS NULL`,
              [ts, reason, employee_id, workDate],
            );
          }
          results.push({ index: i, type, status: "ok" });
          break;
        }
        case "end_day": {
          await dbRun(
            `UPDATE employee_site_attendance SET out_time = ?, updated_at = NOW(), status = 'completed'
             WHERE employee_id = ? AND work_date = ? AND out_time IS NULL`,
            [ts, employee_id, workDate],
          );
          await dbRun(
            `UPDATE tracking_sessions SET ended_at = ?, end_reason = 'manual_end'
             WHERE employee_id = ? AND work_date = ? AND ended_at IS NULL`,
            [ts, employee_id, workDate],
          );
          results.push({ index: i, type, status: "ok (legacy)" });
          break;
        }
        default:
          results.push({ index: i, type, status: "unknown_type" });
      }
    } catch (err) {
      results.push({ index: i, type, status: "error", message: err.message });
    }
  }

  res.json({ success: true, processed: results });
});

app.get("/attendance/by-date", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT e.emp_id,
          CONCAT(e.first_name,' ',IFNULL(e.mid_name,''),' ',e.last_name) AS name,
          CASE WHEN a.id IS NULL THEN 'ABSENT' ELSE 'PRESENT' END AS attendance_status,
          a.in_time, a.out_time, a.status AS attendance_record_status
       FROM employee_master e
       LEFT JOIN (
         SELECT employee_id, MIN(in_time) AS in_time, MAX(out_time) AS out_time,
                MAX(id) AS id, MAX(status) AS status
         FROM employee_site_attendance WHERE work_date=?
         GROUP BY employee_id
       ) a ON e.emp_id = a.employee_id
       WHERE e.status='Active'
       ORDER BY e.emp_id`,
      [req.query.date],
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/attendance/by-date-detail", async (req, res) => {
  const { date } = req.query;
  if (!date) return res.status(400).json({ error: "date required" });

  try {
    const employees = await dbAll(
      `SELECT e.emp_id, TRIM(CONCAT(e.first_name, ' ', IFNULL(e.mid_name, ''), ' ', e.last_name)) AS name
       FROM employee_master e WHERE e.status = 'Active' ORDER BY e.emp_id ASC`,
    );

    const sessions = await dbAll(
      `SELECT ts.id AS session_id, ts.employee_id, ts.session_number,
      DATE_FORMAT(ts.started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
      DATE_FORMAT(ts.ended_at,   '%Y-%m-%d %H:%i:%s') AS ended_at,
      ts.end_reason, ts.is_late, ts.late_minutes, ts.late_hours_text,
      TIMESTAMPDIFF(MINUTE, ts.started_at, IFNULL(ts.ended_at, NOW())) AS session_minutes
   FROM tracking_sessions ts WHERE ts.work_date = ?
   ORDER BY ts.employee_id ASC, ts.session_number ASC`,
      [date],
    );

    const visits = await dbAll(
      `SELECT a.id AS visit_id, a.employee_id, a.session_id, a.site_id, s.site_name,
          DATE_FORMAT(a.in_time,  '%Y-%m-%d %H:%i:%s') AS in_time,
          DATE_FORMAT(a.out_time, '%Y-%m-%d %H:%i:%s') AS out_time,
          a.status, TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS worked_minutes
       FROM employee_site_attendance a
       JOIN sites s ON a.site_id = s.id
       WHERE a.work_date = ?
       ORDER BY a.employee_id ASC, a.in_time ASC`,
      [date],
    );

    const empMap = {};
    for (const emp of employees) {
      empMap[emp.emp_id] = {
        emp_id: emp.emp_id,
        name: emp.name,
        attendance_status: "ABSENT",
        total_minutes: 0,
        session_count: 0,
        sessions: [],
      };
    }

    const visitsBySession = {};
    for (const v of visits) {
      const key = v.session_id ?? `nosession_${v.employee_id}`;
      if (!visitsBySession[key]) visitsBySession[key] = [];
      visitsBySession[key].push(v);
    }

    for (const sess of sessions) {
      const emp = empMap[sess.employee_id];
      if (!emp) continue;
      emp.attendance_status = "PRESENT";
      emp.session_count += 1;
      const sessVisits = visitsBySession[sess.session_id] || [];
      const siteMinutes = sessVisits.reduce(
        (sum, v) => sum + (v.worked_minutes || 0),
        0,
      );
      emp.total_minutes += siteMinutes;
      emp.sessions.push({
        session_number: sess.session_number,
        started_at: sess.started_at,
        ended_at: sess.ended_at,
        end_reason: sess.end_reason,
        session_minutes: sess.session_minutes,
        site_minutes: siteMinutes,
        is_late: sess.is_late === 1,
        late_minutes: sess.late_minutes || 0,
        late_text: sess.late_hours_text || null,
        visits: sessVisits.map((v) => ({
          visit_id: v.visit_id,
          site_id: v.site_id,
          site_name: v.site_name,
          in_time: v.in_time,
          out_time: v.out_time,
          worked_minutes: v.worked_minutes,
          status: v.status,
        })),
      });
    }

    res.json({ success: true, data: Object.values(empMap) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/attendance/tl-team-by-date", async (req, res) => {
  const { date, login_id } = req.query;
  if (!date || !login_id)
    return res.status(400).json({ error: "date and login_id required" });

  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id = ?`,
      [login_id],
    );
    if (!tlUser) return res.status(404).json({ error: "TL not found" });

    const rows = await dbAll(
      `SELECT e.emp_id, TRIM(CONCAT(e.first_name, ' ', IFNULL(e.mid_name, ''), ' ', e.last_name)) AS name,
          s.site_name AS location_name, a.id AS visit_id,
          a.in_time, a.out_time, a.work_date, a.status,
          TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS worked_minutes
       FROM employee_master e
       LEFT JOIN employee_site_attendance a ON e.emp_id = a.employee_id AND a.work_date = ?
       LEFT JOIN sites s ON a.site_id = s.id
       WHERE e.status = 'Active' AND e.tl_id = ?
       ORDER BY e.emp_id ASC, a.in_time ASC`,
      [date, tlUser.emp_id],
    );

    const empMap = {};
    for (const row of rows) {
      if (!empMap[row.emp_id]) {
        empMap[row.emp_id] = {
          emp_id: row.emp_id,
          name: row.name,
          attendance_status: row.visit_id ? "PRESENT" : "ABSENT",
          visits: [],
        };
      }
      if (row.visit_id) {
        empMap[row.emp_id].attendance_status = "PRESENT";
        empMap[row.emp_id].visits.push({
          visit_id: row.visit_id,
          location_name: row.location_name,
          in_time: row.in_time,
          out_time: row.out_time,
          worked_minutes: row.worked_minutes,
          status: row.status,
        });
      }
    }
    res.json({ success: true, data: Object.values(empMap) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/attendance/today-summary/:empId", async (req, res) => {
  try {
    const empId = parseInt(req.params.empId);

    const activeSession = await dbGet(
      `SELECT ts.id AS session_id, ts.session_number,
              DATE_FORMAT(ts.started_at, '%Y-%m-%d %H:%i:%s') AS started_at, ts.is_late
       FROM tracking_sessions ts
       WHERE ts.employee_id = ? AND ts.work_date = CURDATE() AND ts.ended_at IS NULL
       ORDER BY ts.id DESC LIMIT 1`,
      [empId],
    );

    const firstSession = await dbGet(
      `SELECT DATE_FORMAT(started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
              is_late, late_minutes, late_hours_decimal, late_hours_text
       FROM tracking_sessions WHERE employee_id = ? AND work_date = CURDATE()
       ORDER BY id ASC LIMIT 1`,
      [empId],
    );

    const latestVisit = await dbGet(
      `SELECT esa.id, DATE_FORMAT(esa.in_time, '%Y-%m-%d %H:%i:%s') AS in_time,
              DATE_FORMAT(esa.out_time, '%Y-%m-%d %H:%i:%s') AS out_time,
              esa.status, s.site_name, s.id AS site_id
       FROM employee_site_attendance esa
       JOIN sites s ON esa.site_id = s.id
       WHERE esa.employee_id = ? AND esa.work_date = CURDATE()
       ORDER BY esa.in_time DESC LIMIT 1`,
      [empId],
    );

    const hoursRow = await dbGet(
      `SELECT IFNULL(SUM(TIMESTAMPDIFF(MINUTE, in_time, IFNULL(out_time, NOW()))), 0) AS minutes
       FROM employee_site_attendance WHERE employee_id = ? AND work_date = CURDATE()`,
      [empId],
    );

    const minutes = hoursRow?.minutes || 0;
    const todayHours = `${Math.floor(minutes / 60)}h ${minutes % 60}m`;

    let attendanceStatus = "Not Checked In",
      statusColor = "orange",
      currentSite = null;
    if (activeSession && latestVisit && latestVisit.out_time === null) {
      attendanceStatus = "Checked In";
      statusColor = "green";
      currentSite = latestVisit.site_name;
    } else if (!activeSession && latestVisit) {
      attendanceStatus = "Checked Out";
      statusColor = "blue";
      currentSite = latestVisit.site_name;
    }

    res.json({
      success: true,
      attendanceStatus,
      statusColor,
      currentSite,
      todayHours,
      sessionActive: !!activeSession,
      isLate: firstSession?.is_late === 1,
      lateMinutes: firstSession?.late_minutes || 0,
      lateHours: firstSession?.late_hours_decimal || 0,
      lateText: firstSession?.late_hours_text || null,
      firstCheckInTime: firstSession?.started_at || null,
      lastVisit: latestVisit
        ? {
            siteId: latestVisit.site_id,
            siteName: latestVisit.site_name,
            inTime: latestVisit.in_time,
            outTime: latestVisit.out_time,
            status: latestVisit.status,
          }
        : null,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

//  ─── GET OPEN / UNCLOSED SESSIONS FOR A DATE ─────────────────────────────────
app.get("/attendance/open-sessions", async (req, res) => {
  const { date } = req.query;
  if (!date)
    return res.status(400).json({ success: false, message: "date required" });

  try {
    // 1. Open tracking sessions (ended_at IS NULL)
    const openSessions = await dbAll(
      `SELECT
          ts.id            AS session_id,
          ts.employee_id,
          ts.session_number,
          DATE_FORMAT(ts.started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
          ts.is_late,
          ts.late_hours_text,
          TIMESTAMPDIFF(MINUTE, ts.started_at, NOW()) AS open_minutes,
          TRIM(CONCAT(e.first_name, ' ',
            IFNULL(e.mid_name, ''), ' ', e.last_name)) AS emp_name,
          e.emp_id,
          d.department_name,
          r.role_name
       FROM tracking_sessions ts
       JOIN employee_master e  ON ts.employee_id = e.emp_id
       LEFT JOIN department_master d ON e.department_id = d.department_id
       LEFT JOIN role_master r       ON e.role_id       = r.role_id
       WHERE ts.work_date = ?
         AND ts.ended_at IS NULL
       ORDER BY ts.started_at ASC`,
      [date],
    );

    // 2. Open site visits for each open session
    const openVisits = await dbAll(
      `SELECT
          a.id         AS visit_id,
          a.employee_id,
          a.session_id,
          a.site_id,
          s.site_name,
          DATE_FORMAT(a.in_time, '%Y-%m-%d %H:%i:%s') AS in_time,
          TIMESTAMPDIFF(MINUTE, a.in_time, NOW()) AS open_minutes
       FROM employee_site_attendance a
       JOIN sites s ON a.site_id = s.id
       WHERE a.work_date = ?
         AND a.out_time IS NULL
       ORDER BY a.in_time ASC`,
      [date],
    );

    // Map visits by employee_id
    const visitsByEmp = {};
    for (const v of openVisits) {
      if (!visitsByEmp[v.employee_id]) visitsByEmp[v.employee_id] = [];
      visitsByEmp[v.employee_id].push(v);
    }

    // Attach open visits to each session
    const result = openSessions.map((s) => ({
      ...s,
      open_visits: visitsByEmp[s.employee_id] || [],
    }));

    res.json({
      success: true,
      date,
      count: result.length,
      data: result,
    });
  } catch (err) {
    console.error("[open-sessions]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ADMIN FORCE-CLOSE SESSION ────────────────────────────────────────────────
app.post("/attendance/admin-force-close", async (req, res) => {
  const {
    employee_id,
    session_id,
    close_time,
    reason,
    closed_by_login_id,
    work_date,
  } = req.body;

  if (!employee_id || !reason || !closed_by_login_id || !work_date) {
    return res.status(400).json({
      success: false,
      message:
        "employee_id, reason, closed_by_login_id, work_date are required",
    });
  }

  try {
    const closer = await dbGet(
      `SELECT lm.login_id, r.role_name
       FROM login_master lm
       JOIN role_master r ON lm.role_id = r.role_id
       WHERE lm.login_id = ? AND lm.status = 'Active'`,
      [closed_by_login_id],
    );
    if (!closer) {
      return res
        .status(403)
        .json({ success: false, message: "Unauthorized user" });
    }
    const allowedRoles = [
      "Admin",
      "Manager",
      "HR",
      "Team Lead",
      "TL",
      "TeamLead",
      "Team_Lead",
    ];
    if (
      !allowedRoles.some((r) =>
        closer.role_name?.toLowerCase().includes(r.toLowerCase()),
      )
    ) {
      return res.status(403).json({
        success: false,
        message: "Only Admin / Manager / HR can force-close sessions",
      });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }

  let closeTs;
  if (close_time) {
    // Flutter sends ISO without timezone — treat as IST (UTC+5:30)
    // If it already has 'Z' or '+', parse normally; else append IST offset
    const hasTimezone = /[Z+]/.test(close_time.slice(10)); // after date part
    closeTs = hasTimezone
      ? new Date(close_time)
      : new Date(close_time + "+05:30");
  } else {
    closeTs = new Date();
  }
  if (closeTs > new Date()) {
    return res.status(400).json({
      success: false,
      message: "Close time cannot be in the future",
    });
  }
  const istOffset = 5.5 * 60 * 60 * 1000; // 5h30m in ms
  const istDate = new Date(closeTs.getTime() + istOffset);
  const closeTsStr = istDate.toISOString().slice(0, 19).replace("T", " ");

  try {
    let sessionsUpdated = 0,
      visitsUpdated = 0;

    if (session_id) {
      // ── Fix: truncate end_reason to 100 chars ──
      const endReason = `admin_force_close: ${reason}`.substring(0, 100);

      const r1 = await dbRun(
        `UPDATE tracking_sessions
         SET ended_at = ?, end_reason = ?, updated_at = NOW()
         WHERE id = ? AND employee_id = ? AND ended_at IS NULL`,
        [closeTsStr, endReason, session_id, employee_id],
      );
      sessionsUpdated = r1.affectedRows;

      const r2 = await dbRun(
        `UPDATE employee_site_attendance
         SET out_time = ?, updated_at = NOW(), status = 'completed'
         WHERE session_id = ? AND employee_id = ? AND out_time IS NULL`,
        [closeTsStr, session_id, employee_id],
      );
      visitsUpdated = r2.affectedRows;
    } else {
      // ── Fix: truncate end_reason to 100 chars ──
      const endReason = `admin_force_close: ${reason}`.substring(0, 100);

      const r1 = await dbRun(
        `UPDATE tracking_sessions
         SET ended_at = ?, end_reason = ?, updated_at = NOW()
         WHERE employee_id = ? AND work_date = ? AND ended_at IS NULL`,
        [closeTsStr, endReason, employee_id, work_date],
      );
      sessionsUpdated = r1.affectedRows;

      const r2 = await dbRun(
        `UPDATE employee_site_attendance
         SET out_time = ?, updated_at = NOW(), status = 'completed'
         WHERE employee_id = ? AND work_date = ? AND out_time IS NULL`,
        [closeTsStr, employee_id, work_date],
      );
      visitsUpdated = r2.affectedRows;
    }

    await dbRun(
      `INSERT INTO login_logs
         (emp_id, username, status, ip_address, device_info, failure_reason, login_time)
       VALUES (?, ?, 'ADMIN_FORCE_CLOSE', 'server', ?, ?, NOW())`,
      [
        employee_id,
        "admin_action",
        `closed_by:${closed_by_login_id}`,
        `session_id:${session_id ?? "all"} | date:${work_date} | reason:${reason} | close_time:${closeTsStr}`,
      ],
    );

    res.json({
      success: true,
      message: "Session closed successfully",
      sessions_closed: sessionsUpdated,
      visits_closed: visitsUpdated,
      closed_at: closeTsStr,
    });
  } catch (err) {
    console.error("[admin-force-close]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/attendance/admin-force-close-all", async (req, res) => {
  const { work_date, close_time, reason, closed_by_login_id } = req.body;

  if (!work_date || !reason || !closed_by_login_id) {
    return res.status(400).json({
      success: false,
      message: "work_date, reason, closed_by_login_id are required",
    });
  }

  let closeTs;
  if (close_time) {
    // Flutter sends ISO without timezone — treat as IST (UTC+5:30)
    // If it already has 'Z' or '+', parse normally; else append IST offset
    const hasTimezone = /[Z+]/.test(close_time.slice(10)); // after date part
    closeTs = hasTimezone
      ? new Date(close_time)
      : new Date(close_time + "+05:30");
  } else {
    closeTs = new Date();
  }
  if (closeTs > new Date()) {
    return res.status(400).json({
      success: false,
      message: "Close time cannot be in the future",
    });
  }
  const istOffset = 5.5 * 60 * 60 * 1000; // 5h30m in ms
  const istDate = new Date(closeTs.getTime() + istOffset);
  const closeTsStr = istDate.toISOString().slice(0, 19).replace("T", " ");

  try {
    // ── Fix: truncate end_reason to 100 chars ──
    const endReason = `bulk_admin_close: ${reason}`.substring(0, 100);

    const r1 = await dbRun(
      `UPDATE tracking_sessions
       SET ended_at = ?, end_reason = ?, updated_at = NOW()
       WHERE work_date = ? AND ended_at IS NULL`,
      [closeTsStr, endReason, work_date],
    );

    const r2 = await dbRun(
      `UPDATE employee_site_attendance
       SET out_time = ?, updated_at = NOW(), status = 'completed'
       WHERE work_date = ? AND out_time IS NULL`,
      [closeTsStr, work_date],
    );

    res.json({
      success: true,
      message: `All open sessions closed for ${work_date}`,
      sessions_closed: r1.affectedRows,
      visits_closed: r2.affectedRows,
      closed_at: closeTsStr,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ADMIN FORCE-CLOSE ALL OPEN SESSIONS FOR A DATE ──────────────────────────

app.post("/attendance/admin-force-close-all", async (req, res) => {
  const { work_date, close_time, reason, closed_by_login_id } = req.body;

  if (!work_date || !reason || !closed_by_login_id) {
    return res.status(400).json({
      success: false,
      message: "work_date, reason, closed_by_login_id are required",
    });
  }

  let closeTs;
  if (close_time) {
    // Flutter sends ISO without timezone — treat as IST (UTC+5:30)
    // If it already has 'Z' or '+', parse normally; else append IST offset
    const hasTimezone = /[Z+]/.test(close_time.slice(10)); // after date part
    closeTs = hasTimezone
      ? new Date(close_time)
      : new Date(close_time + "+05:30");
  } else {
    closeTs = new Date();
  }
  if (closeTs > new Date()) {
    return res.status(400).json({
      success: false,
      message: "Close time cannot be in the future",
    });
  }

  const istOffset = 5.5 * 60 * 60 * 1000; // 5h30m in ms
  const istDate = new Date(closeTs.getTime() + istOffset);
  const closeTsStr = istDate.toISOString().slice(0, 19).replace("T", " ");

  try {
    const r1 = await dbRun(
      `UPDATE tracking_sessions
       SET ended_at = ?, end_reason = ?, updated_at = NOW()
       WHERE work_date = ? AND ended_at IS NULL`,
      [closeTsStr, `bulk_admin_close: ${reason}`, work_date],
    );

    const r2 = await dbRun(
      `UPDATE employee_site_attendance
       SET out_time = ?, updated_at = NOW(), status = 'completed'
       WHERE work_date = ? AND out_time IS NULL`,
      [closeTsStr, work_date],
    );

    res.json({
      success: true,
      message: `All open sessions closed for ${work_date}`,
      sessions_closed: r1.affectedRows,
      visits_closed: r2.affectedRows,
      closed_at: closeTsStr,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});
app.get("/employee-work-hours/:empId", async (req, res) => {
  const { empId } = req.params;
  try {
    const todayRow = await dbGet(
      `SELECT IFNULL(SUM(TIMESTAMPDIFF(MINUTE, in_time, IFNULL(out_time,NOW()))),0) AS minutes
       FROM employee_site_attendance WHERE employee_id=? AND work_date=CURDATE()`,
      [empId],
    );
    const weekRow = await dbGet(
      `SELECT IFNULL(SUM(TIMESTAMPDIFF(MINUTE, in_time, IFNULL(out_time,NOW()))),0) AS minutes
       FROM employee_site_attendance
       WHERE employee_id=?
         AND work_date >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)
         AND work_date <= CURDATE()`,
      [empId],
    );
    const fmt = (m) => `${Math.floor(m / 60)}h ${m % 60}m`;
    res.json({ today: fmt(todayRow.minutes), week: fmt(weekRow.minutes) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── HOLIDAYS ─────────────────────────────────────────────────────────────────
app.get("/holidays/upcoming", async (req, res) => {
  try {
    const days = Math.min(parseInt(req.query.days) || 30, 365);
    const rows = await dbAll(
      `SELECT holiday_id, holiday_name, DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date,
              holiday_type, description, is_recurring,
              DATEDIFF(holiday_date, CURDATE()) AS days_away
       FROM holiday_master
       WHERE holiday_date >= CURDATE() AND holiday_date <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
       ORDER BY holiday_date ASC`,
      [days],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/holidays/summary", async (req, res) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const counts = await dbAll(
      `SELECT holiday_type, COUNT(*) AS count FROM holiday_master WHERE YEAR(holiday_date) = ? GROUP BY holiday_type`,
      [year],
    );
    const totalRow = await dbGet(
      `SELECT COUNT(*) AS total FROM holiday_master WHERE YEAR(holiday_date) = ?`,
      [year],
    );
    const nextRow = await dbGet(
      `SELECT holiday_name, DATE_FORMAT(holiday_date,'%Y-%m-%d') AS holiday_date,
              DATEDIFF(holiday_date, CURDATE()) AS days_away
       FROM holiday_master WHERE holiday_date >= CURDATE() AND YEAR(holiday_date) = ?
       ORDER BY holiday_date ASC LIMIT 1`,
      [year],
    );
    res.json({
      success: true,
      year,
      total: totalRow?.total || 0,
      by_category: counts,
      next_holiday: nextRow || null,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/holidays/range", async (req, res) => {
  const { from, to } = req.query;
  if (!from || !to)
    return res.status(400).json({ error: "from and to required" });
  try {
    const rows = await dbAll(
      `SELECT DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date, holiday_name, holiday_type
       FROM holiday_master WHERE holiday_date BETWEEN ? AND ? ORDER BY holiday_date ASC`,
      [from, to],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/holidays/:id", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT holiday_id, holiday_name, DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date,
              holiday_type, description, is_recurring, created_at, updated_at
       FROM holiday_master WHERE holiday_id = ?`,
      [req.params.id],
    );
    if (!row)
      return res
        .status(404)
        .json({ success: false, message: "Holiday not found" });
    res.json({ success: true, data: row });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/holidays", async (req, res) => {
  try {
    const year = parseInt(req.query.year) || new Date().getFullYear();
    const rows = await dbAll(
      `SELECT holiday_id, holiday_name, DATE_FORMAT(holiday_date, '%Y-%m-%d') AS holiday_date,
              holiday_type, description, is_recurring,
              DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
              DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
       FROM holiday_master WHERE YEAR(holiday_date) = ? ORDER BY holiday_date ASC`,
      [year],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/holidays/bulk", async (req, res) => {
  const { holidays } = req.body;
  if (!Array.isArray(holidays) || holidays.length === 0)
    return res
      .status(400)
      .json({ success: false, message: "holidays array required" });

  const validTypes = ["Public", "National", "Optional", "Office"];
  const errors = [],
    values = [];

  holidays.forEach((h, i) => {
    if (!h.holiday_name?.trim()) {
      errors.push(`[${i}] holiday_name required`);
      return;
    }
    if (!h.holiday_date) {
      errors.push(`[${i}] holiday_date required`);
      return;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(h.holiday_date)) {
      errors.push(`[${i}] invalid date`);
      return;
    }
    const type = h.holiday_type || "Public";
    if (!validTypes.includes(type)) {
      errors.push(`[${i}] invalid type "${type}"`);
      return;
    }
    values.push([
      h.holiday_name.trim(),
      h.holiday_date,
      type,
      h.description?.trim() || null,
      h.is_recurring ? 1 : 0,
    ]);
  });

  if (errors.length)
    return res
      .status(400)
      .json({ success: false, message: "Validation errors", errors });

  try {
    const result = await dbRun(
      `INSERT IGNORE INTO holiday_master (holiday_name, holiday_date, holiday_type, description, is_recurring) VALUES ?`,
      [values],
    );
    res.status(201).json({
      success: true,
      message: `${result.affectedRows} holiday(s) inserted (${values.length - result.affectedRows} skipped as duplicates)`,
      inserted: result.affectedRows,
      skipped: values.length - result.affectedRows,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/holidays", async (req, res) => {
  const {
    holiday_name,
    holiday_date,
    holiday_type,
    description,
    is_recurring,
    login_id,
  } = req.body;

  if (!holiday_name?.trim())
    return res
      .status(400)
      .json({ success: false, message: "Holiday name is required" });
  if (!holiday_date)
    return res
      .status(400)
      .json({ success: false, message: "Date is required" });
  if (!/^\d{4}-\d{2}-\d{2}$/.test(holiday_date))
    return res
      .status(400)
      .json({ success: false, message: "Date must be YYYY-MM-DD" });

  const validTypes = ["Public", "National", "Optional", "Office"];
  const type = holiday_type || "Public";
  if (!validTypes.includes(type))
    return res.status(400).json({
      success: false,
      message: `Invalid type. Use: ${validTypes.join(", ")}`,
    });

  try {
    const result = await dbRun(
      `INSERT INTO holiday_master (holiday_name, holiday_date, holiday_type, description, is_recurring, created_by)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        holiday_name.trim(),
        holiday_date,
        type,
        description?.trim() || null,
        is_recurring ? 1 : 0,
        login_id || null,
      ],
    );
    res.status(201).json({
      success: true,
      message: "Holiday added successfully",
      holiday_id: result.insertId,
    });
  } catch (err) {
    if (err.code === "ER_DUP_ENTRY")
      return res.status(409).json({
        success: false,
        message: "Holiday already exists on this date",
      });
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/holidays/:id", async (req, res) => {
  const {
    holiday_name,
    holiday_date,
    holiday_type,
    description,
    is_recurring,
  } = req.body;
  try {
    const existing = await dbGet(
      `SELECT * FROM holiday_master WHERE holiday_id = ?`,
      [req.params.id],
    );
    if (!existing)
      return res
        .status(404)
        .json({ success: false, message: "Holiday not found" });

    const validTypes = ["Public", "National", "Optional", "Office"];
    const newType = holiday_type || existing.holiday_type;
    if (!validTypes.includes(newType))
      return res
        .status(400)
        .json({ success: false, message: "Invalid holiday type" });
    if (holiday_date && !/^\d{4}-\d{2}-\d{2}$/.test(holiday_date))
      return res
        .status(400)
        .json({ success: false, message: "Date must be YYYY-MM-DD" });

    await dbRun(
      `UPDATE holiday_master SET holiday_name=?, holiday_date=?, holiday_type=?, description=?, is_recurring=?, updated_at=NOW()
       WHERE holiday_id=?`,
      [
        holiday_name?.trim() || existing.holiday_name,
        holiday_date || existing.holiday_date,
        newType,
        description !== undefined
          ? description?.trim() || null
          : existing.description,
        is_recurring !== undefined
          ? is_recurring
            ? 1
            : 0
          : existing.is_recurring,
        req.params.id,
      ],
    );
    res.json({ success: true, message: "Holiday updated successfully" });
  } catch (err) {
    if (err.code === "ER_DUP_ENTRY")
      return res.status(409).json({
        success: false,
        message: "A holiday already exists on that date",
      });
    res.status(500).json({ success: false, message: err.message });
  }
});

app.delete("/holidays/:id", async (req, res) => {
  try {
    const result = await dbRun(
      `DELETE FROM holiday_master WHERE holiday_id = ?`,
      [req.params.id],
    );
    if (result.affectedRows === 0)
      return res
        .status(404)
        .json({ success: false, message: "Holiday not found" });
    res.json({ success: true, message: "Holiday deleted" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ADMIN REQUESTS ───────────────────────────────────────────────────────────
app.get("/admin/pending-requests", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT p.request_id, p.emp_id,
          COALESCE(p.first_name,        e.first_name)        AS first_name,
          COALESCE(p.mid_name,          e.mid_name)          AS mid_name,
          COALESCE(p.last_name,         e.last_name)         AS last_name,
          COALESCE(p.email_id,          e.email_id)          AS email_id,
          COALESCE(p.phone_number,      e.phone_number)      AS phone_number,
          COALESCE(p.date_of_birth,     e.date_of_birth)     AS date_of_birth,
          COALESCE(p.gender,            e.gender)            AS gender,
          COALESCE(p.department_id,     e.department_id)     AS department_id,
          COALESCE(p.role_id,           e.role_id)           AS role_id,
          COALESCE(p.date_of_joining,   e.date_of_joining)   AS date_of_joining,
          COALESCE(p.employment_type,   e.employment_type)   AS employment_type,
          COALESCE(p.work_type,         e.work_type)         AS work_type,
          COALESCE(p.permanent_address, e.permanent_address) AS permanent_address,
          COALESCE(p.communication_address, e.communication_address) AS communication_address,
          COALESCE(p.aadhar_number,     e.aadhar_number)     AS aadhar_number,
          COALESCE(p.pan_number,        e.pan_number)        AS pan_number,
          COALESCE(p.passport_number,   e.passport_number)   AS passport_number,
          COALESCE(p.father_name,       e.father_name)       AS father_name,
          COALESCE(p.emergency_contact, e.emergency_contact) AS emergency_contact,
          COALESCE(p.pf_number,         e.pf_number)         AS pf_number,
          COALESCE(p.esic_number,       e.esic_number)       AS esic_number,
          COALESCE(p.years_experience,  e.years_experience)  AS years_experience,
          COALESCE(p.emergency_contact_relation, e.emergency_contact_relation) AS emergency_contact_relation,
          p.admin_approve, p.username, p.request_type, p.edit_reason, p.reject_reason,
          p.created_at, p.updated_at, d.department_name, r.role_name,
          (SELECT JSON_ARRAYAGG(JSON_OBJECT(
              'education_level', x.education_level, 'stream', x.stream, 'score', x.score,
              'year_of_passout', x.year_of_passout, 'university', x.university, 'college_name', x.college_name))
           FROM (
             SELECT ep.education_level, ep.stream, ep.score, ep.year_of_passout, ep.university, ep.college_name
             FROM education_pending_request ep WHERE ep.request_id = p.request_id
             UNION ALL
             SELECT ed.education_level, ed.stream, ed.score, ed.year_of_passout, ed.university, ed.college_name
             FROM education_details ed WHERE ed.emp_id = p.emp_id
               AND NOT EXISTS (SELECT 1 FROM education_pending_request ep2 WHERE ep2.request_id = p.request_id AND ep2.education_level = ed.education_level)
           ) x) AS education_list
       FROM employee_pending_request p
       LEFT JOIN employee_master   e ON p.emp_id        = e.emp_id
       LEFT JOIN department_master d ON COALESCE(p.department_id, e.department_id) = d.department_id
       LEFT JOIN role_master       r ON COALESCE(p.role_id, e.role_id) = r.role_id
       WHERE p.admin_approve = 'PENDING'
       ORDER BY p.created_at DESC`,
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/admin/reject-request", async (req, res) => {
  const { request_id, reject_reason } = req.body;
  if (!request_id || !reject_reason)
    return res
      .status(400)
      .json({ error: "request_id and reject_reason required" });
  try {
    await dbRun(
      `UPDATE employee_pending_request SET admin_approve='REJECTED', reject_reason=? WHERE request_id=?`,
      [reject_reason, request_id],
    );
    res.json({ message: "Request rejected" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get("/admin/request/:request_id", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT p.*,
      COALESCE(p.department_id, e.department_id) AS dept_id_resolved,
      COALESCE(p.role_id, e.role_id) AS role_id_resolved,
      d.department_name, r.role_name,
      TRIM(CONCAT(tl.first_name, ' ', IFNULL(tl.mid_name, ''), ' ', tl.last_name)) AS tl_name
   FROM employee_pending_request p
   LEFT JOIN employee_master   e  ON p.emp_id = e.emp_id
   LEFT JOIN department_master d  ON COALESCE(p.department_id, e.department_id) = d.department_id
   LEFT JOIN role_master       r  ON COALESCE(p.role_id, e.role_id) = r.role_id
   LEFT JOIN employee_master   tl ON COALESCE(p.tl_id, e.tl_id) = tl.emp_id
   WHERE p.request_id = ?`,
      [req.params.request_id],
    );
    if (!row)
      return res
        .status(404)
        .json({ success: false, message: "Request not found" });
    res.json({ success: true, data: row });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ALL EMPLOYEES ────────────────────────────────────────────────────────────
app.get("/all-employees", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT * FROM (
         SELECT e.emp_id, e.first_name, e.mid_name, e.last_name,
           e.email_id AS email, e.phone_number AS phone, e.date_of_birth, e.gender,
           e.department_id, d.department_name, e.role_id, r.role_name,
           e.date_of_joining, e.employment_type, e.work_type, e.status AS emp_status,
           NULL AS admin_approve, NULL AS request_id, 'MASTER' AS source, e.created_at, e.updated_at
         FROM employee_master e
         LEFT JOIN department_master d ON e.department_id=d.department_id
         LEFT JOIN role_master r ON e.role_id=r.role_id
         UNION ALL
         SELECT p.emp_id, p.first_name, p.mid_name, p.last_name,
           p.email_id AS email, p.phone_number AS phone, p.date_of_birth, p.gender,
           p.department_id, d2.department_name, p.role_id, r2.role_name,
           p.date_of_joining, p.employment_type, p.work_type,
           NULL AS emp_status, p.admin_approve, p.request_id, 'PENDING' AS source, p.created_at, p.updated_at
         FROM employee_pending_request p
         LEFT JOIN department_master d2 ON p.department_id=d2.department_id
         LEFT JOIN role_master r2 ON p.role_id=r2.role_id
         WHERE p.admin_approve IN ('PENDING','REJECTED')
       ) combined ORDER BY created_at DESC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── EDUCATION ────────────────────────────────────────────────────────────────
app.get("/employees/:empId/education", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT edu_id, emp_id, education_level, stream, score,
              year_of_passout, university, college_name, created_at
       FROM education_details WHERE emp_id=?
       ORDER BY FIELD(education_level,'10','12','Diploma','UG','PG','PhD') ASC`,
      [req.params.empId],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── EMPLOYEE USER ────────────────────────────────────────────────────────────
app.get("/employee-user/:loginId", async (req, res) => {
  try {
    const u = await dbGet(
      `SELECT lm.login_id, lm.emp_id, lm.username, r.role_name,
          CONCAT(e.first_name,
            CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != '' THEN CONCAT(' ', e.mid_name) ELSE '' END,
            ' ', e.last_name) AS full_name
       FROM login_master lm
       LEFT JOIN employee_master e ON lm.emp_id = e.emp_id
       LEFT JOIN role_master r ON lm.role_id = r.role_id
       WHERE lm.login_id = ?`,
      [req.params.loginId],
    );
    if (!u)
      return res.status(404).json({ success: false, message: "Not found" });
    res.json({
      success: true,
      login_id: u.login_id,
      emp_id: u.emp_id,
      full_name: u.full_name?.trim() || u.username,
      role_name: u.role_name || "-",
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── NEW EMPLOYEE PENDING REQUEST ────────────────────────────────────────────
app.post("/employee-pending-request", async (req, res) => {
  const {
    first_name,
    mid_name,
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    department_id,
    role_id,
    tl_id,
    date_of_joining,
    employment_type,
    work_type,
    permanent_address,
    communication_address,
    aadhar_number,
    pan_number,
    passport_number,
    father_name,
    emergency_contact_relation,
    emergency_contact,
    pf_number,
    esic_number,
    years_experience,
    username,
    password,
    education,
  } = req.body;

  const required = [
    first_name,
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    department_id,
    role_id,
    date_of_joining,
    employment_type,
    work_type,
    permanent_address,
    username,
    password,
  ];
  if (required.some((v) => !v))
    return res
      .status(400)
      .json({ success: false, message: "Missing required fields" });

  const safe = (v) => (v && v.toString().trim() !== "" ? v : null);

  try {
    const result = await dbRun(
      `INSERT INTO employee_pending_request (
        first_name, mid_name, last_name, email_id, phone_number, date_of_birth, gender,
        department_id, role_id, tl_id, date_of_joining, employment_type, work_type,
        permanent_address, communication_address, aadhar_number, pan_number, passport_number,
        father_name, emergency_contact_relation, emergency_contact,
        pf_number, esic_number, years_experience,
        admin_approve, username, password, request_type, created_at, updated_at
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'PENDING',?,?,'NEW',NOW(),NOW())`,
      [
        first_name,
        safe(mid_name),
        last_name,
        email_id,
        phone_number,
        date_of_birth,
        gender,
        department_id,
        role_id,
        tl_id,
        date_of_joining,
        employment_type,
        work_type,
        permanent_address,
        safe(communication_address),
        safe(aadhar_number),
        safe(pan_number),
        safe(passport_number),
        safe(father_name),
        safe(emergency_contact_relation),
        safe(emergency_contact),
        safe(pf_number),
        safe(esic_number),
        years_experience ? parseInt(years_experience) : null,
        username,
        password,
      ],
    );

    const requestId = result.insertId;
    if (Array.isArray(education) && education.length > 0) {
      const eduValues = education.map((e) => [
        requestId,
        e.education_level,
        e.stream || null,
        e.score ? parseFloat(e.score) : null,
        e.year_of_passout || null,
        e.university || null,
        e.college_name || null,
      ]);
      await dbRun(
        `INSERT INTO education_pending_request (request_id, education_level, stream, score, year_of_passout, university, college_name) VALUES ?`,
        [eduValues],
      );
    }
    res.json({
      success: true,
      message: "Employee request submitted",
      request_id: requestId,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── FACE EMBEDDING FUNCTION ──────────────────────────────────────────────────
async function getFaceEmbedding(imageBuffer) {
  try {
    const form = new FormData();
    form.append("file", imageBuffer, { filename: "face.jpg" });
    const res = await axios.post("http://127.0.0.1:8000/embedding", form, {
      headers: form.getHeaders(),
      timeout: 5000,
    });
    if (!res.data.success)
      throw new Error(res.data.error || "Embedding failed");
    return res.data.embedding;
  } catch (err) {
    console.error("Embedding Error:", err.message);
    return null;
  }
}

// ─── APPROVE REQUEST ──────────────────────────────────────────────────────────
app.post("/admin/approve-request", async (req, res) => {
  const { request_id } = req.body;
  if (!request_id)
    return res.status(400).json({ error: "request_id is required" });

  db.getConnection(async (connErr, conn) => {
    if (connErr) return res.status(500).json({ error: connErr.message });

    const run = (sql, params = []) =>
      new Promise((resolve, reject) =>
        conn.query(sql, params, (err, result) =>
          err ? reject(err) : resolve(result),
        ),
      );
    const get = (sql, params = []) =>
      new Promise((resolve, reject) =>
        conn.query(sql, params, (err, rows) =>
          err ? reject(err) : resolve(rows[0] || null),
        ),
      );

    try {
      await run("START TRANSACTION");

      const request = await get(
        `SELECT * FROM employee_pending_request WHERE request_id = ? AND admin_approve = 'PENDING'`,
        [request_id],
      );

      if (!request) {
        await run("ROLLBACK");
        conn.release();
        return res
          .status(404)
          .json({ error: "Request not found or already processed" });
      }

      const n = (v) => (v && v.toString().trim() !== "" ? v : null);
      const toInt = (v) => (v != null && v !== "" ? parseInt(v, 10) : null);

      const dupChecks = [
        ["email_id", request.email_id, "Email already exists"],
        ["phone_number", request.phone_number, "Phone already exists"],
        ["aadhar_number", request.aadhar_number, "Aadhar already exists"],
        ["pan_number", request.pan_number, "PAN already exists"],
      ];

      for (const [field, value, label] of dupChecks) {
        if (!value || value.toString().trim() === "") continue;
        let dup;
        if (request.request_type === "UPDATE" && request.emp_id) {
          dup = await get(
            `SELECT emp_id FROM employee_master WHERE ${field} = ? AND emp_id != ?`,
            [value, request.emp_id],
          );
        } else {
          dup = await get(
            `SELECT emp_id FROM employee_master WHERE ${field} = ?`,
            [value],
          );
        }
        if (dup) {
          await run(
            `UPDATE employee_pending_request SET admin_approve = 'REJECTED', reject_reason = ? WHERE request_id = ?`,
            [label, request_id],
          );
          await run("COMMIT");
          conn.release();
          return res.status(409).json({ error: label });
        }
      }

      if (request.request_type === "NEW") {
        const empResult = await run(
          `INSERT INTO employee_master (
            first_name, mid_name, last_name, email_id, phone_number, date_of_birth, gender,
            father_name, emergency_contact_relation, emergency_contact,
            department_id, role_id, tl_id, date_of_joining, date_of_relieving,
            employment_type, work_type, permanent_address, communication_address,
            aadhar_number, pan_number, passport_number, pf_number, esic_number, years_experience, status
          ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'Active')`,
          [
            request.first_name,
            n(request.mid_name),
            request.last_name,
            request.email_id,
            request.phone_number,
            request.date_of_birth,
            request.gender,
            n(request.father_name),
            n(request.emergency_contact_relation),
            n(request.emergency_contact),
            request.department_id,
            request.role_id,
            n(request.tl_id),
            request.date_of_joining,
            n(request.date_of_relieving),
            request.employment_type,
            request.work_type,
            request.permanent_address,
            n(request.communication_address),
            n(request.aadhar_number),
            n(request.pan_number),
            n(request.passport_number),
            n(request.pf_number),
            n(request.esic_number),
            toInt(request.years_experience),
          ],
        );

        const empId = empResult.insertId;

        const pendingPhoto = await get(
          `SELECT profile_photo, profile_photo_mime FROM employee_pending_request WHERE request_id = ?`,
          [request_id],
        );
        if (pendingPhoto?.profile_photo) {
          await run(
            `UPDATE employee_master SET profile_photo = ?, profile_photo_mime = ? WHERE emp_id = ?`,
            [
              pendingPhoto.profile_photo,
              pendingPhoto.profile_photo_mime,
              empId,
            ],
          );
          const embedding = await getFaceEmbedding(pendingPhoto.profile_photo);
          if (embedding) {
            await run(
              `UPDATE employee_master SET face_embedding = ? WHERE emp_id = ?`,
              [JSON.stringify(embedding), empId],
            );
          }
        }

        const eduRows = await new Promise((resolve, reject) =>
          conn.query(
            `SELECT * FROM education_pending_request WHERE request_id = ?`,
            [request_id],
            (err, rows) => (err ? reject(err) : resolve(rows)),
          ),
        );
        if (eduRows.length > 0) {
          const eduValues = eduRows.map((e) => [
            empId,
            e.education_level,
            e.stream || null,
            e.score != null ? parseFloat(e.score) : null,
            e.year_of_passout || null,
            e.university || null,
            e.college_name || null,
          ]);
          await run(
            `INSERT INTO education_details (emp_id, education_level, stream, score, year_of_passout, university, college_name) VALUES ?`,
            [eduValues],
          );
        }

        await run(
          `INSERT INTO login_master (emp_id, username, password, role_id, status) VALUES (?, ?, ?, ?, 'Active')`,
          [empId, request.username, request.password, request.role_id],
        );
        await run(
          `UPDATE employee_pending_request SET admin_approve = 'APPROVED', emp_id = ? WHERE request_id = ?`,
          [empId, request_id],
        );
        await run("COMMIT");
        conn.release();
        return res.json({
          success: true,
          message: "Employee approved and created",
          emp_id: empId,
        });
      }

      if (request.request_type === "UPDATE") {
        if (!request.emp_id) {
          await run("ROLLBACK");
          conn.release();
          return res.status(400).json({
            error: "emp_id missing in pending request for UPDATE type",
          });
        }

        const pendingPhoto = await get(
          `SELECT profile_photo, profile_photo_mime FROM employee_pending_request WHERE request_id = ?`,
          [request_id],
        );

        const updateResult = await run(
          `UPDATE employee_master SET
            first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?,
            date_of_birth=?, gender=?, father_name=?, emergency_contact_relation=?, emergency_contact=?,
            department_id=?, role_id=?, tl_id=?, date_of_joining=?, date_of_relieving=?,
            employment_type=?, work_type=?, permanent_address=?, communication_address=?,
            aadhar_number=?, pan_number=?, passport_number=?, pf_number=?, esic_number=?,
            years_experience=?, status=?,
            profile_photo=COALESCE(?,profile_photo), profile_photo_mime=COALESCE(?,profile_photo_mime),
            updated_at=NOW()
           WHERE emp_id=?`,
          [
            request.first_name,
            n(request.mid_name),
            request.last_name,
            request.email_id,
            request.phone_number,
            request.date_of_birth,
            request.gender,
            n(request.father_name),
            n(request.emergency_contact_relation),
            n(request.emergency_contact),
            request.department_id,
            request.role_id,
            n(request.tl_id),
            request.date_of_joining,
            n(request.date_of_relieving),
            request.employment_type,
            request.work_type,
            request.permanent_address,
            n(request.communication_address),
            n(request.aadhar_number),
            n(request.pan_number),
            n(request.passport_number),
            n(request.pf_number),
            n(request.esic_number),
            toInt(request.years_experience),
            request.status || "Active",
            pendingPhoto?.profile_photo || null,
            pendingPhoto?.profile_photo_mime || null,
            request.emp_id,
          ],
        );

        if (updateResult.affectedRows === 0) {
          await run("ROLLBACK");
          conn.release();
          return res.status(404).json({ error: "Employee not found" });
        }

        await run(
          `UPDATE login_master SET role_id = ?, updated_at = NOW() WHERE emp_id = ?`,
          [request.role_id, request.emp_id],
        );

        const eduRows = await new Promise((resolve, reject) =>
          conn.query(
            `SELECT * FROM education_pending_request WHERE request_id = ?`,
            [request_id],
            (err, rows) => (err ? reject(err) : resolve(rows)),
          ),
        );
        if (eduRows.length > 0) {
          await run(`DELETE FROM education_details WHERE emp_id = ?`, [
            request.emp_id,
          ]);
          const eduValues = eduRows.map((e) => [
            request.emp_id,
            e.education_level,
            e.stream || null,
            e.score != null ? parseFloat(e.score) : null,
            e.year_of_passout || null,
            e.university || null,
            e.college_name || null,
          ]);
          await run(
            `INSERT INTO education_details (emp_id, education_level, stream, score, year_of_passout, university, college_name) VALUES ?`,
            [eduValues],
          );
        }

        if (pendingPhoto?.profile_photo) {
          const embedding = await getFaceEmbedding(pendingPhoto.profile_photo);
          if (embedding) {
            await run(
              `UPDATE employee_master SET face_embedding = ? WHERE emp_id = ?`,
              [JSON.stringify(embedding), request.emp_id],
            );
          }
        }

        await run(
          `UPDATE employee_pending_request SET admin_approve = 'APPROVED' WHERE request_id = ?`,
          [request_id],
        );
        await run("COMMIT");
        conn.release();
        return res.json({
          success: true,
          message: "Employee updated and approved",
          emp_id: request.emp_id,
        });
      }

      await run("ROLLBACK");
      conn.release();
      return res.status(400).json({ error: "Unknown request type" });
    } catch (err) {
      try {
        await conn.query("ROLLBACK");
      } catch (_) {}
      conn.release();
      return res
        .status(500)
        .json({ error: "Internal server error", details: err.message });
    }
  });
});

// ─── EDIT REQUEST ─────────────────────────────────────────────────────────────
app.post("/employee-edit-request", async (req, res) => {
  const {
    emp_id,
    first_name,
    mid_name,
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    department_id,
    role_id,
    tl_id,
    date_of_joining,
    date_of_relieving,
    employment_type,
    work_type,
    permanent_address,
    communication_address,
    aadhar_number,
    pan_number,
    passport_number,
    father_name,
    emergency_contact_relation,
    emergency_contact,
    pf_number,
    esic_number,
    years_experience,
    edit_reason,
    status,
    education,
  } = req.body;

  if (!emp_id)
    return res.status(400).json({ success: false, message: "emp_id required" });

  const emptyToNull = (v) =>
    v != null && v.toString().trim() !== "" ? v : null;
  const safeInt = (v) => (v != null && v !== "" ? parseInt(v) : null);

  if (
    status === "Relieved" &&
    (!date_of_relieving || date_of_relieving.toString().trim() === "")
  ) {
    return res.status(400).json({
      success: false,
      message: "Date of Relieving is required when status is Relieved",
    });
  }

  const dorValue =
    status === "Relieved" ? emptyToNull(date_of_relieving) : null;
  const sharedFields = [
    first_name,
    emptyToNull(mid_name),
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    safeInt(department_id),
    safeInt(role_id),
    safeInt(tl_id),
    date_of_joining,
    dorValue,
    employment_type,
    work_type,
    permanent_address,
    emptyToNull(communication_address),
    emptyToNull(aadhar_number),
    emptyToNull(pan_number),
    emptyToNull(passport_number),
    emptyToNull(father_name),
    emptyToNull(emergency_contact_relation),
    emptyToNull(emergency_contact),
    emptyToNull(pf_number),
    emptyToNull(esic_number),
    safeInt(years_experience),
    status || "Active",
    emptyToNull(edit_reason),
  ];

  try {
    const existing = await dbGet(
      `SELECT request_id FROM employee_pending_request WHERE emp_id = ? AND admin_approve = 'PENDING' ORDER BY created_at DESC LIMIT 1`,
      [emp_id],
    );
    let requestId;

    if (existing) {
      await dbRun(
        `UPDATE employee_pending_request SET
          first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?, date_of_birth=?, gender=?,
          department_id=?, role_id=?, tl_id=?, date_of_joining=?, date_of_relieving=?,
          employment_type=?, work_type=?, permanent_address=?, communication_address=?,
          aadhar_number=?, pan_number=?, passport_number=?, father_name=?,
          emergency_contact_relation=?, emergency_contact=?, pf_number=?, esic_number=?,
          years_experience=?, status=?, edit_reason=?, admin_approve='PENDING', updated_at=NOW()
         WHERE request_id=?`,
        [...sharedFields, existing.request_id],
      );
      requestId = existing.request_id;
    } else {
      const result = await dbRun(
        `INSERT INTO employee_pending_request
          (emp_id, first_name, mid_name, last_name, email_id, phone_number, date_of_birth, gender,
           department_id, role_id, tl_id, date_of_joining, date_of_relieving, employment_type, work_type,
           permanent_address, communication_address, aadhar_number, pan_number, passport_number,
           father_name, emergency_contact_relation, emergency_contact, pf_number, esic_number,
           years_experience, status, admin_approve, username, password, request_type, edit_reason, created_at, updated_at)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'PENDING','-','-','UPDATE',?,NOW(),NOW())`,
        [emp_id, ...sharedFields],
      );
      requestId = result.insertId;
    }

    if (requestId) {
      await dbRun("DELETE FROM education_pending_request WHERE request_id=?", [
        requestId,
      ]);
      if (Array.isArray(education) && education.length > 0) {
        const eduValues = education.map((e) => [
          requestId,
          e.education_level,
          e.stream || null,
          e.score != null && e.score !== "" ? parseFloat(e.score) : null,
          e.year_of_passout || null,
          e.university || null,
          e.college_name || null,
        ]);
        await dbRun(
          `INSERT INTO education_pending_request (request_id, education_level, stream, score, year_of_passout, university, college_name) VALUES ?`,
          [eduValues],
        );
      }
    }

    res.json({
      success: true,
      message: existing
        ? "Pending request updated!"
        : "Pending request submitted!",
      request_id: requestId,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── RESUBMIT REJECTED REQUEST ────────────────────────────────────────────────
app.put("/admin/resubmit-request/:request_id", async (req, res) => {
  const {
    first_name,
    mid_name,
    last_name,
    email_id,
    phone_number,
    date_of_birth,
    gender,
    department_id,
    role_id,
    date_of_joining,
    employment_type,
    work_type,
    permanent_address,
    communication_address,
    aadhar_number,
    pan_number,
    passport_number,
    father_name,
    emergency_contact_relation,
    emergency_contact,
    pf_number,
    esic_number,
    years_experience,
    username,
    education,
  } = req.body;

  try {
    const result = await dbRun(
      `UPDATE employee_pending_request SET
         first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?, date_of_birth=?, gender=?,
         department_id=?, role_id=?, date_of_joining=?, employment_type=?, work_type=?,
         permanent_address=?, communication_address=?, aadhar_number=?, pan_number=?, passport_number=?,
         father_name=?, emergency_contact_relation=?, emergency_contact=?,
         pf_number=?, esic_number=?, years_experience=?,
         username=?, admin_approve='PENDING', reject_reason=NULL, updated_at=NOW()
       WHERE request_id=? AND admin_approve='REJECTED'`,
      [
        first_name,
        mid_name || null,
        last_name,
        email_id,
        phone_number,
        date_of_birth,
        gender,
        department_id,
        role_id,
        date_of_joining,
        employment_type,
        work_type,
        permanent_address,
        communication_address || null,
        aadhar_number || null,
        pan_number || null,
        passport_number || null,
        father_name || null,
        emergency_contact_relation || null,
        emergency_contact || null,
        pf_number || null,
        esic_number || null,
        years_experience ? parseInt(years_experience) : null,
        username,
        req.params.request_id,
      ],
    );

    if (result.affectedRows === 0)
      return res.status(404).json({
        success: false,
        message: "Request not found or not in REJECTED state",
      });

    await dbRun("DELETE FROM education_pending_request WHERE request_id=?", [
      req.params.request_id,
    ]);
    if (Array.isArray(education) && education.length > 0) {
      const eduValues = education.map((e) => [
        req.params.request_id,
        e.education_level,
        e.stream || null,
        e.score ? parseFloat(e.score) : null,
        e.year_of_passout || null,
        e.university || null,
        e.college_name || null,
      ]);
      await dbRun(
        `INSERT INTO education_pending_request (request_id, education_level, stream, score, year_of_passout, university, college_name) VALUES ?`,
        [eduValues],
      );
    }
    res.json({ success: true, message: "Request resubmitted successfully" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ADMIN SESSION MANAGEMENT ─────────────────────────────────────────────────
app.get("/admin/sessions", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT lm.login_id, lm.emp_id, lm.username, lm.role_id, r.role_name,
          CONCAT(e.first_name, CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != '' THEN CONCAT(' ', e.mid_name) ELSE '' END, ' ', e.last_name) AS full_name,
          lm.status, lm.session_token, lm.session_device, lm.device_logged_in, lm.last_login_at, lm.updated_at
       FROM login_master lm
       LEFT JOIN employee_master e ON lm.emp_id = e.emp_id
       LEFT JOIN role_master r ON lm.role_id = r.role_id
       WHERE lm.status = 'Active'
       ORDER BY lm.last_login_at DESC`,
    );

    const sessions = rows.map((row) => ({
      loginId: row.login_id,
      empId: row.emp_id,
      username: row.username,
      fullName: row.full_name?.trim() || row.username,
      roleName: row.role_name || "-",
      isLoggedIn: row.device_logged_in === 1 && row.session_token !== null,
      deviceInfo: parseDeviceInfo(row.session_device),
      lastLoginAt: row.last_login_at || null,
      updatedAt: row.updated_at || null,
    }));

    res.json({ success: true, data: sessions });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/admin/sessions/:loginId/force-logout", async (req, res) => {
  const { loginId } = req.params;
  if (!loginId || isNaN(parseInt(loginId)))
    return res.status(400).json({ success: false, message: "Invalid loginId" });

  try {
    const user = await dbGet(
      `SELECT login_id, emp_id, username, device_logged_in, session_token FROM login_master WHERE login_id = ? AND status = 'Active'`,
      [loginId],
    );
    if (!user)
      return res
        .status(404)
        .json({ success: false, message: "User not found or inactive" });
    if (!user.session_token || user.device_logged_in === 0)
      return res.json({
        success: true,
        message: "User is not currently logged in",
      });

    if (user.emp_id) {
      await dbRun(
        `UPDATE employee_site_attendance SET out_time = NOW(), updated_at = NOW(), status = 'completed'
         WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
        [user.emp_id],
      );
      await dbRun(
        `UPDATE tracking_sessions SET ended_at = NOW(), end_reason = 'force_logout'
         WHERE employee_id = ? AND work_date = CURDATE() AND ended_at IS NULL`,
        [user.emp_id],
      );
    }

    await dbRun(
      `UPDATE login_master SET session_token = NULL, session_device = NULL, device_logged_in = 0, updated_at = NOW() WHERE login_id = ?`,
      [loginId],
    );

    res.json({
      success: true,
      message: `${user.username} has been logged out`,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/admin/sessions/force-logout-all/:empId", async (req, res) => {
  const { empId } = req.params;
  if (!empId || isNaN(parseInt(empId)))
    return res.status(400).json({ success: false, message: "Invalid empId" });

  try {
    await dbRun(
      `UPDATE employee_site_attendance SET out_time = NOW(), updated_at = NOW(), status = 'completed'
       WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
      [empId],
    );
    await dbRun(
      `UPDATE tracking_sessions SET ended_at = NOW(), end_reason = 'force_logout'
       WHERE employee_id = ? AND work_date = CURDATE() AND ended_at IS NULL`,
      [empId],
    );
    const result = await dbRun(
      `UPDATE login_master SET session_token = NULL, session_device = NULL, device_logged_in = 0, updated_at = NOW()
       WHERE emp_id = ? AND status = 'Active'`,
      [empId],
    );
    res.json({
      success: true,
      message: `All sessions cleared (${result.affectedRows} account(s))`,
      affectedRows: result.affectedRows,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/admin/sessions/:loginId/status", async (req, res) => {
  const { loginId } = req.params;
  try {
    const row = await dbGet(
      `SELECT lm.login_id, lm.username, lm.session_device, lm.device_logged_in, lm.last_login_at,
          CONCAT(e.first_name, ' ', e.last_name) AS full_name
       FROM login_master lm
       LEFT JOIN employee_master e ON lm.emp_id = e.emp_id
       WHERE lm.login_id = ?`,
      [loginId],
    );
    if (!row)
      return res.status(404).json({ success: false, message: "Not found" });
    res.json({
      success: true,
      loginId: row.login_id,
      fullName: row.full_name?.trim() || row.username,
      isLoggedIn: row.device_logged_in === 1,
      sessionDevice: row.session_device || null,
      lastLoginAt: row.last_login_at || null,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── AUDIT LOG HELPER ─────────────────────────────────────────────────────────
async function _auditLog(
  empId,
  username,
  status,
  ip,
  deviceInfo,
  failureReason,
) {
  try {
    const deviceStr = deviceInfo
      ? typeof deviceInfo === "string"
        ? deviceInfo
        : JSON.stringify(deviceInfo)
      : null;
    await dbRun(
      `INSERT INTO login_logs (emp_id, username, status, ip_address, device_info, failure_reason, login_time) VALUES (?, ?, ?, ?, ?, ?, NOW())`,
      [
        empId || null,
        username || null,
        status,
        ip,
        deviceStr,
        failureReason || null,
      ],
    );
  } catch (e) {
    console.error("[auditLog]", e.message);
  }
}

// ─── CHANGE PASSWORD ──────────────────────────────────────────────────────────
app.post("/auth/change-password", async (req, res) => {
  const { login_id, new_password, confirm_password, device_id, device_info } =
    req.body;
  const ip =
    (req.headers["x-forwarded-for"] || "").split(",")[0].trim() ||
    req.socket?.remoteAddress ||
    "unknown";

  if (!login_id || !new_password || !confirm_password)
    return res
      .status(400)
      .json({ success: false, message: "All fields required" });
  if (new_password !== confirm_password)
    return res
      .status(400)
      .json({ success: false, message: "Passwords do not match" });
  if (new_password.length < 8)
    return res
      .status(400)
      .json({ success: false, message: "Minimum 8 characters" });
  if (!/[a-zA-Z]/.test(new_password))
    return res
      .status(400)
      .json({ success: false, message: "Must contain a letter" });
  if (!/[0-9]/.test(new_password))
    return res
      .status(400)
      .json({ success: false, message: "Must contain a number" });

  try {
    const user = await dbGet(
      `SELECT login_id, emp_id, role_id, username FROM login_master WHERE login_id=? AND status='Active'`,
      [login_id],
    );
    if (!user)
      return res
        .status(404)
        .json({ success: false, message: "User not found" });

    const hashed = await bcrypt.hash(new_password, 10);
    const sessionToken = crypto.randomUUID();
    const deviceJson = device_info
      ? JSON.stringify({
          brand: device_info.brand || "Unknown",
          model: device_info.model || "Unknown",
          os: device_info.os || "Unknown",
          osVersion: device_info.osVersion || "",
          deviceId: device_info.deviceId || device_id || "unknown",
        })
      : device_id || "unknown";

    await dbRun(
      `UPDATE login_master SET password=?, is_first_login=0, password_updated_at=NOW(), session_token=?, session_device=?, device_logged_in=1, last_login_at=NOW(), failed_attempts=0, locked_until=NULL, updated_at=NOW() WHERE login_id=?`,
      [hashed, sessionToken, deviceJson, login_id],
    );
    await _auditLog(
      user.emp_id,
      user.username,
      "PASSWORD_CHANGED",
      ip,
      device_info,
      null,
    );

    res.json({
      success: true,
      message: "Password changed successfully.",
      loginId: user.login_id,
      empId: user.emp_id,
      roleId: user.role_id,
      username: user.username.trim(),
      sessionToken,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// ─── ADMIN PASSWORD RESET ─────────────────────────────────────────────────────
app.post("/auth/reset-password", async (req, res) => {
  const { emp_id, new_password, confirm_password } = req.body;
  if (!emp_id || !new_password || !confirm_password)
    return res.status(400).json({
      success: false,
      message: "emp_id, new_password, confirm_password required",
    });
  if (new_password !== confirm_password)
    return res
      .status(400)
      .json({ success: false, message: "Passwords do not match" });
  if (new_password.length < 8)
    return res
      .status(400)
      .json({ success: false, message: "Minimum 8 characters" });
  if (!/[a-zA-Z]/.test(new_password))
    return res
      .status(400)
      .json({ success: false, message: "Must contain a letter" });
  if (!/[0-9]/.test(new_password))
    return res
      .status(400)
      .json({ success: false, message: "Must contain a number" });

  try {
    const user = await dbGet(
      `SELECT login_id, emp_id, role_id, username FROM login_master WHERE emp_id=? AND status='Active'`,
      [emp_id],
    );
    if (!user)
      return res
        .status(404)
        .json({ success: false, message: "User not found" });

    const hashed = await bcrypt.hash(new_password, 10);
    await dbRun(
      `UPDATE login_master SET password=?, is_first_login=1, password_updated_at=NOW(), session_token=NULL, session_device=NULL, device_logged_in=0, failed_attempts=0, locked_until=NULL, updated_at=NOW() WHERE emp_id=? AND status='Active'`,
      [hashed, emp_id],
    );
    await _auditLog(
      user.emp_id,
      user.username,
      "PASSWORD_RESET_BY_ADMIN",
      "server",
      null,
      "Admin-triggered reset — all sessions cleared",
    );

    res.json({
      success: true,
      message:
        "Password reset. User logged out from all devices and must change password on next login.",
      loginId: user.login_id,
      empId: user.emp_id,
      roleId: user.role_id,
      username: user.username.trim(),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// ─── LOGIN AUDIT LOGS ─────────────────────────────────────────────────────────
app.get("/auth/login-logs", async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit || "100"), 500);
  const empId = req.query.emp_id || null;
  const status = req.query.status || null;
  let sql = `SELECT log_id, emp_id, username, status, ip_address, device_info, failure_reason, login_time FROM login_logs WHERE 1=1`;
  const params = [];
  if (empId) {
    sql += ` AND emp_id=?`;
    params.push(empId);
  }
  if (status) {
    sql += ` AND status=?`;
    params.push(status);
  }
  sql += ` ORDER BY login_time DESC LIMIT ?`;
  params.push(limit);
  try {
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── TEAM LEADS ───────────────────────────────────────────────────────────────
app.get("/team-leads", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT emp_id AS id, TRIM(CONCAT(first_name, ' ', IFNULL(mid_name, ''), ' ', last_name)) AS name
       FROM employee_master WHERE role_id = 3 AND status = 'Active' ORDER BY first_name ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res
      .status(500)
      .json({ success: false, message: "Failed to fetch team leads" });
  }
});

// ─── LEAVE APPROVED RANGE ─────────────────────────────────────────────────────
app.get("/leaves/approved-range", async (req, res) => {
  const { from, to } = req.query;
  if (!from || !to)
    return res.status(400).json({ error: "from and to required" });
  try {
    const rows = await dbAll(
      `SELECT l.emp_id, l.leave_type, l.status,
              DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS leave_start_date,
              DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS leave_end_date
       FROM leave_master l
       WHERE l.status = 'Approved' AND l.leave_start_date <= ? AND l.leave_end_date >= ?`,
      [to, from],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── LEAVE POLICY ─────────────────────────────────────────────────────────────
app.get("/leave-policy", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT * FROM leave_policy WHERE is_active=1 ORDER BY leave_type`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/leave-policy/:type", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT * FROM leave_policy WHERE leave_type=? AND is_active=1`,
      [req.params.type],
    );
    if (!row)
      return res
        .status(404)
        .json({ success: false, message: "Policy not found" });
    res.json({ success: true, data: row });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/leave-policy/:type", async (req, res) => {
  const {
    total_days,
    carry_forward,
    max_carry_days,
    half_day_allowed,
    effective_from,
  } = req.body;
  if (total_days === undefined || total_days === null)
    return res
      .status(400)
      .json({ success: false, message: "total_days required" });

  try {
    await dbRun(
      `INSERT INTO leave_policy (leave_type, total_days, carry_forward, max_carry_days, half_day_allowed, effective_from)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE total_days=VALUES(total_days), carry_forward=VALUES(carry_forward),
         max_carry_days=VALUES(max_carry_days), half_day_allowed=VALUES(half_day_allowed),
         effective_from=VALUES(effective_from), updated_at=NOW()`,
      [
        req.params.type,
        total_days,
        carry_forward ? 1 : 0,
        max_carry_days ?? 0,
        half_day_allowed !== false ? 1 : 0,
        effective_from || new Date().toISOString().slice(0, 10),
      ],
    );
    res.json({ success: true, message: "Policy saved" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── LEAVE BALANCE HELPERS ────────────────────────────────────────────────────
async function countWorkingDays(from, to) {
  const holidays = await dbAll(
    `SELECT DATE_FORMAT(holiday_date, '%Y-%m-%d') AS hd FROM holiday_master WHERE holiday_date BETWEEN ? AND ?`,
    [from, to],
  );
  const holidaySet = new Set(holidays.map((h) => h.hd));
  let count = 0;
  const cursor = new Date(from + "T00:00:00");
  const end = new Date(to + "T00:00:00");
  while (cursor <= end) {
    const dow = cursor.getDay();
    const ds = cursor.toISOString().slice(0, 10);
    if (dow !== 0 && dow !== 6 && !holidaySet.has(ds)) count++;
    cursor.setDate(cursor.getDate() + 1);
  }
  return count;
}

async function ensureLeaveBalance(empId, leaveType, year) {
  // Skip Comp-Off — handled separately
  if (leaveType === "Comp-Off") return null;

  const existing = await dbGet(
    `SELECT * FROM leave_balance WHERE emp_id=? AND leave_type=? AND year=?`,
    [empId, leaveType, year],
  );
  if (existing) return existing;

  // Use monthly_limit * 12 for yearly allocation, 0 for unlimited
  const policy = await dbGet(
    `SELECT monthly_limit, is_unlimited FROM leave_policy WHERE leave_type=? AND is_active=1`,
    [leaveType],
  );

  const allocated = policy?.is_unlimited
    ? 0 // unlimited types store 0, handled at display level
    : parseFloat(policy?.monthly_limit ?? 1) * 12;

  await dbRun(
    `INSERT IGNORE INTO leave_balance (emp_id, leave_type, year, allocated_days)
     VALUES (?, ?, ?, ?)`,
    [empId, leaveType, year, allocated],
  );

  return dbGet(
    `SELECT * FROM leave_balance WHERE emp_id=? AND leave_type=? AND year=?`,
    [empId, leaveType, year],
  );
}

async function syncLeaveBalance(empId, leaveType, year) {
  // Skip Comp-Off — handled separately
  if (leaveType === "Comp-Off") return;

  const usedRow = await dbGet(
    `SELECT IFNULL(SUM(number_of_days), 0) AS v
     FROM leave_master
     WHERE emp_id=?
       AND leave_type=?
       AND YEAR(leave_start_date)=?
       AND status='Approved'`,
    [empId, leaveType, year],
  );

  const pendingRow = await dbGet(
    `SELECT IFNULL(SUM(number_of_days), 0) AS v
     FROM leave_master
     WHERE emp_id=?
       AND leave_type=?
       AND YEAR(leave_start_date)=?
       AND status IN ('Pending_TL','Pending_Manager')`,
    [empId, leaveType, year],
  );

  // Only update if the row exists (ensureLeaveBalance must be called first)
  await dbRun(
    `UPDATE leave_balance
     SET used_days=?, pending_days=?, updated_at=NOW()
     WHERE emp_id=? AND leave_type=? AND year=?`,
    [usedRow.v, pendingRow.v, empId, leaveType, year],
  );
}
// ─── LEAVE BALANCE API ────────────────────────────────────────────────────────
// Replace the entire GET /employees/:empId/leave-balance endpoint with this:
app.get("/employees/:empId/leave-balance", async (req, res) => {
  const { empId } = req.params;
  const year = parseInt(req.query.year) || new Date().getFullYear();

  try {
    const policies = await dbAll(
      `SELECT * FROM leave_policy WHERE is_active = 1`,
    );

    if (!policies || policies.length === 0) {
      return res.json({ success: true, data: [] });
    }

    const result = [];

    for (const policy of policies) {
      const leaveType = policy.leave_type;
      if (leaveType === "Comp-Off") continue;

      const usedRow = await dbGet(
        `SELECT IFNULL(SUM(number_of_days), 0) AS used
         FROM leave_master
         WHERE emp_id = ? AND leave_type = ?
           AND YEAR(leave_start_date) = ?
           AND status = 'Approved'`,
        [empId, leaveType, year],
      );

      const pendingRow = await dbGet(
        `SELECT IFNULL(SUM(number_of_days), 0) AS pending
         FROM leave_master
         WHERE emp_id = ? AND leave_type = ?
           AND YEAR(leave_start_date) = ?
           AND status IN ('Pending_TL','Pending_Manager')`,
        [empId, leaveType, year],
      );

      // This month usage — for Casual/Sick monthly cap display
      const thisMonthRow = await dbGet(
        `SELECT IFNULL(SUM(number_of_days), 0) AS used_month
         FROM leave_master
         WHERE emp_id = ? AND leave_type = ?
           AND YEAR(leave_start_date) = YEAR(CURDATE())
           AND MONTH(leave_start_date) = MONTH(CURDATE())
           AND status NOT IN ('Cancelled','Rejected_By_Manager')`,
        [empId, leaveType],
      );

      const used = parseFloat(usedRow?.used ?? 0);
      const pending = parseFloat(pendingRow?.pending ?? 0);
      const usedThisMonth = parseFloat(thisMonthRow?.used_month ?? 0);
      const monthlyLimit = parseFloat(policy.monthly_limit ?? 0);
      const isUnlimited = policy.is_unlimited === 1;

      const yearlyAllowed = isUnlimited ? null : monthlyLimit * 12;
      const remaining = isUnlimited
        ? null
        : Math.max((yearlyAllowed ?? 0) - used - pending, 0);
      const remainingThisMonth = isUnlimited
        ? null
        : Math.max(monthlyLimit - usedThisMonth, 0);

      result.push({
        leave_type: leaveType,
        is_unlimited: isUnlimited,
        monthly_limit: monthlyLimit,
        allocated_days: yearlyAllowed,
        total_available: yearlyAllowed,
        used_days: used,
        pending_days: pending,
        remaining_days: remaining,
        used_this_month: usedThisMonth,
        remaining_this_month: remainingThisMonth,
        half_day_allowed: 1,
      });
    }

    return res.json({ success: true, data: result });
  } catch (err) {
    console.error("❌ Leave balance error:", err);
    return res.status(500).json({ success: false, message: err.message });
  }
});
app.get("/employees/:empId/leave-balance/:type", async (req, res) => {
  const year = parseInt(req.query.year) || new Date().getFullYear();
  const { empId, type } = req.params;
  try {
    await ensureLeaveBalance(empId, type, year);
    await syncLeaveBalance(empId, type, year);
    const row = await dbGet(
      `SELECT lb.leave_type, lb.year, lb.allocated_days, lb.carry_forward AS carried_forward,
              (lb.allocated_days + lb.carry_forward) AS total_available,
              lb.used_days, lb.pending_days,
              (lb.allocated_days + lb.carry_forward - lb.used_days - lb.pending_days) AS remaining_days,
              lp.half_day_allowed
       FROM leave_balance lb
       LEFT JOIN leave_policy lp ON lb.leave_type = lp.leave_type AND lp.is_active = 1
       WHERE lb.emp_id=? AND lb.leave_type=? AND lb.year=?`,
      [empId, type, year],
    );
    if (!row)
      return res
        .status(404)
        .json({ success: false, message: "Balance not found" });
    res.json({ success: true, data: row });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/working-days", async (req, res) => {
  const { from, to } = req.query;
  if (!from || !to)
    return res.status(400).json({ error: "from and to required (YYYY-MM-DD)" });
  try {
    const days = await countWorkingDays(from, to);
    res.json({ success: true, from, to, working_days: days });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/leave/sync-balance", async (req, res) => {
  const { emp_id, leave_type, year } = req.body;
  if (!emp_id || !leave_type || !year)
    return res
      .status(400)
      .json({ success: false, message: "emp_id, leave_type, year required" });
  try {
    await ensureLeaveBalance(emp_id, leave_type, year);
    await syncLeaveBalance(emp_id, leave_type, year);
    const bal = await dbGet(
      `SELECT * FROM leave_balance WHERE emp_id=? AND leave_type=? AND year=?`,
      [emp_id, leave_type, year],
    );
    res.json({ success: true, balance: bal });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── YEAR-END CARRY-FORWARD ───────────────────────────────────────────────────
app.post("/leave/year-end-process", async (req, res) => {
  const fromYear = parseInt(req.query.year || req.body.year);
  if (!fromYear || fromYear < 2000 || fromYear > 2100)
    return res
      .status(400)
      .json({ success: false, message: "year param required (e.g. 2024)" });
  const toYear = fromYear + 1;

  try {
    const policies = await dbAll(
      `SELECT leave_type, total_days, carry_forward, max_carry_days FROM leave_policy WHERE is_active=1`,
    );
    const employees = await dbAll(
      `SELECT emp_id FROM employee_master WHERE status='Active'`,
    );
    let processed = 0;
    const logs = [];

    for (const emp of employees) {
      for (const policy of policies) {
        await syncLeaveBalance(emp.emp_id, policy.leave_type, fromYear);
        const bal = await dbGet(
          `SELECT allocated_days, carry_forward AS cf, used_days, pending_days FROM leave_balance WHERE emp_id=? AND leave_type=? AND year=?`,
          [emp.emp_id, policy.leave_type, fromYear],
        );
        const balanceBefore = bal
          ? bal.allocated_days + bal.cf - bal.used_days - bal.pending_days
          : 0;
        let carriedDays = 0,
          lapsedDays = 0;

        if (policy.carry_forward && balanceBefore > 0) {
          carriedDays = policy.max_carry_days
            ? Math.min(balanceBefore, policy.max_carry_days)
            : balanceBefore;
          lapsedDays = balanceBefore - carriedDays;
        } else {
          lapsedDays = Math.max(balanceBefore, 0);
        }

        await dbRun(
          `INSERT INTO leave_balance (emp_id, leave_type, year, allocated_days, carry_forward)
           VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE carry_forward=VALUES(carry_forward), updated_at=NOW()`,
          [
            emp.emp_id,
            policy.leave_type,
            toYear,
            policy.total_days,
            carriedDays,
          ],
        );
        await dbRun(
          `INSERT INTO leave_carry_forward_log (emp_id, leave_type, from_year, to_year, balance_before, carried_days, lapsed_days)
           VALUES (?,?,?,?,?,?,?)`,
          [
            emp.emp_id,
            policy.leave_type,
            fromYear,
            toYear,
            balanceBefore,
            carriedDays,
            lapsedDays,
          ],
        );
        logs.push({
          emp_id: emp.emp_id,
          leave_type: policy.leave_type,
          balance_before: balanceBefore,
          carried: carriedDays,
          lapsed: lapsedDays,
        });
        processed++;
      }
    }

    res.json({
      success: true,
      from_year: fromYear,
      to_year: toYear,
      processed_records: processed,
      summary: logs,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/leave/carry-forward-log", async (req, res) => {
  const { emp_id, year } = req.query;
  try {
    let sql = `SELECT * FROM leave_carry_forward_log WHERE 1=1`;
    const params = [];
    if (emp_id) {
      sql += " AND emp_id=?";
      params.push(emp_id);
    }
    if (year) {
      sql += " AND from_year=?";
      params.push(year);
    }
    sql += " ORDER BY processed_at DESC LIMIT 500";
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── REGULARIZATION ───────────────────────────────────────────────────────────
app.post("/regularization", async (req, res) => {
  const { emp_id, work_date, expected_in, expected_out, reason } = req.body;
  if (!emp_id || !work_date || !reason)
    return res.status(400).json({
      success: false,
      message: "emp_id, work_date, reason are required",
    });
  if (!expected_in && !expected_out)
    return res.status(400).json({
      success: false,
      message: "At least one of expected_in or expected_out is required",
    });

  try {
    const employee = await dbGet(
      `SELECT role_id FROM employee_master WHERE emp_id=? AND status='Active'`,
      [emp_id],
    );
    if (!employee)
      return res
        .status(404)
        .json({ success: false, message: "Employee not found" });

    const duplicate = await dbGet(
      `SELECT reg_id FROM regularization_request WHERE emp_id=? AND work_date=? AND status IN ('Pending_TL','Pending_Manager')`,
      [emp_id, work_date],
    );
    if (duplicate)
      return res.status(409).json({
        success: false,
        message:
          "A pending regularization request already exists for this date",
      });

    let status;
    switch (employee.role_id) {
      case 1:
        status = "Pending_TL";
        break;
      case 2:
      case 3:
        status = "Pending_Manager";
        break;
      case 8:
        status = "Approved";
        break;
      default:
        status = "Pending_TL";
    }

    const result = await dbRun(
      `INSERT INTO regularization_request (emp_id, work_date, expected_in, expected_out, reason, status, created_at, updated_at)
       VALUES (?,?,?,?,?,?,NOW(),NOW())`,
      [
        emp_id,
        work_date,
        expected_in || null,
        expected_out || null,
        reason,
        status,
      ],
    );

    if (status === "Approved") {
      await applyRegularization(
        emp_id,
        work_date,
        expected_in || null,
        expected_out || null,
      );
    }

    res.json({
      success: true,
      reg_id: result.insertId,
      status,
      message:
        status === "Approved"
          ? "Regularization auto-approved and applied"
          : status === "Pending_Manager"
            ? "Regularization sent to Manager"
            : "Regularization sent to Team Lead for review",
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

async function applyRegularization(empId, workDate, expectedIn, expectedOut) {
  const session = await dbGet(
    `SELECT id FROM tracking_sessions WHERE employee_id=? AND work_date=? ORDER BY id ASC LIMIT 1`,
    [empId, workDate],
  );
  if (!session && expectedIn) {
    await dbRun(
      `INSERT INTO tracking_sessions (employee_id, work_date, started_at, ended_at, session_number, end_reason, is_late) VALUES (?,?,?,?,1,'regularized',0)`,
      [
        empId,
        workDate,
        `${workDate} ${expectedIn}`,
        expectedOut ? `${workDate} ${expectedOut}` : null,
      ],
    );
  } else if (session) {
    if (expectedIn)
      await dbRun(`UPDATE tracking_sessions SET started_at=? WHERE id=?`, [
        `${workDate} ${expectedIn}`,
        session.id,
      ]);
    if (expectedOut)
      await dbRun(
        `UPDATE tracking_sessions SET ended_at=?, end_reason='regularized' WHERE id=?`,
        [`${workDate} ${expectedOut}`, session.id],
      );
  }
}

app.get("/regularization", async (req, res) => {
  const { emp_id, status } = req.query;
  if (!emp_id)
    return res.status(400).json({ success: false, message: "emp_id required" });
  try {
    let sql = `SELECT r.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, DATE_FORMAT(r.work_date,'%Y-%m-%d') AS work_date FROM regularization_request r JOIN employee_master e ON r.emp_id = e.emp_id WHERE r.emp_id=?`;
    const params = [emp_id];
    if (status) {
      sql += " AND r.status=?";
      params.push(status);
    }
    sql += " ORDER BY r.work_date DESC";
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/regularization/pending-tl", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id=?`,
      [login_id],
    );
    if (!tlUser)
      return res.status(404).json({ success: false, message: "TL not found" });
    const rows = await dbAll(
      `SELECT r.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(r.work_date,'%Y-%m-%d') AS work_date
       FROM regularization_request r JOIN employee_master e ON r.emp_id = e.emp_id
       LEFT JOIN department_master d ON e.department_id = d.department_id
       WHERE r.status='Pending_TL' AND e.tl_id=? ORDER BY r.work_date DESC`,
      [tlUser.emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/regularization/pending-manager", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT r.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(r.work_date,'%Y-%m-%d') AS work_date
       FROM regularization_request r JOIN employee_master e ON r.emp_id = e.emp_id
       LEFT JOIN department_master d ON e.department_id = d.department_id
       WHERE r.status='Pending_Manager' ORDER BY r.created_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/regularization/:regId/tl-action", async (req, res) => {
  const { action, remark, login_id } = req.body;
  if (!action || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "action and login_id required" });
  if (!["approve", "reject"].includes(action))
    return res
      .status(400)
      .json({ success: false, message: "action must be approve or reject" });
  if (action === "reject" && !remark?.trim())
    return res
      .status(400)
      .json({ success: false, message: "remark required for rejection" });

  try {
    const reg = await dbGet(
      `SELECT * FROM regularization_request WHERE reg_id=? AND status='Pending_TL'`,
      [req.params.regId],
    );
    if (!reg)
      return res.status(404).json({
        success: false,
        message: "Request not found or not in Pending_TL state",
      });
    const newStatus =
      action === "approve" ? "Pending_Manager" : "Rejected_By_TL";
    await dbRun(
      `UPDATE regularization_request SET status=?, tl_action_by=?, tl_action_at=NOW(), tl_remark=?, updated_at=NOW() WHERE reg_id=?`,
      [newStatus, login_id, remark || null, req.params.regId],
    );
    res.json({ success: true, status: newStatus });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/regularization/:regId/manager-action", async (req, res) => {
  const { action, remark, login_id } = req.body;
  if (!action || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "action and login_id required" });
  if (!["approve", "reject"].includes(action))
    return res
      .status(400)
      .json({ success: false, message: "action must be approve or reject" });
  if (action === "reject" && !remark?.trim())
    return res
      .status(400)
      .json({ success: false, message: "remark required for rejection" });

  try {
    const reg = await dbGet(
      `SELECT * FROM regularization_request WHERE reg_id = ? AND status = 'Pending_Manager'`,
      [req.params.regId], // ← was being used as array index, not params!
    );
    if (!reg)
      return res.status(404).json({
        success: false,
        message: "Request not found or already processed",
      });

    if (action === "reject") {
      await dbRun(
        `UPDATE regularization_request SET status='Rejected_By_Manager', mgr_action_by=?, mgr_action_at=NOW(), mgr_remark=?, updated_at=NOW() WHERE reg_id=?`,
        [login_id, remark, req.params.regId],
      );
      return res.json({ success: true, status: "Rejected_By_Manager" });
    }

    await dbRun(
      `UPDATE regularization_request SET status='Approved', mgr_action_by=?, mgr_action_at=NOW(), mgr_remark=?, updated_at=NOW() WHERE reg_id=?`,
      [login_id, remark || null, req.params.regId],
    );
    await applyRegularization(
      reg.emp_id,
      reg.work_date,
      reg.expected_in,
      reg.expected_out,
    );
    res.json({
      success: true,
      status: "Approved",
      message: "Regularization applied to attendance",
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});
app.put("/regularization/:regId/cancel", async (req, res) => {
  const { emp_id } = req.body;
  if (!emp_id)
    return res.status(400).json({ success: false, message: "emp_id required" });
  try {
    const result = await dbRun(
      `UPDATE regularization_request SET status='Cancelled', updated_at=NOW() WHERE reg_id=? AND emp_id=? AND status IN ('Pending_TL','Pending_Manager')`,
      [req.params.regId, emp_id],
    );
    if (result.affectedRows === 0)
      return res.status(400).json({
        success: false,
        message: "Request not found or cannot be cancelled",
      });
    res.json({ success: true, message: "Regularization cancelled" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/regularization/all-history", async (req, res) => {
  const { status, from, to } = req.query;
  try {
    let sql = `SELECT r.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(r.work_date,'%Y-%m-%d') AS work_date FROM regularization_request r JOIN employee_master e ON r.emp_id = e.emp_id LEFT JOIN department_master d ON e.department_id = d.department_id WHERE 1=1`;
    const params = [];
    if (status) {
      sql += " AND r.status=?";
      params.push(status);
    }
    if (from) {
      sql += " AND r.work_date >= ?";
      params.push(from);
    }
    if (to) {
      sql += " AND r.work_date <= ?";
      params.push(to);
    }
    sql += " ORDER BY r.created_at DESC LIMIT 500";
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/regularization/tl-history", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id=?`,
      [login_id],
    );
    if (!tlUser)
      return res.status(404).json({ success: false, message: "TL not found" });
    const rows = await dbAll(
      `SELECT r.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, DATE_FORMAT(r.work_date,'%Y-%m-%d') AS work_date
       FROM regularization_request r JOIN employee_master e ON r.emp_id = e.emp_id
       WHERE e.tl_id=? ORDER BY r.work_date DESC`,
      [tlUser.emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/regularization/pending-count", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT COUNT(*) AS count FROM regularization_request WHERE status IN ('Pending_TL','Pending_Manager')`,
    );
    res.json({ success: true, count: row?.count || 0 });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

async function autoGrantCompoff(db, empId, workDate, sessionId) {
  const dateStr = workDate.toISOString().split("T")[0]; // "YYYY-MM-DD"
  const dayOfWeek = workDate.getDay(); // 0 = Sunday, 6 = Saturday

  const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;

  // ── 1. Check holiday master ───────────────────────────────────────────────
  let isHoliday = false;
  let holidayName = null;

  const [holidayRows] = await db.query(
    `SELECT holiday_name FROM holiday_master
      WHERE holiday_date = ? AND is_active = 1
      LIMIT 1`,
    [dateStr],
  );

  if (holidayRows.length > 0) {
    isHoliday = true;
    holidayName = holidayRows[0].holiday_name;
  }

  if (!isWeekend && !isHoliday) {
    // Normal working day — nothing to do
    return { granted: false };
  }

  // ── 2. Prevent duplicate comp-off for same emp + date ────────────────────
  const [existing] = await db.query(
    `SELECT compoff_id FROM compoff_earn
      WHERE emp_id = ? AND worked_date = ?
      LIMIT 1`,
    [empId, dateStr],
  );

  if (existing.length > 0) {
    // Already granted today — idempotent, skip silently
    return { granted: false, reason: "duplicate" };
  }

  // ── 3. Build reason string ────────────────────────────────────────────────
  let workType = isHoliday
    ? `Holiday (${holidayName})`
    : dayOfWeek === 0
      ? "Sunday"
      : "Saturday";

  const reason = `Auto comp-off: Worked on ${workType} — ${dateStr}`;

  // ── 4. Insert comp-off earn record (auto-approved, no approval flow) ──────
  const [result] = await db.query(
    `INSERT INTO compoff_earn
       (emp_id, worked_date, worked_hours, reason,
        status, auto_granted, attendance_session_id,
        created_at, updated_at)
     VALUES
       (?, ?, 8.00, ?,
        'approved', 1, ?,
        NOW(), NOW())`,
    [empId, dateStr, reason, sessionId],
  );

  // ── 5. Credit comp-off balance (upsert into compoff_transactions) ─────────────
  //  If you maintain a balance table:
  await db.query(
    `INSERT INTO compoff_transactions (emp_id, available_days, updated_at)
       VALUES (?, 1.00, NOW())
     ON DUPLICATE KEY UPDATE
       available_days = available_days + 1.00,
       updated_at = NOW()`,
    [empId],
  );

  console.log(
    `[AutoCompoff] emp=${empId} date=${dateStr} type=${workType} compoff_earn_id=${result.insertId}`,
  );

  return {
    granted: true,
    compoffEarnId: result.insertId,
    workType,
    date: dateStr,
  };
}
async function startSessionHandler(req, res, db) {
  const { emp_id } = req.body;
  const now = new Date();
  const today = now.toISOString().split("T")[0];

  try {
    // ── A. Your existing shift / late calculation (keep as-is) ──────────────
    const [shiftRows] = await db.query(
      `SELECT shift_start, late_threshold_minutes
         FROM employee_shifts
        WHERE emp_id = ? AND is_active = 1
        LIMIT 1`,
      [emp_id],
    );

    let isLate = false,
      lateMinutes = 0,
      lateHours = 0,
      lateText = null;

    if (shiftRows.length > 0) {
      const shift = shiftRows[0];
      const [sh, sm] = shift.shift_start.split(":").map(Number);
      const shiftStart = new Date(now);
      shiftStart.setHours(sh, sm + (shift.late_threshold_minutes || 0), 0, 0);

      if (now > shiftStart) {
        const diffMs = now - shiftStart;
        lateMinutes = Math.floor(diffMs / 60000);
        lateHours = +(lateMinutes / 60).toFixed(2);
        isLate = true;
        if (lateMinutes >= 240) {
          lateText = "Half Day";
        } else {
          const h = Math.floor(lateMinutes / 60);
          const m = lateMinutes % 60;
          lateText = h > 0 ? `${h}hr ${m}min` : `${m}min`;
        }
      }
    }

    // ── B. Insert attendance session ─────────────────────────────────────────
    const [sessionResult] = await db.query(
      `INSERT INTO attendance_sessions
         (emp_id, in_time, status, is_late, late_minutes, late_hours, late_text, created_at)
       VALUES (?, NOW(), 'in_progress', ?, ?, ?, ?, NOW())`,
      [emp_id, isLate, lateMinutes, lateHours, lateText],
    );

    const sessionId = sessionResult.insertId;

    // ── C. AUTO COMP-OFF CHECK ───────────────────────────────────────────────
    const compoffResult = await autoGrantCompoff(db, emp_id, now, sessionId);

    // ── D. Respond ───────────────────────────────────────────────────────────
    return res.json({
      success: true,
      session_id: sessionId,
      is_late: isLate,
      late_minutes: lateMinutes,
      late_hours: lateHours,
      late_text: lateText,
      // Let Flutter know comp-off was granted so UI can show a toast
      compoff_granted: compoffResult.granted,
      compoff_work_type: compoffResult.workType ?? null,
    });
  } catch (err) {
    console.error("[startSession]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = { autoGrantCompoff, startSessionHandler };

// ─── COMP-OFF ─────────────────────────────────────────────────────────────────
async function getCompoffPolicy() {
  const p = await dbGet(`SELECT * FROM compoff_policy WHERE policy_id = 1`);
  return (
    p || {
      expiry_days: 90,
      max_accumulate_days: 10,
      min_hours_for_full: 6.0,
      min_hours_for_half: 3.0,
    }
  );
}

async function getDateType(dateStr) {
  const d = new Date(dateStr + "T00:00:00");
  const dow = d.getDay();
  const isWeekend = dow === 0 || dow === 6;
  const holiday = await dbGet(
    `SELECT holiday_name FROM holiday_master WHERE holiday_date = ?`,
    [dateStr],
  );
  if (isWeekend && holiday) return "Both";
  if (holiday) return "Holiday";
  if (isWeekend) return "Weekend";
  return null;
}

function compoffInitialStatus(roleId) {
  switch (roleId) {
    case 1:
      return "Pending_TL";
    case 2:
    case 3:
      return "Pending_Manager";
    case 8:
      return "Approved";
    default:
      return "Pending_TL";
  }
}

app.get("/compoff/policy", async (req, res) => {
  try {
    res.json({ success: true, data: await getCompoffPolicy() });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/compoff/policy", async (req, res) => {
  const {
    expiry_days,
    max_accumulate_days,
    min_hours_for_full,
    min_hours_for_half,
    auto_expire_cron,
  } = req.body;
  try {
    await dbRun(
      `UPDATE compoff_policy SET expiry_days=COALESCE(?,expiry_days), max_accumulate_days=COALESCE(?,max_accumulate_days), min_hours_for_full=COALESCE(?,min_hours_for_full), min_hours_for_half=COALESCE(?,min_hours_for_half), auto_expire_cron=COALESCE(?,auto_expire_cron), updated_at=NOW() WHERE policy_id=1`,
      [
        expiry_days ?? null,
        max_accumulate_days ?? null,
        min_hours_for_full ?? null,
        min_hours_for_half ?? null,
        auto_expire_cron != null ? (auto_expire_cron ? 1 : 0) : null,
      ],
    );
    res.json({ success: true, message: "Policy updated" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/employees/:empId/compoff-balance", async (req, res) => {
  try {
    const balance = await getCompoffBalance(req.params.empId);
    const expiring = await dbAll(
      `SELECT compoff_id, worked_date, days_earned, expiry_date, DATEDIFF(expiry_date, CURDATE()) AS days_until_expiry
       FROM compoff_transactions WHERE emp_id=? AND status='Approved' AND expiry_date IS NOT NULL AND expiry_date >= CURDATE() AND expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) ORDER BY expiry_date ASC`,
      [req.params.empId],
    );
    res.json({ success: true, balance, expiring_soon: expiring });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/compoff/earn", async (req, res) => {
  const { emp_id, worked_date, worked_hours, reason } = req.body;
  if (!emp_id || !worked_date || !reason)
    return res.status(400).json({
      success: false,
      message: "emp_id, worked_date, reason are required",
    });

  try {
    const employee = await dbGet(
      `SELECT role_id FROM employee_master WHERE emp_id=? AND status='Active'`,
      [emp_id],
    );
    if (!employee)
      return res
        .status(404)
        .json({ success: false, message: "Employee not found" });

    const dayType = await getDateType(worked_date);
    if (!dayType)
      return res.status(400).json({
        success: false,
        message: "Comp-off can only be earned for weekends or public holidays",
        worked_date,
      });

    const duplicate = await dbGet(
      `SELECT compoff_id, status FROM compoff_transactions WHERE emp_id=? AND worked_date=?`,
      [emp_id, worked_date],
    );
    if (duplicate)
      return res.status(409).json({
        success: false,
        message: `A comp-off request for ${worked_date} already exists (status: ${duplicate.status})`,
      });

    const policy = await getCompoffPolicy();
    let daysEarned = 1.0;
    if (worked_hours != null) {
      if (worked_hours >= policy.min_hours_for_full) daysEarned = 1.0;
      else if (worked_hours >= policy.min_hours_for_half) daysEarned = 0.5;
      else
        return res.status(400).json({
          success: false,
          message: `Minimum ${policy.min_hours_for_half}h required to earn comp-off (worked: ${worked_hours}h)`,
        });
    }

    const balance = await getCompoffBalance(emp_id);
    if (balance.available + daysEarned > policy.max_accumulate_days)
      return res.status(400).json({
        success: false,
        message: `Cannot exceed max comp-off balance of ${policy.max_accumulate_days} days (current: ${balance.available})`,
      });

    const status = compoffInitialStatus(employee.role_id);
    const result = await dbRun(
      `INSERT INTO compoff_transactions (emp_id, worked_date, worked_hours, reason, day_type, days_earned, status, created_at, updated_at) VALUES (?,?,?,?,?,?,?,NOW(),NOW())`,
      [
        emp_id,
        worked_date,
        worked_hours ?? null,
        reason,
        dayType,
        daysEarned,
        status,
      ],
    );

    if (status === "Approved") {
      const expiryDate = new Date();
      expiryDate.setDate(expiryDate.getDate() + policy.expiry_days);
      await dbRun(
        `UPDATE compoff_transactions SET expiry_date=? WHERE compoff_id=?`,
        [expiryDate.toISOString().slice(0, 10), result.insertId],
      );
    }

    res.json({
      success: true,
      compoff_id: result.insertId,
      days_earned: daysEarned,
      day_type: dayType,
      status,
      message:
        status === "Approved"
          ? "Comp-off auto-approved"
          : status === "Pending_Manager"
            ? "Comp-off request sent to Manager"
            : "Comp-off request sent to Team Lead",
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/earn", async (req, res) => {
  const { emp_id, status } = req.query;
  if (!emp_id)
    return res.status(400).json({ success: false, message: "emp_id required" });
  try {
    let sql = `SELECT c.*, DATE_FORMAT(c.worked_date,'%Y-%m-%d') AS worked_date, DATE_FORMAT(c.expiry_date,'%Y-%m-%d') AS expiry_date, DATEDIFF(c.expiry_date, CURDATE()) AS days_until_expiry FROM compoff_transactions c WHERE c.emp_id=?`;
    const params = [emp_id];
    if (status) {
      sql += " AND c.status=?";
      params.push(status);
    }
    sql += " ORDER BY c.worked_date DESC";
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/compoff/earn/:compoffId/cancel", async (req, res) => {
  const { emp_id } = req.body;
  if (!emp_id)
    return res.status(400).json({ success: false, message: "emp_id required" });
  try {
    const result = await dbRun(
      `UPDATE compoff_transactions SET status='Cancelled', updated_at=NOW() WHERE compoff_id=? AND emp_id=? AND status IN ('Pending_TL','Pending_Manager')`,
      [req.params.compoffId, emp_id],
    );
    if (result.affectedRows === 0)
      return res.status(400).json({
        success: false,
        message: "Request not found or cannot be cancelled",
      });
    res.json({ success: true, message: "Comp-off earn request cancelled" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/compoff/earn/:compoffId/tl-action", async (req, res) => {
  const { action, remark, login_id } = req.body;
  if (!action || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "action and login_id required" });
  if (!["approve", "reject"].includes(action))
    return res
      .status(400)
      .json({ success: false, message: "action must be approve or reject" });
  if (action === "reject" && !remark?.trim())
    return res
      .status(400)
      .json({ success: false, message: "remark required for rejection" });
  try {
    const record = await dbGet(
      `SELECT * FROM compoff_transactions WHERE compoff_id=? AND status='Pending_TL'`,
      [req.params.compoffId],
    );
    if (!record)
      return res.status(404).json({
        success: false,
        message: "Request not found or not in Pending_TL state",
      });
    const newStatus =
      action === "approve" ? "Pending_Manager" : "Rejected_By_TL";
    await dbRun(
      `UPDATE compoff_transactions SET status=?, tl_action_by=?, tl_action_at=NOW(), tl_remark=?, updated_at=NOW() WHERE compoff_id=?`,
      [newStatus, login_id, remark || null, req.params.compoffId],
    );
    res.json({ success: true, status: newStatus });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/compoff/earn/:compoffId/manager-action", async (req, res) => {
  const { action, remark, login_id } = req.body;
  if (!action || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "action and login_id required" });
  if (!["approve", "reject"].includes(action))
    return res
      .status(400)
      .json({ success: false, message: "action must be approve or reject" });
  if (action === "reject" && !remark?.trim())
    return res
      .status(400)
      .json({ success: false, message: "remark required for rejection" });
  try {
    const record = await dbGet(
      `SELECT * FROM compoff_transactions WHERE compoff_id=? AND status IN ('Pending_Manager','Pending_TL')`,
      [req.params.compoffId],
    );
    if (!record)
      return res.status(404).json({
        success: false,
        message: "Request not found or already processed",
      });
    if (action === "reject") {
      await dbRun(
        `UPDATE compoff_transactions SET status='Rejected_By_Manager', mgr_action_by=?, mgr_action_at=NOW(), mgr_remark=?, updated_at=NOW() WHERE compoff_id=?`,
        [login_id, remark, req.params.compoffId],
      );
      return res.json({ success: true, status: "Rejected_By_Manager" });
    }
    const policy = await getCompoffPolicy();
    const expiryDate = new Date();
    expiryDate.setDate(expiryDate.getDate() + policy.expiry_days);
    const expiryStr = expiryDate.toISOString().slice(0, 10);
    await dbRun(
      `UPDATE compoff_transactions SET status='Approved', mgr_action_by=?, mgr_action_at=NOW(), mgr_remark=?, expiry_date=?, updated_at=NOW() WHERE compoff_id=?`,
      [login_id, remark || null, expiryStr, req.params.compoffId],
    );
    res.json({
      success: true,
      status: "Approved",
      expiry_date: expiryStr,
      message: `Comp-off approved. Valid until ${expiryStr}`,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/earn/pending-tl", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id=?`,
      [login_id],
    );
    if (!tlUser)
      return res.status(404).json({ success: false, message: "TL not found" });
    const rows = await dbAll(
      `SELECT c.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(c.worked_date,'%Y-%m-%d') AS worked_date
       FROM compoff_transactions c JOIN employee_master e ON c.emp_id=e.emp_id LEFT JOIN department_master d ON e.department_id=d.department_id
       WHERE c.status='Pending_TL' AND e.tl_id=? ORDER BY c.worked_date DESC`,
      [tlUser.emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/earn/pending-manager", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT c.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(c.worked_date,'%Y-%m-%d') AS worked_date
       FROM compoff_transactions c JOIN employee_master e ON c.emp_id=e.emp_id LEFT JOIN department_master d ON e.department_id=d.department_id
       WHERE c.status='Pending_Manager' ORDER BY c.created_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/compoff/avail", async (req, res) => {
  const { emp_id, compoff_id, avail_date, days_used = 1.0, reason } = req.body;
  if (!emp_id || !avail_date)
    return res
      .status(400)
      .json({ success: false, message: "emp_id and avail_date are required" });

  try {
    const employee = await dbGet(
      `SELECT role_id FROM employee_master WHERE emp_id=? AND status='Active'`,
      [emp_id],
    );
    if (!employee)
      return res
        .status(404)
        .json({ success: false, message: "Employee not found" });

    const dayType = await getDateType(avail_date);
    if (dayType)
      return res.status(400).json({
        success: false,
        message: `Cannot avail comp-off on a ${dayType} (${avail_date})`,
      });

    const today = new Date().toISOString().slice(0, 10);
    if (avail_date <= today)
      return res
        .status(400)
        .json({ success: false, message: "avail_date must be a future date" });

    const dupAvail = await dbGet(
      `SELECT avail_id FROM compoff_availed WHERE emp_id=? AND avail_date=? AND status NOT IN ('Rejected_By_TL','Rejected_By_Manager','Cancelled')`,
      [emp_id, avail_date],
    );
    if (dupAvail)
      return res.status(409).json({
        success: false,
        message: "A comp-off avail request for this date already exists",
      });

    const balance = await getCompoffBalance(emp_id);
    if (balance.available < days_used)
      return res.status(400).json({
        success: false,
        message: `Insufficient comp-off balance. Available: ${balance.available}, Requested: ${days_used}`,
        available: balance.available,
        requested: days_used,
      });

    let resolvedCompoffId = compoff_id || null;
    if (compoff_id) {
      const earnRecord = await dbGet(
        `SELECT compoff_id, days_earned, expiry_date FROM compoff_transactions WHERE compoff_id=? AND emp_id=? AND status='Approved' AND (expiry_date IS NULL OR expiry_date >= CURDATE())`,
        [compoff_id, emp_id],
      );
      if (!earnRecord)
        return res.status(400).json({
          success: false,
          message:
            "Specified comp-off record not found, not approved, or expired",
        });
      const usedOnThis = await dbGet(
        `SELECT IFNULL(SUM(days_used),0) AS used FROM compoff_availed WHERE compoff_id=? AND status='Approved'`,
        [compoff_id],
      );
      const remaining =
        earnRecord.days_earned - (parseFloat(usedOnThis.used) || 0);
      if (remaining < days_used)
        return res.status(400).json({
          success: false,
          message: `Only ${remaining} day(s) remain on comp-off #${compoff_id}`,
        });
    } else {
      const oldest = await dbGet(
        `SELECT ce.compoff_id FROM compoff_transactions ce WHERE ce.emp_id=? AND ce.status='Approved' AND (ce.expiry_date IS NULL OR ce.expiry_date >= CURDATE()) AND (ce.days_earned - IFNULL((SELECT SUM(ca.days_used) FROM compoff_availed ca WHERE ca.compoff_id=ce.compoff_id AND ca.status='Approved'),0)) >= ? ORDER BY ce.expiry_date ASC, ce.worked_date ASC LIMIT 1`,
        [emp_id, days_used],
      );
      if (!oldest)
        return res.status(400).json({
          success: false,
          message:
            "No single approved comp-off record with sufficient balance found",
        });
      resolvedCompoffId = oldest.compoff_id;
    }

    const status = compoffInitialStatus(employee.role_id);
    const result = await dbRun(
      `INSERT INTO compoff_availed (emp_id, compoff_id, avail_date, days_used, reason, status, created_at, updated_at) VALUES (?,?,?,?,?,?,NOW(),NOW())`,
      [
        emp_id,
        resolvedCompoffId,
        avail_date,
        days_used,
        reason || null,
        status,
      ],
    );
    res.json({
      success: true,
      avail_id: result.insertId,
      compoff_id: resolvedCompoffId,
      days_used,
      status,
      message:
        status === "Approved"
          ? "Comp-off avail auto-approved"
          : status === "Pending_Manager"
            ? "Comp-off avail request sent to Manager"
            : "Comp-off avail request sent to Team Lead",
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/avail", async (req, res) => {
  const { emp_id, status } = req.query;
  if (!emp_id)
    return res.status(400).json({ success: false, message: "emp_id required" });
  try {
    let sql = `SELECT ca.*, DATE_FORMAT(ca.avail_date,'%Y-%m-%d') AS avail_date, DATE_FORMAT(ce.worked_date,'%Y-%m-%d') AS worked_date, ce.day_type, ce.expiry_date FROM compoff_availed ca JOIN compoff_transactions ce ON ca.compoff_id=ce.compoff_id WHERE ca.emp_id=?`;
    const params = [emp_id];
    if (status) {
      sql += " AND ca.status=?";
      params.push(status);
    }
    sql += " ORDER BY ca.avail_date DESC";
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/compoff/avail/:availId/cancel", async (req, res) => {
  const { emp_id } = req.body;
  if (!emp_id)
    return res.status(400).json({ success: false, message: "emp_id required" });
  try {
    const result = await dbRun(
      `UPDATE compoff_availed SET status='Cancelled', updated_at=NOW() WHERE avail_id=? AND emp_id=? AND status IN ('Pending_TL','Pending_Manager')`,
      [req.params.availId, emp_id],
    );
    if (result.affectedRows === 0)
      return res.status(400).json({
        success: false,
        message: "Request not found or cannot be cancelled",
      });
    res.json({ success: true, message: "Comp-off avail request cancelled" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/compoff/avail/:availId/tl-action", async (req, res) => {
  const { action, remark, login_id } = req.body;
  if (!action || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "action and login_id required" });
  if (!["approve", "reject"].includes(action))
    return res
      .status(400)
      .json({ success: false, message: "action must be approve or reject" });
  if (action === "reject" && !remark?.trim())
    return res
      .status(400)
      .json({ success: false, message: "remark required for rejection" });
  try {
    const record = await dbGet(
      `SELECT * FROM compoff_availed WHERE avail_id=? AND status='Pending_TL'`,
      [req.params.availId],
    );
    if (!record)
      return res.status(404).json({
        success: false,
        message: "Request not found or not in Pending_TL state",
      });
    const newStatus =
      action === "approve" ? "Pending_Manager" : "Rejected_By_TL";
    await dbRun(
      `UPDATE compoff_availed SET status=?, tl_action_by=?, tl_action_at=NOW(), tl_remark=?, updated_at=NOW() WHERE avail_id=?`,
      [newStatus, login_id, remark || null, req.params.availId],
    );
    res.json({ success: true, status: newStatus });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.put("/compoff/avail/:availId/manager-action", async (req, res) => {
  const { action, remark, login_id } = req.body;
  if (!action || !login_id)
    return res
      .status(400)
      .json({ success: false, message: "action and login_id required" });
  if (!["approve", "reject"].includes(action))
    return res
      .status(400)
      .json({ success: false, message: "action must be approve or reject" });
  if (action === "reject" && !remark?.trim())
    return res
      .status(400)
      .json({ success: false, message: "remark required for rejection" });
  try {
    const record = await dbGet(
      `SELECT * FROM compoff_availed WHERE avail_id=? AND status IN ('Pending_Manager','Pending_TL')`,
      [req.params.availId],
    );
    if (!record)
      return res.status(404).json({
        success: false,
        message: "Request not found or already processed",
      });
    if (action === "reject") {
      await dbRun(
        `UPDATE compoff_availed SET status='Rejected_By_Manager', mgr_action_by=?, mgr_action_at=NOW(), mgr_remark=?, updated_at=NOW() WHERE avail_id=?`,
        [login_id, remark, req.params.availId],
      );
      return res.json({ success: true, status: "Rejected_By_Manager" });
    }
    await dbRun(
      `UPDATE compoff_availed SET status='Approved', mgr_action_by=?, mgr_action_at=NOW(), mgr_remark=?, updated_at=NOW() WHERE avail_id=?`,
      [login_id, remark || null, req.params.availId],
    );
    res.json({
      success: true,
      status: "Approved",
      message: "Comp-off avail approved",
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/avail/pending-tl", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id=?`,
      [login_id],
    );
    if (!tlUser)
      return res.status(404).json({ success: false, message: "TL not found" });
    const rows = await dbAll(
      `SELECT ca.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(ca.avail_date,'%Y-%m-%d') AS avail_date, DATE_FORMAT(ce.worked_date,'%Y-%m-%d') AS worked_date, ce.day_type
       FROM compoff_availed ca JOIN compoff_transactions ce ON ca.compoff_id=ce.compoff_id JOIN employee_master e ON ca.emp_id=e.emp_id LEFT JOIN department_master d ON e.department_id=d.department_id
       WHERE ca.status='Pending_TL' AND e.tl_id=? ORDER BY ca.avail_date ASC`,
      [tlUser.emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/avail/pending-manager", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT ca.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(ca.avail_date,'%Y-%m-%d') AS avail_date, DATE_FORMAT(ce.worked_date,'%Y-%m-%d') AS worked_date, ce.day_type
       FROM compoff_availed ca JOIN compoff_transactions ce ON ca.compoff_id=ce.compoff_id JOIN employee_master e ON ca.emp_id=e.emp_id LEFT JOIN department_master d ON e.department_id=d.department_id
       WHERE ca.status='Pending_Manager' ORDER BY ca.created_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/earn/all-history", async (req, res) => {
  const { status, from, to, emp_id } = req.query;
  try {
    let sql = `SELECT c.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(c.worked_date,'%Y-%m-%d') AS worked_date, DATE_FORMAT(c.expiry_date,'%Y-%m-%d') AS expiry_date FROM compoff_transactions c JOIN employee_master e ON c.emp_id=e.emp_id LEFT JOIN department_master d ON e.department_id=d.department_id WHERE 1=1`;
    const params = [];
    if (emp_id) {
      sql += " AND c.emp_id=?";
      params.push(emp_id);
    }
    if (status) {
      sql += " AND c.status=?";
      params.push(status);
    }
    if (from) {
      sql += " AND c.worked_date>=?";
      params.push(from);
    }
    if (to) {
      sql += " AND c.worked_date<=?";
      params.push(to);
    }
    sql += " ORDER BY c.worked_date DESC LIMIT 500";
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/avail/all-history", async (req, res) => {
  const { status, from, to, emp_id } = req.query;
  try {
    let sql = `SELECT ca.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, d.department_name, DATE_FORMAT(ca.avail_date,'%Y-%m-%d') AS avail_date, DATE_FORMAT(ce.worked_date,'%Y-%m-%d') AS worked_date, ce.day_type FROM compoff_availed ca JOIN compoff_transactions ce ON ca.compoff_id=ce.compoff_id JOIN employee_master e ON ca.emp_id=e.emp_id LEFT JOIN department_master d ON e.department_id=d.department_id WHERE 1=1`;
    const params = [];
    if (emp_id) {
      sql += " AND ca.emp_id=?";
      params.push(emp_id);
    }
    if (status) {
      sql += " AND ca.status=?";
      params.push(status);
    }
    if (from) {
      sql += " AND ca.avail_date>=?";
      params.push(from);
    }
    if (to) {
      sql += " AND ca.avail_date<=?";
      params.push(to);
    }
    sql += " ORDER BY ca.avail_date DESC LIMIT 500";
    const rows = await dbAll(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/earn/tl-history", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id=?`,
      [login_id],
    );
    if (!tlUser)
      return res.status(404).json({ success: false, message: "TL not found" });
    const rows = await dbAll(
      `SELECT c.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, DATE_FORMAT(c.worked_date,'%Y-%m-%d') AS worked_date, DATE_FORMAT(c.expiry_date,'%Y-%m-%d') AS expiry_date FROM compoff_transactions c JOIN employee_master e ON c.emp_id=e.emp_id WHERE e.tl_id=? ORDER BY c.worked_date DESC`,
      [tlUser.emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/avail/tl-history", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id)
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id=?`,
      [login_id],
    );
    if (!tlUser)
      return res.status(404).json({ success: false, message: "TL not found" });
    const rows = await dbAll(
      `SELECT ca.*, CONCAT(e.first_name,' ',e.last_name) AS employee_name, DATE_FORMAT(ca.avail_date,'%Y-%m-%d') AS avail_date, DATE_FORMAT(ce.worked_date,'%Y-%m-%d') AS worked_date, ce.day_type FROM compoff_availed ca JOIN compoff_transactions ce ON ca.compoff_id=ce.compoff_id JOIN employee_master e ON ca.emp_id=e.emp_id WHERE e.tl_id=? ORDER BY ca.avail_date DESC`,
      [tlUser.emp_id],
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/compoff/expire", async (req, res) => {
  try {
    const result = await dbRun(
      `UPDATE compoff_transactions SET status='Expired', updated_at=NOW() WHERE status='Approved' AND expiry_date IS NOT NULL AND expiry_date < CURDATE()`,
    );
    const cancelledAvails = await dbRun(
      `UPDATE compoff_availed ca JOIN compoff_transactions ce ON ca.compoff_id=ce.compoff_id SET ca.status='Cancelled', ca.updated_at=NOW() WHERE ce.status='Expired' AND ca.status IN ('Pending_TL','Pending_Manager')`,
    );
    res.json({
      success: true,
      expired_earn_records: result.affectedRows,
      cancelled_avail_requests: cancelledAvails.affectedRows,
      run_at: new Date().toISOString(),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/compoff/pending-count", async (req, res) => {
  try {
    const earnRow = await dbGet(
      `SELECT COUNT(*) AS count FROM compoff_transactions WHERE status IN ('Pending_TL','Pending_Manager')`,
    );
    const availRow = await dbGet(
      `SELECT COUNT(*) AS count FROM compoff_availed WHERE status IN ('Pending_TL','Pending_Manager')`,
    );
    res.json({
      success: true,
      pending_earn: earnRow?.count || 0,
      pending_avail: availRow?.count || 0,
      total: (earnRow?.count || 0) + (availRow?.count || 0),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/employee-location/:empId", async (req, res) => {
  try {
    res.json({ success: true, lat: 13.0827, lng: 80.2707 });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Add this to your cron jobs or run daily
async function autoCreateCompOffsDaily() {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const dateStr = yesterday.toISOString().slice(0, 10);

  // Find all employees who worked yesterday
  const workers = await dbAll(
    `SELECT DISTINCT employee_id, work_date 
     FROM tracking_sessions 
     WHERE work_date = ?`,
    [dateStr],
  );

  for (const worker of workers) {
    await _autoCreateCompoff(worker.employee_id, worker.work_date);
  }
}

// Schedule to run daily at 1 AM IST
cron.schedule("30 19 * * *", autoCreateCompOffsDaily, {
  timezone: "Asia/Kolkata",
});

// ─── DEBUG (remove in production) ────────────────────────────────────────────
app.get("/debug/tl-leaves", async (req, res) => {
  const { login_id } = req.query;
  try {
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id = ?`,
      [login_id],
    );
    if (!tlUser) return res.json({ step: "login_master", data: null });
    const tlEmpId = tlUser.emp_id;
    const employees = await dbAll(
      `SELECT emp_id, first_name FROM employee_master WHERE tl_id = ?`,
      [tlEmpId],
    );
    const leaves = await dbAll(
      `SELECT * FROM leave_master WHERE emp_id IN (SELECT emp_id FROM employee_master WHERE tl_id = ?)`,
      [tlEmpId],
    );
    const pendingTL = await dbAll(
      `SELECT * FROM leave_master WHERE status = 'Pending_TL' AND emp_id IN (SELECT emp_id FROM employee_master WHERE tl_id = ?)`,
      [tlEmpId],
    );
    res.json({
      login_id,
      tlEmpId,
      employees_count: employees.length,
      employees,
      total_leaves: leaves.length,
      pending_tl_count: pendingTL.length,
      pendingTL,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── CHECK COMP-OFF ELIGIBILITY FOR LEAVE APPLY ───────────────────────────
app.get("/employees/:empId/compoff-eligible", async (req, res) => {
  const { empId } = req.params;
  try {
    const earnedRow = await dbGet(
      `SELECT IFNULL(SUM(days), 0) AS total
       FROM compoff_transactions
       WHERE emp_id = ?
         AND type = 'EARNED'
         AND status = 'Approved'
         AND (expiry_date IS NULL OR expiry_date >= CURDATE())`,
      [empId],
    );

    const usedRow = await dbGet(
      `SELECT IFNULL(SUM(days), 0) AS total
       FROM compoff_transactions
       WHERE emp_id = ?
         AND type = 'USED'
         AND status = 'Approved'`,
      [empId],
    );

    // ✅ Also subtract Comp-Off days used via leave_master
    const leaveUsedRow = await dbGet(
      `SELECT IFNULL(SUM(number_of_days), 0) AS total
       FROM leave_master
       WHERE emp_id = ?
         AND leave_type = 'Comp-Off'
         AND status = 'Approved'`,
      [empId],
    );

    const earned = parseFloat(earnedRow?.total ?? 0);
    const used = parseFloat(usedRow?.total ?? 0);
    const leaveUsed = parseFloat(leaveUsedRow?.total ?? 0);
    const available = Math.max(
      parseFloat((earned - used - leaveUsed).toFixed(1)),
      0,
    );

    return res.json({
      success: true,
      eligible: available > 0,
      available: available,
      earned,
      used: used + leaveUsed,
    });
  } catch (err) {
    console.error("[compoff-eligible]", err.message);
    return res.json({ success: true, eligible: false, available: 0 });
  }
});

// ─── MONTH SUMMARY (holidays + leaves + compoff) ──────────────────────────
app.get("/attendance/month-summary/:empId", async (req, res) => {
  const { empId } = req.params;
  const { year, month } = req.query;

  if (!year || !month) {
    return res.status(400).json({ message: "year and month required" });
  }

  try {
    // ── Holidays ─────────────────────────────────────────────
    const holidays = await dbAll(
      `SELECT DATE_FORMAT(holiday_date, '%Y-%m-%d') AS date,
              holiday_name,
              holiday_type
       FROM holiday_master
       WHERE YEAR(holiday_date) = ?
         AND MONTH(holiday_date) = ?
         AND holiday_type IN ('National', 'Public')
       ORDER BY holiday_date ASC`,
      [year, month],
    );

    // ── Leaves (FIXED OVERLAP LOGIC) ─────────────────────────
    const leaves = await dbAll(
      `SELECT DATE_FORMAT(leave_start_date, '%Y-%m-%d') AS from_date,
              DATE_FORMAT(leave_end_date, '%Y-%m-%d') AS to_date,
              leave_type,
              number_of_days,
              status
       FROM leave_master
       WHERE emp_id = ?
         AND status IN ('Approved', 'Pending_TL', 'Pending_Manager')
         AND leave_start_date <= LAST_DAY(CONCAT(?, '-', ?, '-01'))
         AND leave_end_date >= CONCAT(?, '-', ?, '-01')
       ORDER BY leave_start_date ASC`,
      [empId, year, month, year, month],
    );

    // ── Comp-offs ───────────────────────────────────────────
    const compoffs = await dbAll(
      `SELECT DATE_FORMAT(work_date, '%Y-%m-%d') AS date,
          reason,
          status,
          days AS days_earned   -- ✅ mapped correctly
   FROM compoff_transactions
   WHERE emp_id = ?
     AND type = 'EARNED'       -- ✅ IMPORTANT
     AND YEAR(work_date) = ?
     AND MONTH(work_date) = ?
     AND status = 'Approved'
   ORDER BY work_date ASC`,
      [empId, year, month],
    );

    res.json({
      success: true,
      holidays,
      leaves,
      compoffs,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
});
// Runs at 00:01 IST on Jan 1 every year (IST = UTC+5:30, so 18:31 UTC Dec 31)
cron.schedule(
  "31 18 31 12 *",
  async () => {
    const year = new Date().getFullYear();
    console.log(`[cron] Running year-end carry-forward for ${year}`);
    try {
      const toYear = year + 1;
      const policies = await dbAll(
        `SELECT leave_type, total_days, carry_forward, max_carry_days FROM leave_policy WHERE is_active=1`,
      );
      const employees = await dbAll(
        `SELECT emp_id FROM employee_master WHERE status='Active'`,
      );

      for (const emp of employees) {
        for (const policy of policies) {
          await syncLeaveBalance(emp.emp_id, policy.leave_type, year);

          const bal = await dbGet(
            `SELECT allocated_days, carry_forward AS cf, used_days, pending_days
           FROM leave_balance WHERE emp_id=? AND leave_type=? AND year=?`,
            [emp.emp_id, policy.leave_type, year],
          );

          const balanceBefore = bal
            ? bal.allocated_days + bal.cf - bal.used_days - bal.pending_days
            : 0;

          let carriedDays = 0,
            lapsedDays = 0;
          if (policy.carry_forward && balanceBefore > 0) {
            carriedDays = policy.max_carry_days
              ? Math.min(balanceBefore, policy.max_carry_days)
              : balanceBefore;
            lapsedDays = balanceBefore - carriedDays;
          } else {
            lapsedDays = Math.max(balanceBefore, 0);
          }

          await dbRun(
            `INSERT INTO leave_balance (emp_id, leave_type, year, allocated_days, carry_forward)
           VALUES (?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE carry_forward=VALUES(carry_forward), updated_at=NOW()`,
            [
              emp.emp_id,
              policy.leave_type,
              toYear,
              policy.total_days,
              carriedDays,
            ],
          );

          await dbRun(
            `INSERT INTO leave_carry_forward_log
           (emp_id, leave_type, from_year, to_year, balance_before, carried_days, lapsed_days)
           VALUES (?,?,?,?,?,?,?)`,
            [
              emp.emp_id,
              policy.leave_type,
              year,
              toYear,
              balanceBefore,
              carriedDays,
              lapsedDays,
            ],
          );
        }
      }
      console.log(`[cron] Year-end process complete for ${year} → ${toYear}`);
    } catch (err) {
      console.error("[cron] Year-end process failed:", err);
    }
  },
  { timezone: "Asia/Kolkata" },
);
// ─── START SERVER ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(`Server running on http://0.0.0.0:${PORT}`),
);
