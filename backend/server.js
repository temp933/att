// const express = require("express");
// const mysql = require("mysql2");
// const cors = require("cors");

// const app = express();
// const PORT = 3000;

// app.use(cors());
// app.use(express.json());

// app.get("/", (req, res) => res.send("API is running"));

// const db = mysql.createPool({
//   host: "127.0.0.1",
//   user: "root",
//   password: "2026",
//   database: "attendance_system",
//   waitForConnections: true,
//   connectionLimit: 10,
//   queueLimit: 0,
// });

// db.getConnection((err, connection) => {
//   if (err) console.error("DB Connection Error:", err);
//   else {
//     console.log("MySQL Pool Connected");
//     connection.release();
//   }
// });

// /* ======================
//    ADMIN APIs
// ====================== */

// app.post("/sites", (req, res) => {
//   const { site_name, polygon_json, start_date, end_date } = req.body;
//   if (!site_name || !polygon_json || !start_date || !end_date)
//     return res.status(400).json({ message: "Missing required fields" });

//   db.query(
//     `INSERT INTO sites (site_name, polygon_json, start_date, end_date) VALUES (?, ?, ?, ?)`,
//     [site_name, JSON.stringify(polygon_json), start_date, end_date],
//     (err, result) => {
//       if (err) {
//         console.error(err);
//         return res.status(500).json({ message: "Database error" });
//       }
//       res.json({ message: "Site saved", id: result.insertId });
//     },
//   );
// });

// app.get("/sites", (req, res) => {
//   db.query(
//     `SELECT id, site_name, polygon_json,
//       DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
//       DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
//       created_at FROM sites`,
//     (err, results) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       res.json(results);
//     },
//   );
// });

// app.put("/sites/:id", (req, res) => {
//   const { id } = req.params;
//   const { site_name, polygon_json, start_date, end_date } = req.body;
//   if (!site_name || !polygon_json || !start_date || !end_date)
//     return res.status(400).json({ message: "Missing required fields" });

//   db.query(
//     `UPDATE sites SET site_name = ?, polygon_json = ?, start_date = ?, end_date = ? WHERE id = ?`,
//     [site_name, JSON.stringify(polygon_json), start_date, end_date, id],
//     (err) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       res.json({ message: "Site updated successfully" });
//     },
//   );
// });

// /* ======================
//    LOCATION CHECK
// ====================== */

// app.post("/attendance/check-location", (req, res) => {
//   const { lat, lng } = req.body;
//   if (lat == null || lng == null)
//     return res.status(400).json({ message: "lat and lng are required" });

//   db.query(
//     `SELECT id, site_name, polygon_json FROM sites WHERE CURDATE() BETWEEN start_date AND end_date`,
//     (err, rows) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       for (const site of rows) {
//         const polygon = JSON.parse(site.polygon_json);
//         if (
//           isPointInPolygon(lat, lng, polygon) ||
//           isNearPolygon(lat, lng, polygon)
//         ) {
//           return res.json({
//             inside: true,
//             site_id: site.id,
//             site_name: site.site_name,
//           });
//         }
//       }
//       res.json({ inside: false });
//     },
//   );
// });

// function isPointInPolygon(lat, lng, polygon) {
//   const pts = [...polygon];
//   if (
//     pts[0].lat !== pts[pts.length - 1].lat ||
//     pts[0].lng !== pts[pts.length - 1].lng
//   )
//     pts.push({ lat: pts[0].lat, lng: pts[0].lng });
//   let intersect = 0;
//   for (let i = 0; i < pts.length - 1; i++) {
//     const p1 = pts[i],
//       p2 = pts[i + 1];
//     if (
//       p1.lng > lng !== p2.lng > lng &&
//       lat < ((p2.lat - p1.lat) * (lng - p1.lng)) / (p2.lng - p1.lng) + p1.lat
//     )
//       intersect++;
//   }
//   return intersect % 2 === 1;
// }

// function getDistance(lat1, lng1, lat2, lng2) {
//   const R = 6371000;
//   const dLat = ((lat2 - lat1) * Math.PI) / 180;
//   const dLng = ((lng2 - lng1) * Math.PI) / 180;
//   const a =
//     Math.sin(dLat / 2) ** 2 +
//     Math.cos((lat1 * Math.PI) / 180) *
//       Math.cos((lat2 * Math.PI) / 180) *
//       Math.sin(dLng / 2) ** 2;
//   return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
// }

// function isNearPolygon(lat, lng, polygon, bufferMeters = 35) {
//   const pts = [...polygon];
//   if (
//     pts[0].lat !== pts[pts.length - 1].lat ||
//     pts[0].lng !== pts[pts.length - 1].lng
//   )
//     pts.push({ lat: pts[0].lat, lng: pts[0].lng });
//   for (let i = 0; i < pts.length - 1; i++) {
//     if (getDistance(lat, lng, pts[i].lat, pts[i].lng) <= bufferMeters)
//       return true;
//     if (isNearSegment(lat, lng, pts[i], pts[i + 1], bufferMeters)) return true;
//   }
//   return false;
// }

// function isNearSegment(lat, lng, p1, p2, bufferMeters) {
//   const dx = p2.lat - p1.lat,
//     dy = p2.lng - p1.lng;
//   const lenSq = dx * dx + dy * dy;
//   if (lenSq === 0) return getDistance(lat, lng, p1.lat, p1.lng) <= bufferMeters;
//   const t = Math.max(
//     0,
//     Math.min(1, ((lat - p1.lat) * dx + (lng - p1.lng) * dy) / lenSq),
//   );
//   return (
//     getDistance(lat, lng, p1.lat + t * dx, p1.lng + t * dy) <= bufferMeters
//   );
// }

// /* ======================
//    MARK IN
//    Rules:
//    1. Same site, row is open (out_time IS NULL) → already IN, do nothing
//    2. Same site, row closed < 15 min ago → reopen: reset in_time, clear out_time
//    3. Same site, row closed >= 15 min ago → create new row (long break / new visit)
//    4. Different site open → close it first, then apply rules 1-3 for new site
//    5. No row today for this site → create new row
// ====================== */
// app.post("/attendance/in", (req, res) => {
//   const { employee_id, site_id } = req.body;
//   if (!employee_id || !site_id)
//     return res
//       .status(400)
//       .json({ message: "employee_id and site_id are required" });

//   // Check site is active today
//   db.query(
//     `SELECT id FROM sites WHERE id = ? AND CURDATE() BETWEEN start_date AND end_date`,
//     [site_id],
//     (err, siteRows) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       if (siteRows.length === 0)
//         return res.status(400).json({ message: "Site not active today" });

//       // Close any open record at a DIFFERENT site first
//       db.query(
//         `UPDATE attendance_logs
//          SET out_time = NOW(), updated_at = NOW()
//          WHERE employee_id = ? AND site_id != ? AND work_date = CURDATE() AND out_time IS NULL`,
//         [employee_id, site_id],
//         (err) => {
//           if (err) return res.status(500).json({ message: "Database error" });

//           // Now check current site's most recent row today
//           db.query(
//             `SELECT id, out_time,
//                TIMESTAMPDIFF(MINUTE, out_time, NOW()) AS minutes_since_out
//              FROM attendance_logs
//              WHERE employee_id = ? AND site_id = ? AND work_date = CURDATE()
//              ORDER BY id DESC LIMIT 1`,
//             [employee_id, site_id],
//             (err, rows) => {
//               if (err)
//                 return res.status(500).json({ message: "Database error" });

//               if (rows.length === 0) {
//                 // Rule 5: No row for this site today — create fresh
//                 return createNewRow(employee_id, site_id, res);
//               }

//               const row = rows[0];

//               if (row.out_time === null) {
//                 // Rule 1: Already open — do nothing
//                 return res.json({ message: "Already IN at this site" });
//               }

//               if (
//                 row.minutes_since_out !== null &&
//                 row.minutes_since_out < 15
//               ) {
//                 // Rule 2: Returned within 15 min — reopen same row, keep original in_time
//                 db.query(
//                   `UPDATE attendance_logs
//                    SET out_time = NULL, updated_at = NOW()
//                    WHERE id = ?`,
//                   [row.id],
//                   (err) => {
//                     if (err)
//                       return res
//                         .status(500)
//                         .json({ message: "Database error" });
//                     res.json({
//                       message: "IN marked (returned within 15min)",
//                       id: row.id,
//                     });
//                   },
//                 );
//               } else {
//                 // Rule 3: Been away >= 15 min — new row (new visit / after long break)
//                 return createNewRow(employee_id, site_id, res);
//               }
//             },
//           );
//         },
//       );
//     },
//   );
// });

// function createNewRow(employee_id, site_id, res) {
//   db.query(
//     `INSERT INTO attendance_logs (employee_id, site_id, in_time, work_date, updated_at)
//      VALUES (?, ?, NOW(), CURDATE(), NOW())`,
//     [employee_id, site_id],
//     (err, result) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       res.json({ message: "IN marked (new row)", id: result.insertId });
//     },
//   );
// }

// /* ======================
//    MARK OUT
// ====================== */
// app.post("/attendance/out", (req, res) => {
//   const { employee_id } = req.body;
//   if (!employee_id)
//     return res.status(400).json({ message: "employee_id is required" });

//   db.query(
//     `UPDATE attendance_logs
//      SET out_time = NOW(), updated_at = NOW()
//      WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
//     [employee_id],
//     (err) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       res.json({ message: "OUT marked" });
//     },
//   );
// });

// /* ======================
//    HEARTBEAT
//    Updates updated_at every second + out_time as rolling "last seen"
//    while employee is confirmed inside a site.
//    out_time will be overwritten with the real final time on markOut.
// ====================== */
// app.put("/attendance/heartbeat", (req, res) => {
//   const { employee_id } = req.body;
//   if (!employee_id)
//     return res.status(400).json({ message: "employee_id is required" });

//   db.query(
//     `UPDATE attendance_logs
//      SET updated_at = NOW(), out_time = NOW()
//      WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL
//      ORDER BY id DESC LIMIT 1`,
//     [employee_id],
//     (err, result) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       res.json({ message: "ok", updated: result.affectedRows });
//     },
//   );
// });

// /* ======================
//    END DAY
//    Closes all open rows and marks day as done.
// ====================== */
// app.post("/attendance/end-day", (req, res) => {
//   const { employee_id } = req.body;
//   if (!employee_id)
//     return res.status(400).json({ message: "employee_id is required" });

//   db.query(
//     `UPDATE attendance_logs
//      SET out_time = NOW(), updated_at = NOW(), status = 'completed'
//      WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
//     [employee_id],
//     (err) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       res.json({ message: "Day ended" });
//     },
//   );
// });

// /* ======================
//    STATUS CHECK
// ====================== */
// app.get("/attendance/status/:empId", (req, res) => {
//   db.query(
//     `SELECT * FROM attendance_logs
//      WHERE employee_id = ? AND work_date = CURDATE()
//      ORDER BY id DESC LIMIT 1`,
//     [req.params.empId],
//     (err, rows) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       if (rows.length === 0) return res.json({ status: "not_started" });
//       const row = rows[0];
//       if (row.status === "completed") return res.json({ status: "completed" });
//       if (row.out_time !== null) return res.json({ status: "completed" });
//       return res.json({ status: "in_progress" });
//     },
//   );
// });

// /* ======================
//    TODAY'S LOGS — all site visits for employee today
//    Returns each row with site name, in_time, out_time
//    Used by employee home screen to show site-by-site breakdown
// ====================== */
// app.get("/attendance/today/:empId", (req, res) => {
//   db.query(
//     `SELECT
//        a.id,
//        a.site_id,
//        s.site_name,
//        DATE_FORMAT(a.in_time,  '%H:%i:%s') AS in_time,
//        DATE_FORMAT(a.out_time, '%H:%i:%s') AS out_time,
//        a.work_date,
//        a.status,
//        TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS duration_minutes
//      FROM attendance_logs a
//      JOIN sites s ON a.site_id = s.id
//      WHERE a.employee_id = ? AND a.work_date = CURDATE()
//      ORDER BY a.in_time ASC`,
//     [req.params.empId],
//     (err, results) => {
//       if (err) return res.status(500).json({ message: "Database error" });
//       res.json(results);
//     },
//   );
// });

// app.listen(PORT, "0.0.0.0", () =>
//   console.log(`Server running on port ${PORT}`),
// );
const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => res.send("API is running"));

const db = mysql.createPool({
  host: "127.0.0.1",
  user: "root",
  password: "2026",
  database: "attendance_system",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

db.getConnection((err, connection) => {
  if (err) console.error("DB Connection Error:", err);
  else {
    console.log("MySQL Pool Connected");
    connection.release();
  }
});

/* ======================
   AUTH
====================== */

/* LOGIN — validates credentials, returns employee id + role + name */
app.post("/auth/login", (req, res) => {
  const { login_id, password } = req.body;

  if (!login_id || !password)
    return res
      .status(400)
      .json({ message: "login_id and password are required" });

  db.query(
    `SELECT id, name, role FROM employees WHERE login_id = ? AND password = ?`,
    [login_id, password],
    (err, rows) => {
      if (err) return res.status(500).json({ message: "Database error" });
      if (rows.length === 0)
        return res
          .status(401)
          .json({ message: "Invalid Login ID or Password" });
      const user = rows[0];
      res.json({ id: user.id, name: user.name, role: user.role.toLowerCase() });
    },
  );
});

/* ======================
   ADMIN APIs
====================== */

app.post("/sites", (req, res) => {
  const { site_name, polygon_json, start_date, end_date } = req.body;
  if (!site_name || !polygon_json || !start_date || !end_date)
    return res.status(400).json({ message: "Missing required fields" });

  db.query(
    `INSERT INTO sites (site_name, polygon_json, start_date, end_date) VALUES (?, ?, ?, ?)`,
    [site_name, JSON.stringify(polygon_json), start_date, end_date],
    (err, result) => {
      if (err) {
        console.error(err);
        return res.status(500).json({ message: "Database error" });
      }
      res.json({ message: "Site saved", id: result.insertId });
    },
  );
});

app.get("/sites", (req, res) => {
  db.query(
    `SELECT id, site_name, polygon_json,
      DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
      DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
      created_at FROM sites`,
    (err, results) => {
      if (err) return res.status(500).json({ message: "Database error" });
      res.json(results);
    },
  );
});

app.put("/sites/:id", (req, res) => {
  const { id } = req.params;
  const { site_name, polygon_json, start_date, end_date } = req.body;
  if (!site_name || !polygon_json || !start_date || !end_date)
    return res.status(400).json({ message: "Missing required fields" });

  db.query(
    `UPDATE sites SET site_name = ?, polygon_json = ?, start_date = ?, end_date = ? WHERE id = ?`,
    [site_name, JSON.stringify(polygon_json), start_date, end_date, id],
    (err) => {
      if (err) return res.status(500).json({ message: "Database error" });
      res.json({ message: "Site updated successfully" });
    },
  );
});

/* ======================
   LOCATION CHECK
====================== */

app.post("/attendance/check-location", (req, res) => {
  const { lat, lng } = req.body;
  if (lat == null || lng == null)
    return res.status(400).json({ message: "lat and lng are required" });

  db.query(
    `SELECT id, site_name, polygon_json FROM sites WHERE CURDATE() BETWEEN start_date AND end_date`,
    (err, rows) => {
      if (err) return res.status(500).json({ message: "Database error" });
      for (const site of rows) {
        const polygon = JSON.parse(site.polygon_json);
        if (
          isPointInPolygon(lat, lng, polygon) ||
          isNearPolygon(lat, lng, polygon)
        ) {
          return res.json({
            inside: true,
            site_id: site.id,
            site_name: site.site_name,
          });
        }
      }
      res.json({ inside: false });
    },
  );
});

function isPointInPolygon(lat, lng, polygon) {
  const pts = [...polygon];
  if (
    pts[0].lat !== pts[pts.length - 1].lat ||
    pts[0].lng !== pts[pts.length - 1].lng
  )
    pts.push({ lat: pts[0].lat, lng: pts[0].lng });
  let intersect = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const p1 = pts[i],
      p2 = pts[i + 1];
    if (
      p1.lng > lng !== p2.lng > lng &&
      lat < ((p2.lat - p1.lat) * (lng - p1.lng)) / (p2.lng - p1.lng) + p1.lat
    )
      intersect++;
  }
  return intersect % 2 === 1;
}

function getDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function isNearPolygon(lat, lng, polygon, bufferMeters = 35) {
  const pts = [...polygon];
  if (
    pts[0].lat !== pts[pts.length - 1].lat ||
    pts[0].lng !== pts[pts.length - 1].lng
  )
    pts.push({ lat: pts[0].lat, lng: pts[0].lng });
  for (let i = 0; i < pts.length - 1; i++) {
    if (getDistance(lat, lng, pts[i].lat, pts[i].lng) <= bufferMeters)
      return true;
    if (isNearSegment(lat, lng, pts[i], pts[i + 1], bufferMeters)) return true;
  }
  return false;
}

function isNearSegment(lat, lng, p1, p2, bufferMeters) {
  const dx = p2.lat - p1.lat,
    dy = p2.lng - p1.lng;
  const lenSq = dx * dx + dy * dy;
  if (lenSq === 0) return getDistance(lat, lng, p1.lat, p1.lng) <= bufferMeters;
  const t = Math.max(
    0,
    Math.min(1, ((lat - p1.lat) * dx + (lng - p1.lng) * dy) / lenSq),
  );
  return (
    getDistance(lat, lng, p1.lat + t * dx, p1.lng + t * dy) <= bufferMeters
  );
}

/* ======================
   MARK IN
   Rules:
   1. Same site, row is open (out_time IS NULL) → already IN, do nothing
   2. Same site, row closed < 15 min ago → reopen: reset in_time, clear out_time
   3. Same site, row closed >= 15 min ago → create new row (long break / new visit)
   4. Different site open → close it first, then apply rules 1-3 for new site
   5. No row today for this site → create new row
====================== */
app.post("/attendance/in", (req, res) => {
  const { employee_id, site_id } = req.body;
  if (!employee_id || !site_id)
    return res
      .status(400)
      .json({ message: "employee_id and site_id are required" });

  // Check site is active today
  db.query(
    `SELECT id FROM sites WHERE id = ? AND CURDATE() BETWEEN start_date AND end_date`,
    [site_id],
    (err, siteRows) => {
      if (err) return res.status(500).json({ message: "Database error" });
      if (siteRows.length === 0)
        return res.status(400).json({ message: "Site not active today" });

      // Close any open record at a DIFFERENT site first
      db.query(
        `UPDATE attendance_logs
         SET out_time = NOW(), updated_at = NOW()
         WHERE employee_id = ? AND site_id != ? AND work_date = CURDATE() AND out_time IS NULL`,
        [employee_id, site_id],
        (err) => {
          if (err) return res.status(500).json({ message: "Database error" });

          // Now check current site's most recent row today
          db.query(
            `SELECT id, out_time,
               TIMESTAMPDIFF(MINUTE, out_time, NOW()) AS minutes_since_out
             FROM attendance_logs
             WHERE employee_id = ? AND site_id = ? AND work_date = CURDATE()
             ORDER BY id DESC LIMIT 1`,
            [employee_id, site_id],
            (err, rows) => {
              if (err)
                return res.status(500).json({ message: "Database error" });

              if (rows.length === 0) {
                // Rule 5: No row for this site today — create fresh
                return createNewRow(employee_id, site_id, res);
              }

              const row = rows[0];

              if (row.out_time === null) {
                // Rule 1: Already open — do nothing
                return res.json({ message: "Already IN at this site" });
              }

              if (
                row.minutes_since_out !== null &&
                row.minutes_since_out < 15
              ) {
                // Rule 2: Returned within 15 min — reopen same row, keep original in_time
                db.query(
                  `UPDATE attendance_logs
                   SET out_time = NULL, updated_at = NOW()
                   WHERE id = ?`,
                  [row.id],
                  (err) => {
                    if (err)
                      return res
                        .status(500)
                        .json({ message: "Database error" });
                    res.json({
                      message: "IN marked (returned within 15min)",
                      id: row.id,
                    });
                  },
                );
              } else {
                // Rule 3: Been away >= 15 min — new row (new visit / after long break)
                return createNewRow(employee_id, site_id, res);
              }
            },
          );
        },
      );
    },
  );
});

function createNewRow(employee_id, site_id, res) {
  db.query(
    `INSERT INTO attendance_logs (employee_id, site_id, in_time, work_date, updated_at)
     VALUES (?, ?, NOW(), CURDATE(), NOW())`,
    [employee_id, site_id],
    (err, result) => {
      if (err) return res.status(500).json({ message: "Database error" });
      res.json({ message: "IN marked (new row)", id: result.insertId });
    },
  );
}

/* ======================
   MARK OUT
====================== */
app.post("/attendance/out", (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id is required" });

  db.query(
    `UPDATE attendance_logs
     SET out_time = NOW(), updated_at = NOW()
     WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
    [employee_id],
    (err) => {
      if (err) return res.status(500).json({ message: "Database error" });
      res.json({ message: "OUT marked" });
    },
  );
});

/* ======================
   HEARTBEAT
   Updates updated_at every second + out_time as rolling "last seen"
   while employee is confirmed inside a site.
   out_time will be overwritten with the real final time on markOut.
====================== */
app.put("/attendance/heartbeat", (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id is required" });

  db.query(
    `UPDATE attendance_logs
     SET updated_at = NOW(), out_time = NOW()
     WHERE employee_id = ? AND work_date = CURDATE()
     ORDER BY id DESC LIMIT 1`,
    [employee_id],
    (err, result) => {
      if (err) return res.status(500).json({ message: "Database error" });
      res.json({ message: "ok", updated: result.affectedRows });
    },
  );
});

/* ======================
   END DAY
   Closes all open rows and marks day as done.
====================== */
app.post("/attendance/end-day", (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id is required" });

  db.query(
    `UPDATE attendance_logs
     SET out_time = NOW(), updated_at = NOW(), status = 'completed'
     WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
    [employee_id],
    (err) => {
      if (err) return res.status(500).json({ message: "Database error" });
      res.json({ message: "Day ended" });
    },
  );
});

/* ======================
   STATUS CHECK
====================== */
app.get("/attendance/status/:empId", (req, res) => {
  db.query(
    `SELECT * FROM attendance_logs
     WHERE employee_id = ? AND work_date = CURDATE()
     ORDER BY id DESC LIMIT 1`,
    [req.params.empId],
    (err, rows) => {
      if (err) return res.status(500).json({ message: "Database error" });
      if (rows.length === 0) return res.json({ status: "not_started" });
      const row = rows[0];
      if (row.status === "completed") return res.json({ status: "completed" });
      if (row.out_time !== null) return res.json({ status: "completed" });
      return res.json({ status: "in_progress" });
    },
  );
});

/* ======================
   TODAY'S LOGS — all site visits for employee today
   Returns each row with site name, in_time, out_time
   Used by employee home screen to show site-by-site breakdown
====================== */
app.get("/attendance/today/:empId", (req, res) => {
  db.query(
    `SELECT
       a.id,
       a.site_id,
       s.site_name,
       DATE_FORMAT(a.in_time,  '%H:%i:%s') AS in_time,
       DATE_FORMAT(a.out_time, '%H:%i:%s') AS out_time,
       a.work_date,
       a.status,
       TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS duration_minutes
     FROM attendance_logs a
     JOIN sites s ON a.site_id = s.id
     WHERE a.employee_id = ? AND a.work_date = CURDATE()
     ORDER BY a.in_time ASC`,
    [req.params.empId],
    (err, results) => {
      if (err) return res.status(500).json({ message: "Database error" });
      res.json(results);
    },
  );
});

app.listen(PORT, "0.0.0.0", () =>
  console.log(`Server running on port ${PORT}`),
);
