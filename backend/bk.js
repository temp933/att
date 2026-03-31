const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const bcrypt = require("bcryptjs");
// const crypto = require("crypto");

const app = express();
app.use(express.json());
app.use(cors());

// ─── DATABASE ────────────────────────────────────────────────────────────────
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

    // ── Unknown user ──────────────────────────────────────────────────────────
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

    // ── Inactive account ──────────────────────────────────────────────────────
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

    // ── Account locked ────────────────────────────────────────────────────────
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

    // ── Password check (supports both bcrypt and legacy plain-text) ───────────
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

    // ── Single-session check ──────────────────────────────────────────────────
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
      // Allow re-login if existing session is older than 8 hours
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

    // ── Migrate plain-text password to bcrypt silently ────────────────────────
    let finalHash = user.password;
    if (!user.password.startsWith("$2")) {
      finalHash = await bcrypt.hash(password, 10);
    }

    // ── Create session ────────────────────────────────────────────────────────
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

    // ── First login → force password change ───────────────────────────────────
    if (user.is_first_login) {
      return res.json({
        success: true,
        firstLogin: true,
        message: "Please change your password before continuing.",
        loginId: user.login_id,
        empId: user.emp_id,
        roleId: user.role_id,
        username: user.username.trim(),
        // No sessionToken until password is changed
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
  const { login_id, session_token, device_id } = req.body;
  if (!login_id || !session_token)
    return res.json({ valid: false, expired: true });

  try {
    const user = await dbGet(
      `SELECT session_token, session_device, device_logged_in, 
              locked_until, status
       FROM login_master WHERE login_id = ?`,
      [login_id],
    );

    if (!user || user.status !== "Active")
      return res.json({ valid: false, expired: true });

    // ← Key change: null token means admin force-logged them out
    if (!user.session_token || user.device_logged_in === 0) {
      return res.json({ valid: false, force_logout: true });
    }

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

// ─── APPLY LEAVE ─────────────────────────────────────────────────────────────
app.post("/employees/:empId/apply-leave", async (req, res) => {
  const { leave_type, leave_start_date, leave_end_date, reason } = req.body;

  if (!leave_type || !leave_start_date || !leave_end_date) {
    return res.status(400).json({
      success: false,
      message: "Leave type and dates are required",
    });
  }

  try {
    const employee = await dbGet(
      `SELECT role_id FROM employee_master WHERE emp_id = ?`,
      [req.params.empId],
    );

    if (!employee) {
      return res
        .status(404)
        .json({ success: false, message: "Employee not found" });
    }

    // FIX: role_id → initial leave status mapping
    // 1 = Employee   → Pending_TL
    // 2 = Team Lead  → Pending_Manager  (skips TL review, goes direct to Manager)
    // 3 = HR         → Pending_Manager  (skips TL review, goes direct to Manager)
    // 8 = Manager    → Approved         (self-approved instantly)
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

    await dbRun(
      `INSERT INTO leave_master
        (emp_id, leave_type, leave_start_date, leave_end_date, reason, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        req.params.empId,
        leave_type,
        leave_start_date,
        leave_end_date,
        reason || "",
        status,
      ],
    );

    res.json({
      success: true,
      message:
        status === "Approved"
          ? "Leave approved (self-approved)"
          : status === "Pending_Manager"
            ? "Leave applied and sent directly to Manager"
            : "Leave applied successfully",
    });
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

// ─── LEAVE PENDING TL ─────────────────────────────────────────────────────────
app.get("/leaves/pending-tl", async (req, res) => {
  const { login_id } = req.query;
  if (!login_id) {
    return res
      .status(400)
      .json({ success: false, message: "login_id required" });
  }

  try {
    // Step 1: resolve login_id → emp_id
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id = ?`,
      // REMOVED: AND status = 'Active'  ← this might be causing null if status col differs
      [login_id],
    );

    console.log("[pending-tl] login_id:", login_id, "→ tlUser:", tlUser); // ADD THIS LOG

    if (!tlUser || !tlUser.emp_id) {
      return res
        .status(404)
        .json({ success: false, message: "TL user not found" });
    }

    const tlEmpId = tlUser.emp_id;

    // Step 2: fetch only leaves where employee's tl_id = this TL's emp_id
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

    console.log("[pending-tl] tlEmpId:", tlEmpId, "→ rows found:", rows.length); // ADD THIS LOG

    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get("/debug/tl-leaves", async (req, res) => {
  const { login_id } = req.query;

  try {
    // 1. login_id → emp_id
    const tlUser = await dbGet(
      `SELECT emp_id FROM login_master WHERE login_id = ?`,
      [login_id],
    );

    if (!tlUser) {
      return res.json({ step: "login_master", data: null });
    }

    const tlEmpId = tlUser.emp_id;

    // 2. employees under this TL
    const employees = await dbAll(
      `SELECT emp_id, first_name FROM employee_master WHERE tl_id = ?`,
      [tlEmpId],
    );

    // 3. leaves for those employees
    const leaves = await dbAll(
      `SELECT * FROM leave_master 
       WHERE emp_id IN (
         SELECT emp_id FROM employee_master WHERE tl_id = ?
       )`,
      [tlEmpId],
    );

    // 4. pending TL leaves only
    const pendingTL = await dbAll(
      `SELECT * FROM leave_master 
       WHERE status = 'Pending_TL'
       AND emp_id IN (
         SELECT emp_id FROM employee_master WHERE tl_id = ?
       )`,
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

    // FIX: recommend → Pending_Manager (was Pending_HR — manager is now final approver)
    const newStatus =
      action === "recommend" ? "Pending_Manager" : "Not_Recommended_By_TL";

    await dbRun(
      `UPDATE leave_master
       SET status=?,
           rejection_reason=?,
           recommended_by=?,
           recommended_at=?,
           approved_by=?,
           updated_at=NOW()
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
    // FIX: accept both Pending_Manager and Pending_HR so legacy records work
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

// ─── HR ACTION (kept for any direct HR-role screens) ─────────────────────────
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

    // FIX: check for manager or admin role (was checking %hr% which is wrong)
    const hrRoles = await dbAll(
      `SELECT role_id FROM role_master WHERE LOWER(role_name) LIKE '%manager%' OR LOWER(role_name) LIKE '%admin%'`,
    );
    if (!hrRoles.some((r) => r.role_id === user.role_id))
      return res
        .status(403)
        .json({ success: false, message: "Only Manager/Admin can action" });

    // FIX: accept Pending_HR and Pending_Manager
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

// ─── ALL PENDING LEAVES (TL + Manager combined) ───────────────────────────────
app.get("/leaves/all-pending", async (req, res) => {
  try {
    const rows = await dbAll(
      // FIX: added 'Pending_Manager' to WHERE so manager-queue items appear here too
      `SELECT
          l.leave_id, l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          d.department_name, r.role_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS leave_start_date,
          DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS leave_end_date,
          l.number_of_days, l.reason, l.status,
          l.recommended_by, l.recommended_at,
          IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0) AS taken_days,
          CASE l.leave_type
            WHEN 'Sick'      THEN 12
            WHEN 'Casual'    THEN 12
            WHEN 'Paid'      THEN 15
            WHEN 'Maternity' THEN 90
            WHEN 'Paternity' THEN 15
            ELSE 12
          END AS total_allowed,
          (CASE l.leave_type
            WHEN 'Sick'      THEN 12
            WHEN 'Casual'    THEN 12
            WHEN 'Paid'      THEN 15
            WHEN 'Maternity' THEN 90
            WHEN 'Paternity' THEN 15
            ELSE 12
          END
          - IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0)
          ) AS remaining_days
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       LEFT JOIN department_master d  ON e.department_id = d.department_id
       LEFT JOIN role_master r        ON e.role_id       = r.role_id
       LEFT JOIN leave_master lm2
         ON lm2.emp_id = l.emp_id
        AND lm2.leave_type = l.leave_type
        AND lm2.status = 'Approved'
       WHERE l.status IN ('Pending_TL', 'Pending_HR', 'Pending_Manager')
       GROUP BY l.leave_id
       ORDER BY l.created_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─── ALL LEAVE HISTORY ────────────────────────────────────────────────────────
app.get("/leaves/all-history", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          l.leave_id,
          l.emp_id,
          CONCAT(e.first_name,' ',e.last_name) AS employee_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date,'%Y-%m-%d') AS from_date,
          DATE_FORMAT(l.leave_end_date,'%Y-%m-%d') AS to_date,
          l.number_of_days AS total_days,
          l.status,
          l.reason,
          l.rejection_reason,
          l.cancel_reason,
          CASE
            WHEN l.recommended_by IS NOT NULL
            THEN CONCAT(tl_emp.first_name,' ',tl_emp.last_name)
            ELSE NULL
          END AS recommended_by_name,
          CASE
            WHEN l.approved_by IS NOT NULL
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

// ─── ATTENDANCE ───────────────────────────────────────────────────────────────
app.get("/attendance/status/:empId", async (req, res) => {
  try {
    const row = await dbGet(
      `SELECT status FROM employee_site_attendance
       WHERE employee_id = ? AND work_date = CURDATE()
       ORDER BY id DESC LIMIT 1`,
      [req.params.empId],
    );
    if (!row) return res.json({ status: "not_started" });
    if (row.status === "ended_manually")
      return res.json({ status: "completed" });
    return res.json({ status: "in_progress" });
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.get("/attendance/today/:empId", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT a.id, a.site_id, s.site_name,
          DATE_FORMAT(a.in_time,  '%H:%i:%s') AS in_time,
          DATE_FORMAT(a.out_time, '%H:%i:%s') AS out_time,
          a.work_date, a.status,
          TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS duration_minutes
       FROM employee_site_attendance a
       JOIN sites s ON a.site_id = s.id
       WHERE a.employee_id = ? AND a.work_date = CURDATE()
       ORDER BY a.in_time ASC`,
      [req.params.empId],
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/in", async (req, res) => {
  const { employee_id, site_id } = req.body;
  if (!employee_id || !site_id)
    return res
      .status(400)
      .json({ message: "employee_id and site_id required" });

  try {
    const dayEnded = await dbGet(
      `SELECT id FROM employee_site_attendance
       WHERE employee_id=? AND work_date=CURDATE() AND status='ended_manually' LIMIT 1`,
      [employee_id],
    );
    if (dayEnded)
      return res.status(409).json({ message: "Day already ended for today" });

    const site = await dbGet(
      `SELECT id FROM sites WHERE id=? AND CURDATE() BETWEEN start_date AND end_date`,
      [site_id],
    );
    if (!site)
      return res.status(400).json({ message: "Site not active today" });

    await dbRun(
      `UPDATE employee_site_attendance
       SET out_time=NOW(), updated_at=NOW(), status='completed'
       WHERE employee_id=? AND site_id!=? AND work_date=CURDATE() AND out_time IS NULL`,
      [employee_id, site_id],
    );

    const existing = await dbGet(
      `SELECT id, out_time,
          TIMESTAMPDIFF(MINUTE, out_time, NOW()) AS minutes_since_out
       FROM employee_site_attendance
       WHERE employee_id=? AND site_id=? AND work_date=CURDATE()
       ORDER BY id DESC LIMIT 1`,
      [employee_id, site_id],
    );

    if (!existing) {
      const r = await dbRun(
        `INSERT INTO employee_site_attendance
           (employee_id, site_id, in_time, work_date, status, updated_at)
         VALUES (?, ?, NOW(), CURDATE(), 'active', NOW())`,
        [employee_id, site_id],
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
        `UPDATE employee_site_attendance
         SET out_time=NULL, updated_at=NOW(), status='active' WHERE id=?`,
        [existing.id],
      );
      return res.json({
        message: "IN marked (returned <15m)",
        id: existing.id,
      });
    }

    const r = await dbRun(
      `INSERT INTO employee_site_attendance
         (employee_id, site_id, in_time, work_date, status, updated_at)
       VALUES (?, ?, NOW(), CURDATE(), 'active', NOW())`,
      [employee_id, site_id],
    );
    res.json({ message: "IN marked (new row)", id: r.insertId });
  } catch (err) {
    console.error("[mark_in]", err);
    res.status(500).json({ message: "Database error" });
  }
});

app.post("/attendance/out", async (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id required" });
  try {
    await dbRun(
      `UPDATE employee_site_attendance
       SET out_time=NOW(), updated_at=NOW(), status='completed'
       WHERE employee_id=? AND work_date=CURDATE() AND out_time IS NULL`,
      [employee_id],
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
    const alreadyEnded = await dbGet(
      `SELECT id FROM employee_site_attendance
       WHERE employee_id=? AND work_date=CURDATE() AND status='ended_manually' LIMIT 1`,
      [employee_id],
    );
    if (alreadyEnded) return res.json({ message: "Day already ended" });

    await dbRun(
      `UPDATE employee_site_attendance
       SET out_time=NOW(), updated_at=NOW(), status='ended_manually'
       WHERE employee_id=? AND work_date=CURDATE() AND out_time IS NULL`,
      [employee_id],
    );
    res.json({ message: "Day ended" });
  } catch (err) {
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
       SET out_time=NOW(), updated_at=NOW()
       WHERE employee_id=? AND work_date=CURDATE() AND status='active'
       ORDER BY id DESC LIMIT 1`,
      [employee_id],
    );
    res.json({ message: "ok", updated: result.affectedRows });
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
    const { type, employee_id, site_id, timestamp } = e;
    const ts = timestamp || new Date().toISOString();
    const workDate = ts.slice(0, 10);

    try {
      switch (type) {
        case "mark_in": {
          if (!employee_id || !site_id)
            throw new Error("mark_in requires employee_id and site_id");

          const dayEnded = await dbGet(
            `SELECT id FROM employee_site_attendance
             WHERE employee_id=? AND work_date=? AND status='ended_manually' LIMIT 1`,
            [employee_id, workDate],
          );
          if (dayEnded) {
            results.push({ index: i, type, status: "skipped_day_ended" });
            break;
          }

          await dbRun(
            `UPDATE employee_site_attendance
             SET out_time=?, updated_at=NOW(), status='completed'
             WHERE employee_id=? AND site_id!=? AND work_date=? AND out_time IS NULL`,
            [ts, employee_id, site_id, workDate],
          );

          const existing = await dbGet(
            `SELECT id, out_time,
                TIMESTAMPDIFF(MINUTE, out_time, ?) AS mins_since_out
             FROM employee_site_attendance
             WHERE employee_id=? AND site_id=? AND work_date=?
             ORDER BY id DESC LIMIT 1`,
            [ts, employee_id, site_id, workDate],
          );

          if (!existing) {
            await dbRun(
              `INSERT INTO employee_site_attendance
                 (employee_id, site_id, in_time, work_date, status, updated_at)
               VALUES (?, ?, ?, ?, 'active', NOW())`,
              [employee_id, site_id, ts, workDate],
            );
          } else if (existing.out_time !== null) {
            if (
              existing.mins_since_out !== null &&
              existing.mins_since_out < 15
            ) {
              await dbRun(
                `UPDATE employee_site_attendance
                 SET out_time=NULL, updated_at=NOW(), status='active' WHERE id=?`,
                [existing.id],
              );
            } else {
              await dbRun(
                `INSERT INTO employee_site_attendance
                   (employee_id, site_id, in_time, work_date, status, updated_at)
                 VALUES (?, ?, ?, ?, 'active', NOW())`,
                [employee_id, site_id, ts, workDate],
              );
            }
          }
          results.push({ index: i, type, status: "ok" });
          break;
        }
        case "mark_out": {
          if (!employee_id) throw new Error("mark_out requires employee_id");
          await dbRun(
            `UPDATE employee_site_attendance
             SET out_time=?, updated_at=NOW(), status='completed'
             WHERE employee_id=? AND work_date=? AND out_time IS NULL`,
            [ts, employee_id, workDate],
          );
          results.push({ index: i, type, status: "ok" });
          break;
        }
        case "end_day": {
          if (!employee_id) throw new Error("end_day requires employee_id");
          await dbRun(
            `UPDATE employee_site_attendance
             SET out_time=?, updated_at=NOW(), status='ended_manually'
             WHERE employee_id=? AND work_date=? AND out_time IS NULL`,
            [ts, employee_id, workDate],
          );
          results.push({ index: i, type, status: "ok" });
          break;
        }
        default:
          results.push({ index: i, type, status: "unknown_type" });
      }
    } catch (err) {
      console.error(`[batch-sync] event ${i} (${type}):`, err.message);
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
  try {
    const rows = await dbAll(
      `SELECT
          e.emp_id,
          TRIM(CONCAT(e.first_name, ' ', IFNULL(e.mid_name, ''), ' ', e.last_name)) AS name,
          s.site_name AS location_name,
          a.id AS visit_id,
          a.in_time, a.out_time, a.work_date, a.status,
          TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS worked_minutes
       FROM employee_master e
       LEFT JOIN employee_site_attendance a ON e.emp_id = a.employee_id AND a.work_date = ?
       LEFT JOIN sites s ON a.site_id = s.id
       WHERE e.status = 'Active'
       ORDER BY e.emp_id ASC, a.in_time ASC`,
      [req.query.date],
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
    ] = await Promise.all([
      dbAll(`SELECT COUNT(*) AS v FROM employee_master WHERE status='Active'`),
      dbAll(
        `SELECT COUNT(DISTINCT employee_id) AS v FROM employee_site_attendance WHERE work_date=?`,
        [today],
      ),
      dbAll(
        `SELECT COUNT(DISTINCT emp_id) AS v FROM employee_location_assignment
         WHERE start_date<=? AND end_date>=? AND status IN ('Active','Extended')`,
        [today, today],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM employee_pending_request WHERE admin_approve='PENDING'`,
      ),
      // FIX: count all pending leave statuses including Pending_Manager
      dbAll(
        `SELECT COUNT(*) AS v FROM leave_master
         WHERE status IN ('Pending_TL','Pending_HR','Pending_Manager')
           AND leave_start_date >= ?`,
        [today],
      ),
      dbAll(
        `SELECT COUNT(*) AS v FROM employee_master e
         LEFT JOIN employee_site_attendance a
           ON e.emp_id=a.employee_id AND a.work_date=?
         WHERE e.status='Active' AND a.id IS NULL`,
        [today],
      ),
    ]);

    res.json({
      totalEmployees,
      present,
      absent,
      onSiteToday,
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
      `SELECT department_id AS id, department_name AS name
       FROM department_master WHERE status='Active'`,
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
         (location_nick_name, latitude, longitude, start_date, end_date,
          contact_person_name, contact_person_number)
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
            WHEN ela.status='Active' AND DATE(CONVERT_TZ(ela.end_date,'+00:00','+05:30')) < CURDATE()
              THEN 'Not Completed'
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
      `INSERT INTO employee_location_assignment
         (emp_id, location_id, about_work, start_date, end_date, status, done_by)
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

  let sql = `UPDATE employee_location_assignment
             SET status=?, reason=?, done_by=?, updated_at=NOW()`;
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
          p.admin_approve, p.username, p.request_type,
          p.edit_reason, p.reject_reason,
          p.created_at, p.updated_at,
          d.department_name, r.role_name,
          (
            SELECT JSON_ARRAYAGG(
              JSON_OBJECT(
                'education_level', x.education_level,
                'stream',          x.stream,
                'score',           x.score,
                'year_of_passout', x.year_of_passout,
                'university',      x.university,
                'college_name',    x.college_name
              )
            )
            FROM (
              SELECT ep.education_level, ep.stream, ep.score,
                     ep.year_of_passout, ep.university, ep.college_name
              FROM education_pending_request ep WHERE ep.request_id = p.request_id
              UNION ALL
              SELECT ed.education_level, ed.stream, ed.score,
                     ed.year_of_passout, ed.university, ed.college_name
              FROM education_details ed
              WHERE ed.emp_id = p.emp_id
                AND NOT EXISTS (
                  SELECT 1 FROM education_pending_request ep2
                  WHERE ep2.request_id = p.request_id
                    AND ep2.education_level = ed.education_level
                )
            ) x
          ) AS education_list
       FROM employee_pending_request p
       LEFT JOIN employee_master   e ON p.emp_id        = e.emp_id
       LEFT JOIN department_master d ON COALESCE(p.department_id, e.department_id) = d.department_id
       LEFT JOIN role_master       r ON COALESCE(p.role_id,       e.role_id)       = r.role_id
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
      `UPDATE employee_pending_request
       SET admin_approve='REJECTED', reject_reason=? WHERE request_id=?`,
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
      COALESCE(p.role_id,       e.role_id)       AS role_id_resolved,
      d.department_name, r.role_name,
      TRIM(CONCAT(tl.first_name, ' ', IFNULL(tl.mid_name, ''), ' ', tl.last_name)) AS tl_name
   FROM employee_pending_request p
   LEFT JOIN employee_master   e  ON p.emp_id                          = e.emp_id
   LEFT JOIN department_master d  ON COALESCE(p.department_id, e.department_id) = d.department_id
   LEFT JOIN role_master       r  ON COALESCE(p.role_id, e.role_id)   = r.role_id
   LEFT JOIN employee_master   tl ON COALESCE(p.tl_id, e.tl_id)      = tl.emp_id
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
           NULL AS admin_approve, NULL AS request_id, 'MASTER' AS source,
           e.created_at, e.updated_at
         FROM employee_master e
         LEFT JOIN department_master d ON e.department_id=d.department_id
         LEFT JOIN role_master r       ON e.role_id=r.role_id
         UNION ALL
         SELECT p.emp_id, p.first_name, p.mid_name, p.last_name,
           p.email_id AS email, p.phone_number AS phone, p.date_of_birth, p.gender,
           p.department_id, d2.department_name, p.role_id, r2.role_name,
           p.date_of_joining, p.employment_type, p.work_type,
           NULL AS emp_status, p.admin_approve, p.request_id, 'PENDING' AS source,
           p.created_at, p.updated_at
         FROM employee_pending_request p
         LEFT JOIN department_master d2 ON p.department_id=d2.department_id
         LEFT JOIN role_master r2       ON p.role_id=r2.role_id
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

// ─── EMPLOYEE USER (by loginId) ───────────────────────────────────────────────
app.get("/employee-user/:loginId", async (req, res) => {
  try {
    const u = await dbGet(
      `SELECT lm.login_id, lm.emp_id, lm.username, r.role_name,
          CONCAT(e.first_name,
            CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != ''
              THEN CONCAT(' ', e.mid_name) ELSE '' END,
            ' ', e.last_name) AS full_name
       FROM login_master lm
       LEFT JOIN employee_master e ON lm.emp_id  = e.emp_id
       LEFT JOIN role_master     r ON lm.role_id = r.role_id
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
)
VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'PENDING',?,?,'NEW',NOW(),NOW())`,
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
        `INSERT INTO education_pending_request
           (request_id, education_level, stream, score, year_of_passout, university, college_name)
         VALUES ?`,
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

// ─── APPROVE REQUEST ─────────────────────────────────────────────────────────
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
        `SELECT * FROM employee_pending_request
         WHERE request_id = ? AND admin_approve = 'PENDING'`,
        [request_id],
      );
      if (!request) {
        await run("ROLLBACK");
        conn.release();
        return res
          .status(404)
          .json({ error: "Request not found or already processed." });
      }

      const excludeId =
        request.request_type === "UPDATE" ? (request.emp_id ?? 0) : 0;
      const dupChecks = [
        {
          field: "email_id",
          value: request.email_id,
          label: "Email already exists",
        },
        {
          field: "phone_number",
          value: request.phone_number,
          label: "Phone number already exists",
        },
        {
          field: "aadhar_number",
          value: request.aadhar_number,
          label: "Aadhar number already exists",
        },
        {
          field: "pan_number",
          value: request.pan_number,
          label: "PAN number already exists",
        },
      ];

      for (const check of dupChecks) {
        if (!check.value || check.value.toString().trim() === "") continue;
        const dup = await get(
          `SELECT emp_id FROM employee_master WHERE ${check.field} = ? AND emp_id != ?`,
          [check.value, excludeId],
        );
        if (dup) {
          await run(
            `UPDATE employee_pending_request SET admin_approve='REJECTED', reject_reason=? WHERE request_id=?`,
            [check.label, request_id],
          );
          await run("COMMIT");
          conn.release();
          return res.status(409).json({ error: check.label });
        }
      }

      const n = (v) => (v != null && v.toString().trim() !== "" ? v : null);
      const toInt = (v) => (v != null && v !== "" ? parseInt(v, 10) : null);

      if (request.request_type === "NEW") {
        const empResult = await run(
          `INSERT INTO employee_master (
              first_name, mid_name, last_name, email_id, phone_number,
              date_of_birth, gender, father_name, emergency_contact_relation, emergency_contact,
              department_id, role_id,tl_id, date_of_joining, date_of_relieving,
              employment_type, work_type, permanent_address, communication_address,
              aadhar_number, pan_number, passport_number, pf_number, esic_number,
              years_experience, status
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
            request.tl_id,
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
        await run(
          `INSERT INTO education_details
             (emp_id, education_level, stream, score, year_of_passout, university, college_name)
           SELECT ?, education_level, stream, score, year_of_passout, university, college_name
           FROM education_pending_request WHERE request_id = ?`,
          [empId, request_id],
        );
        await run(
          `INSERT INTO login_master (emp_id, username, password, role_id, status)
           VALUES (?, ?, ?, ?, 'Active')`,
          [empId, request.username, request.password, request.role_id],
        );
        await run(
          `UPDATE employee_pending_request SET admin_approve='APPROVED', emp_id=? WHERE request_id=?`,
          [empId, request_id],
        );
        await run(`DELETE FROM education_pending_request WHERE request_id=?`, [
          request_id,
        ]);
        await run("COMMIT");
        conn.release();
        return res.json({
          success: true,
          message: "New employee approved successfully!",
          emp_id: empId,
        });
      }

      if (request.request_type === "UPDATE") {
        if (!request.emp_id) {
          await run("ROLLBACK");
          conn.release();
          return res
            .status(400)
            .json({ error: "emp_id missing on UPDATE request." });
        }

        const dorValue =
          request.status === "Relieved" ? n(request.date_of_relieving) : null;

        const updateResult = await run(
          `UPDATE employee_master SET
              first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?,
              date_of_birth=?, gender=?, father_name=?,
              emergency_contact_relation=?, emergency_contact=?,
              department_id=?, role_id=?,tl_id=?, date_of_joining=?, date_of_relieving=?,
              employment_type=?, work_type=?, permanent_address=?, communication_address=?,
              aadhar_number=?, pan_number=?, passport_number=?,
              pf_number=?, esic_number=?, years_experience=?, status=?
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
            request.tl_id,
            request.date_of_joining,
            dorValue,
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
            request.emp_id,
          ],
        );

        if (updateResult.affectedRows === 0) {
          await run("ROLLBACK");
          conn.release();
          return res.status(404).json({ error: "Employee not found." });
        }

        await run(
          `UPDATE login_master SET role_id=?, status=? WHERE emp_id=?`,
          [request.role_id, request.status || "Active", request.emp_id],
        );
        await run(`DELETE FROM education_details WHERE emp_id=?`, [
          request.emp_id,
        ]);
        await run(
          `INSERT INTO education_details
             (emp_id, education_level, stream, score, year_of_passout, university, college_name)
           SELECT ?, education_level, stream, score, year_of_passout, university, college_name
           FROM education_pending_request WHERE request_id=?`,
          [request.emp_id, request_id],
        );
        await run(
          `UPDATE employee_pending_request SET admin_approve='APPROVED' WHERE request_id=?`,
          [request_id],
        );
        await run(`DELETE FROM education_pending_request WHERE request_id=?`, [
          request_id,
        ]);
        await run("COMMIT");
        conn.release();
        return res.json({
          success: true,
          message: "Employee update approved successfully!",
        });
      }

      await run("ROLLBACK");
      conn.release();
      return res
        .status(400)
        .json({ error: "Unknown request_type: " + request.request_type });
    } catch (err) {
      try {
        conn.query("ROLLBACK", () => {});
      } catch (_) {}
      conn.release();
      console.error("[approve-request]", err);
      return res.status(500).json({ error: err.message });
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

  if (
    status === "Relieved" &&
    (!date_of_relieving || date_of_relieving.toString().trim() === "")
  )
    return res.status(400).json({
      success: false,
      message: "Date of Relieving is required when status is Relieved",
    });

  const dorValue =
    status === "Relieved" ? emptyToNull(date_of_relieving) : null;
  const safeInt = (v) => (v != null && v !== "" ? parseInt(v) : null);

  try {
    const existing = await dbGet(
      "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND admin_approve='PENDING' LIMIT 1",
      [emp_id],
    );

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

    let requestId;

    if (existing) {
      await dbRun(
        `UPDATE employee_pending_request SET
           first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?,
           date_of_birth=?, gender=?, department_id=?, role_id=?,
           date_of_joining=?, date_of_relieving=?, employment_type=?, work_type=?,
           permanent_address=?, communication_address=?,
           aadhar_number=?, pan_number=?, passport_number=?,
           father_name=?, emergency_contact_relation=?, emergency_contact=?,
           pf_number=?, esic_number=?, years_experience=?,
           status=?, edit_reason=?, updated_at=NOW()
         WHERE emp_id=? AND admin_approve='PENDING'`,
        [...sharedFields, emp_id],
      );
      requestId = existing.request_id;
    } else {
      const result = await dbRun(
        `INSERT INTO employee_pending_request
           (emp_id, first_name, mid_name, last_name, email_id, phone_number,
            date_of_birth, gender, department_id, role_id, tl_id, date_of_joining,
            date_of_relieving, employment_type, work_type, permanent_address,
            communication_address, aadhar_number, pan_number, passport_number,
            father_name, emergency_contact_relation, emergency_contact,
            pf_number, esic_number, years_experience, status,
            admin_approve, username, password, request_type, edit_reason,
            created_at, updated_at)
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
          `INSERT INTO education_pending_request
             (request_id, education_level, stream, score, year_of_passout, university, college_name)
           VALUES ?`,
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
    console.error("[employee-edit-request]", err);
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
         first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?,
         date_of_birth=?, gender=?, department_id=?, role_id=?, date_of_joining=?,
         employment_type=?, work_type=?, permanent_address=?, communication_address=?,
         aadhar_number=?, pan_number=?, passport_number=?,
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
        `INSERT INTO education_pending_request
           (request_id, education_level, stream, score, year_of_passout, university, college_name)
         VALUES ?`,
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
          CONCAT(e.first_name,
            CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != ''
              THEN CONCAT(' ', e.mid_name) ELSE '' END,
            ' ', e.last_name) AS full_name,
          lm.status, lm.session_token, lm.session_device,
          lm.device_logged_in, lm.last_login_at, lm.updated_at
       FROM login_master lm
       LEFT JOIN employee_master e ON lm.emp_id = e.emp_id
       LEFT JOIN role_master r ON lm.role_id = r.role_id
       WHERE lm.status = 'Active'
       ORDER BY lm.last_login_at DESC`,
    );

    const sessions = rows.map((row) => {
      const deviceInfo = parseDeviceInfo(row.session_device);
      return {
        loginId: row.login_id,
        empId: row.emp_id,
        username: row.username,
        fullName: row.full_name?.trim() || row.username,
        roleName: row.role_name || "-",
        isLoggedIn: row.device_logged_in === 1 && row.session_token !== null,
        deviceInfo,
        lastLoginAt: row.last_login_at || null,
        updatedAt: row.updated_at || null,
      };
    });

    res.json({ success: true, data: sessions });
  } catch (err) {
    console.error("[admin/sessions]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/admin/sessions/:loginId/force-logout", async (req, res) => {
  const { loginId } = req.params;
  if (!loginId || isNaN(parseInt(loginId)))
    return res.status(400).json({ success: false, message: "Invalid loginId" });

  try {
    const user = await dbGet(
      `SELECT login_id, emp_id, username, device_logged_in, session_token
       FROM login_master WHERE login_id = ? AND status = 'Active'`,
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

    await dbRun(
      `UPDATE login_master
       SET session_token=NULL, session_device=NULL, device_logged_in=0, updated_at=NOW()
       WHERE login_id=?`,
      [loginId],
    );
    res.json({
      success: true,
      message: `${user.username} has been logged out`,
    });
  } catch (err) {
    console.error("[force-logout]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post("/admin/sessions/force-logout-all/:empId", async (req, res) => {
  const { empId } = req.params;
  if (!empId || isNaN(parseInt(empId)))
    return res.status(400).json({ success: false, message: "Invalid empId" });

  try {
    const result = await dbRun(
      `UPDATE login_master
       SET session_token=NULL, session_device=NULL, device_logged_in=0, updated_at=NOW()
       WHERE emp_id=? AND status='Active'`,
      [empId],
    );
    res.json({
      success: true,
      message: `All sessions cleared (${result.affectedRows} account(s))`,
      affectedRows: result.affectedRows,
    });
  } catch (err) {
    console.error("[force-logout-all]", err);
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
      `INSERT INTO login_logs
         (emp_id, username, status, ip_address, device_info, failure_reason, login_time)
       VALUES (?, ?, ?, ?, ?, ?, NOW())`,
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
app.get("/admin/sessions/:loginId/status", async (req, res) => {
  const { loginId } = req.params;
  try {
    const row = await dbGet(
      `SELECT lm.login_id, lm.username, lm.session_device,
          lm.device_logged_in, lm.last_login_at,
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

// ─── CHANGE PASSWORD (first-login forced) ────────────────────────────────────
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
      `SELECT login_id, emp_id, role_id, username FROM login_master
       WHERE login_id=? AND status='Active'`,
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
      `UPDATE login_master
       SET password=?, is_first_login=0, password_updated_at=NOW(),
           session_token=?, session_device=?, device_logged_in=1,
           last_login_at=NOW(), failed_attempts=0, locked_until=NULL, updated_at=NOW()
       WHERE login_id=?`,
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
    console.error("[change-password]", err);
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
      `SELECT login_id, emp_id, role_id, username FROM login_master
       WHERE emp_id=? AND status='Active'`,
      [emp_id],
    );
    if (!user)
      return res
        .status(404)
        .json({ success: false, message: "User not found" });

    const hashed = await bcrypt.hash(new_password, 10);

    // ── Reset password + force first login + clear ALL sessions ──────────────
    await dbRun(
      `UPDATE login_master
       SET password          = ?,
           is_first_login    = 1,
           password_updated_at = NOW(),
           session_token     = NULL,
           session_device    = NULL,
           device_logged_in  = 0,
           failed_attempts   = 0,
           locked_until      = NULL,
           updated_at        = NOW()
       WHERE emp_id = ? AND status = 'Active'`,
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
    console.error("[reset-password]", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
});

// ─── LOGIN AUDIT LOGS (admin view) ───────────────────────────────────────────
app.get("/auth/login-logs", async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit || "100"), 500);
  const empId = req.query.emp_id || null;
  const status = req.query.status || null;
  let sql = `SELECT log_id, emp_id, username, status, ip_address,
                    device_info, failure_reason, login_time
             FROM login_logs WHERE 1=1`;
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

// ─── GET TEAM LEADS ─────────────────────────────────────────────
app.get("/team-leads", async (req, res) => {
  try {
    const rows = await dbAll(`
      SELECT 
        emp_id AS id,
        TRIM(CONCAT(first_name, ' ', IFNULL(mid_name, ''), ' ', last_name)) AS name
      FROM employee_master
      WHERE role_id = 3
        AND status = 'Active'
      ORDER BY first_name ASC
    `);

    res.json({
      success: true,
      data: rows,
    });
  } catch (err) {
    console.error("Error fetching TL list:", err);
    res.status(500).json({
      success: false,
      message: "Failed to fetch team leads",
    });
  }
});

// ─── TL: leave history for only their team members ────────────────────────
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
          l.leave_id,
          l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          d.department_name,
          r.role_name,
          l.leave_type,
          DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS from_date,
          DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS to_date,
          l.number_of_days AS total_days,
          l.status,
          l.reason,
          l.rejection_reason,
          l.cancel_reason,
          CASE
            WHEN l.recommended_by IS NOT NULL
            THEN CONCAT(tl_emp.first_name, ' ', tl_emp.last_name)
            ELSE NULL
          END AS recommended_by_name,
          CASE
            WHEN l.approved_by IS NOT NULL
            THEN CONCAT(mgr_emp.first_name, ' ', mgr_emp.last_name)
            ELSE NULL
          END AS approved_by_name
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

// ─── TL: attendance for their team only ──────────────────────────────────────
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
      `SELECT
          e.emp_id,
          TRIM(CONCAT(e.first_name, ' ', IFNULL(e.mid_name, ''), ' ', e.last_name)) AS name,
          s.site_name AS location_name,
          a.id AS visit_id,
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
// ─── START SERVER ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(`Server running on http://0.0.0.0:${PORT}`),
);
