// // const express = require("express");
// // const mysql = require("mysql2");
// // const cors = require("cors");

// // const app = express();
// // app.use(express.json());
// // app.use(cors());

// // const db = mysql.createConnection({
// //   host: "localhost",
// //   user: "root",
// //   password: "2026",
// //   database: "kavidhan",
// // });

// // db.connect((err) => {
// //   if (err) {
// //     console.error("DB connection error:", err);
// //     process.exit(1);
// //   }
// //   console.log("MySQL connected!");
// // });

// // app.get("/roles", (req, res) => {
// //   db.query(
// //     "SELECT role_id AS id, role_name AS name FROM role_master ORDER BY role_name ASC",
// //     (err, result) => {
// //       if (err)
// //         return res.status(500).json({
// //           success: false,
// //           message: "Failed to fetch roles",
// //           error: err.message,
// //         });
// //       res.json({ success: true, data: result });
// //     },
// //   );
// // });

// // app.post("/login", (req, res) => {
// //   const { username, password } = req.body;

// //   if (!username || !password) {
// //     return res.status(400).json({ message: "Username and password required" });
// //   }

// //   const sql = `
// //     SELECT login_id, emp_id, role_id, username
// //     FROM login_master
// //     WHERE TRIM(LOWER(username)) = TRIM(LOWER(?))
// //       AND password = ?
// //       AND status = 'Active'
// //   `;

// //   db.query(sql, [username, password], (err, results) => {
// //     if (err) {
// //       console.error(err);
// //       return res.status(500).json({ message: "DB error" });
// //     }

// //     if (results.length === 0) {
// //       return res.status(401).json({ message: "Invalid username or password" });
// //     }

// //     const user = results[0];

// //     res.json({
// //       loginId: user.login_id,
// //       empId: user.emp_id,
// //       roleId: user.role_id,
// //       username: user.username.trim(),
// //     });
// //   });
// // });

// // app.get("/login", (req, res) =>
// //   res.send("Login API is live. Use POST method."),
// // );

// // app.get("/login-user/:loginId", (req, res) => {
// //   db.query(
// //     `SELECT
// //        lm.emp_id,
// //        lm.username,
// //        r.role_name,
// //        CONCAT(
// //          e.first_name,
// //          CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != '' THEN CONCAT(' ', e.mid_name) ELSE '' END,
// //          ' ', e.last_name
// //        ) AS full_name
// //      FROM login_master lm
// //      LEFT JOIN employee_master e  ON lm.emp_id  = e.emp_id
// //      LEFT JOIN role_master     r  ON lm.role_id = r.role_id
// //      WHERE lm.login_id = ?`,
// //     [req.params.loginId],
// //     (err, results) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (results.length === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Login not found" });

// //       const u = results[0];
// //       res.json({
// //         success: true,
// //         login_id: req.params.loginId,
// //         emp_id: u.emp_id,
// //         full_name: u.full_name?.trim() || u.username,
// //         role_name: u.role_name || "-",
// //       });
// //     },
// //   );
// // });

// // // ─── GET EMPLOYEE BY ID ───────────────────────────────────────────────────────
// // app.get("/employees/:empId", (req, res) => {
// //   const query = `
// //     SELECT
// //       e.emp_id,
// //       e.first_name,
// //       e.mid_name,
// //       e.last_name,
// //       e.email_id,
// //       e.phone_number,
// //       DATE_FORMAT(e.date_of_birth, '%Y-%m-%d') AS date_of_birth,
// //       e.gender,
// //       e.department_id,
// //       e.role_id,
// //       DATE_FORMAT(e.date_of_joining, '%Y-%m-%d') AS date_of_joining,
// //       DATE_FORMAT(e.date_of_relieving, '%Y-%m-%d') AS date_of_relieving,
// //       e.employment_type,
// //       e.work_type,
// //       e.permanent_address,
// //       e.communication_address,
// //       e.aadhar_number,
// //       e.pan_number,
// //       e.passport_number,
// //       e.father_name,
// //       e.emergency_contact,
// //       e.pf_number,
// //       e.esic_number,
// //       e.years_experience,
// //       e.status,
// //       d.department_name,
// //       r.role_name
// //     FROM employee_master e
// //     LEFT JOIN department_master d
// //       ON e.department_id = d.department_id
// //     LEFT JOIN role_master r
// //       ON e.role_id = r.role_id
// //     WHERE e.emp_id = ?`;

// //   db.query(query, [req.params.empId], (err, results) => {
// //     if (err) return res.status(500).json({ error: err.message });
// //     if (results.length === 0)
// //       return res.status(404).json({ error: "Employee not found" });
// //     res.json(results[0]);
// //   });
// // });

// // app.get("/employees/:empId/leaves", (req, res) => {
// //   db.query(
// //     `SELECT
// //       leave_id,
// //       emp_id,
// //       leave_type,
// //       DATE_FORMAT(leave_start_date, '%Y-%m-%d') AS leave_start_date,
// //       DATE_FORMAT(leave_end_date, '%Y-%m-%d') AS leave_end_date,
// //       number_of_days,
// //       recommended_by,
// //       DATE_FORMAT(recommended_at, '%Y-%m-%d %H:%i:%s') AS recommended_at,
// //       approved_by,
// //       status,
// //       reason,
// //       cancel_reason,
// //       rejection_reason,
// //       DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
// //       DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
// //     FROM leave_master
// //     WHERE emp_id = ?
// //     ORDER BY leave_start_date DESC`,
// //     [req.params.empId],
// //     (err, results) => {
// //       if (err)
// //         return res
// //           .status(500)
// //           .json({ success: false, message: "Internal server error" });
// //       res.json({ success: true, data: results });
// //     },
// //   );
// // });

// // app.post("/employees/:empId/apply-leave", (req, res) => {
// //   const { leave_type, leave_start_date, leave_end_date, reason } = req.body;
// //   if (!leave_type || !leave_start_date || !leave_end_date)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Leave type and dates are required" });
// //   db.query(
// //     `INSERT INTO leave_master (emp_id, leave_type, leave_start_date, leave_end_date, reason, status, created_at, updated_at)
// //     VALUES (?, ?, ?, ?, ?, 'Pending_TL', NOW(), NOW())`,
// //     [
// //       req.params.empId,
// //       leave_type,
// //       leave_start_date,
// //       leave_end_date,
// //       reason || "",
// //     ],
// //     (err) => {
// //       if (err)
// //         return res
// //           .status(500)
// //           .json({ success: false, message: "Internal server error" });
// //       res.json({ success: true, message: "Leave applied successfully" });
// //     },
// //   );
// // });

// // app.put("/leave/:leaveId", (req, res) => {
// //   const { leave_type, leave_start_date, leave_end_date, reason } = req.body;
// //   if (!leave_type || !leave_start_date || !leave_end_date)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Leave type and dates are required" });
// //   db.query(
// //     `UPDATE leave_master SET leave_type=?, leave_start_date=?, leave_end_date=?, reason=?, updated_at=NOW()
// //      WHERE leave_id=? AND status='Pending_TL'`,
// //     [
// //       leave_type,
// //       leave_start_date,
// //       leave_end_date,
// //       reason || "",
// //       req.params.leaveId,
// //     ],
// //     (err, result) => {
// //       if (err)
// //         return res
// //           .status(500)
// //           .json({ success: false, message: "Internal server error" });
// //       if (result.affectedRows === 0)
// //         return res.status(400).json({
// //           success: false,
// //           message: "Only leaves pending TL review can be edited",
// //         });
// //       res.json({ success: true, message: "Leave updated successfully" });
// //     },
// //   );
// // });

// // app.put("/leave/:leaveId/cancel", (req, res) => {
// //   const { cancel_reason } = req.body;
// //   if (!cancel_reason || cancel_reason.trim() === "")
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Cancel reason is required" });
// //   db.query(
// //     `UPDATE leave_master SET status='Cancelled', cancel_reason=? WHERE leave_id=? AND status='Pending_TL'`,
// //     [cancel_reason, req.params.leaveId],
// //     (err, result) => {
// //       if (err)
// //         return res
// //           .status(500)
// //           .json({ success: false, message: "Internal server error" });
// //       if (result.affectedRows === 0)
// //         return res.status(400).json({
// //           success: false,
// //           message: "Only leaves pending TL review can be cancelled",
// //         });
// //       res.json({ success: true, message: "Leave cancelled successfully" });
// //     },
// //   );
// // });

// // app.get("/admin/pending-requests", (req, res) => {
// //   db.query(
// //     `SELECT
// //         p.request_id,
// //         p.emp_id,

// //         COALESCE(p.first_name, e.first_name) AS first_name,
// //         COALESCE(p.mid_name, e.mid_name) AS mid_name,
// //         COALESCE(p.last_name, e.last_name) AS last_name,
// //         COALESCE(p.email_id, e.email_id) AS email_id,
// //         COALESCE(p.phone_number, e.phone_number) AS phone_number,
// //         COALESCE(p.date_of_birth, e.date_of_birth) AS date_of_birth,
// //         COALESCE(p.gender, e.gender) AS gender,
// //         COALESCE(p.department_id, e.department_id) AS department_id,
// //         COALESCE(p.role_id, e.role_id) AS role_id,
// //         COALESCE(p.date_of_joining, e.date_of_joining) AS date_of_joining,
// //         COALESCE(p.date_of_relieving, e.date_of_relieving) AS date_of_relieving,
// //         COALESCE(p.employment_type, e.employment_type) AS employment_type,
// //         COALESCE(p.work_type, e.work_type) AS work_type,
// //         COALESCE(p.permanent_address, e.permanent_address) AS permanent_address,
// //         COALESCE(p.communication_address, e.communication_address) AS communication_address,
// //         COALESCE(p.aadhar_number, e.aadhar_number) AS aadhar_number,
// //         COALESCE(p.pan_number, e.pan_number) AS pan_number,
// //         COALESCE(p.passport_number, e.passport_number) AS passport_number,
// //         COALESCE(p.father_name, e.father_name) AS father_name,
// //         COALESCE(p.emergency_contact, e.emergency_contact) AS emergency_contact,
// //         COALESCE(p.pf_number, e.pf_number) AS pf_number,
// //         COALESCE(p.esic_number, e.esic_number) AS esic_number,
// //         COALESCE(p.years_experience, e.years_experience) AS years_experience,

// //         (
// //           SELECT JSON_ARRAYAGG(
// //             JSON_OBJECT(
// //               'education_level', x.education_level,
// //               'stream', x.stream,
// //               'score', x.score,
// //               'year_of_passout', x.year_of_passout,
// //               'university', x.university,
// //               'college_name', x.college_name
// //             )
// //           )
// //           FROM (
// //             SELECT
// //               ep.education_level, ep.stream, ep.score,
// //               ep.year_of_passout, ep.university, ep.college_name
// //             FROM education_pending_request ep
// //             WHERE ep.request_id = p.request_id

// //             UNION ALL

// //             SELECT
// //               ed.education_level, ed.stream, ed.score,
// //               ed.year_of_passout, ed.university, ed.college_name
// //             FROM education_details ed
// //             WHERE ed.emp_id = p.emp_id
// //               AND NOT EXISTS (
// //                 SELECT 1
// //                 FROM education_pending_request ep2
// //                 WHERE ep2.request_id = p.request_id
// //                   AND ep2.education_level = ed.education_level
// //               )
// //           ) x
// //         ) AS education_list,

// //         p.admin_approve,
// //         p.username,
// //         p.password,
// //         p.request_type,
// //         p.edit_reason,
// //         p.reject_reason,
// //         p.created_at,
// //         p.updated_at,

// //         d.department_name,
// //         r.role_name

// //     FROM employee_pending_request p
// //     LEFT JOIN employee_master e ON p.emp_id = e.emp_id
// //     LEFT JOIN department_master d ON COALESCE(p.department_id, e.department_id) = d.department_id
// //     LEFT JOIN role_master r ON COALESCE(p.role_id, e.role_id) = r.role_id
// //     WHERE p.admin_approve = 'PENDING'
// //     ORDER BY p.created_at DESC`,
// //     (err, results) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json(results);
// //     },
// //   );
// // });

// // app.get("/admin/request/:request_id", (req, res) => {
// //   db.query(
// //     `SELECT p.*, d.department_name, r.role_name
// //     FROM employee_pending_request p
// //     LEFT JOIN department_master d ON p.department_id = d.department_id
// //     LEFT JOIN role_master r ON p.role_id = r.role_id
// //     WHERE p.request_id = ?`,
// //     [req.params.request_id],
// //     (err, results) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       if (results.length === 0)
// //         return res.status(404).json({ error: "Request not found" });
// //       res.json(results[0]);
// //     },
// //   );
// // });

// // // ─── APPROVE REQUEST ─────────────────────────────────────────────────────────
// // app.post("/admin/approve-request", (req, res) => {
// //   const { request_id } = req.body;
// //   if (!request_id)
// //     return res.status(400).json({ error: "request_id is required" });

// //   db.query(
// //     "SELECT * FROM employee_pending_request WHERE request_id=?",
// //     [request_id],
// //     (err, results) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       if (results.length === 0)
// //         return res.status(404).json({ error: "Request not found" });

// //       const request = results[0];

// //       if (request.request_type === "NEW") {
// //         const empData = {
// //           first_name: request.first_name,
// //           mid_name: request.mid_name || null,
// //           last_name: request.last_name,
// //           email_id: request.email_id,
// //           phone_number: request.phone_number,
// //           date_of_birth: request.date_of_birth,
// //           gender: request.gender,
// //           department_id: request.department_id,
// //           role_id: request.role_id,
// //           date_of_joining: request.date_of_joining,
// //           date_of_relieving: request.date_of_relieving || null,
// //           employment_type: request.employment_type,
// //           work_type: request.work_type,
// //           permanent_address: request.permanent_address,
// //           communication_address: request.communication_address || null,
// //           aadhar_number: request.aadhar_number || null,
// //           pan_number: request.pan_number || null,
// //           passport_number: request.passport_number || null,
// //           father_name: request.father_name || null,
// //           emergency_contact: request.emergency_contact || null,
// //           pf_number: request.pf_number || null,
// //           esic_number: request.esic_number || null,
// //           years_experience:
// //             request.years_experience != null
// //               ? parseInt(request.years_experience)
// //               : null,
// //           status: "Active",
// //         };

// //         db.query(
// //           "INSERT INTO employee_master SET ?",
// //           empData,
// //           (err, empResult) => {
// //             if (err) {
// //               console.error("Insert Employee Error:", err);
// //               return res
// //                 .status(500)
// //                 .json({ error: "Failed to create employee: " + err.message });
// //             }

// //             const empId = empResult.insertId;

// //             db.query(
// //               `INSERT INTO education_details
// //              (emp_id, education_level, stream, score, year_of_passout, university, college_name)
// //              SELECT ?, education_level, stream, score, year_of_passout, university, college_name
// //              FROM education_pending_request
// //              WHERE request_id = ?`,
// //               [empId, request_id],
// //               (eduErr) => {
// //                 if (eduErr)
// //                   return res
// //                     .status(500)
// //                     .json({ error: "Failed to copy education data" });

// //                 const loginData = {
// //                   emp_id: empId,
// //                   username: request.username,
// //                   password: request.password,
// //                   role_id: request.role_id,
// //                   status: "Active",
// //                 };

// //                 db.query("INSERT INTO login_master SET ?", loginData, (err) => {
// //                   if (err)
// //                     return res.status(500).json({
// //                       error: "Failed to create login: " + err.message,
// //                     });

// //                   db.query(
// //                     "UPDATE employee_pending_request SET admin_approve='APPROVED', emp_id=? WHERE request_id=?",
// //                     [empId, request_id],
// //                     (err) => {
// //                       if (err)
// //                         return res.status(500).json({ error: err.message });

// //                       db.query(
// //                         "DELETE FROM education_pending_request WHERE request_id=?",
// //                         [request_id],
// //                       );

// //                       res.json({
// //                         message: "New employee approved successfully!",
// //                         emp_id: empId,
// //                       });
// //                     },
// //                   );
// //                 });
// //               },
// //             );
// //           },
// //         );
// //       } else if (request.request_type === "UPDATE") {
// //         if (!request.emp_id)
// //           return res
// //             .status(400)
// //             .json({ error: "emp_id missing for update request" });

// //         const dorValue =
// //           request.status === "Relieved"
// //             ? request.date_of_relieving || null
// //             : null;

// //         if (request.status === "Relieved" && !dorValue)
// //           return res.status(400).json({
// //             error: "Relieving date is required when status is Relieved",
// //           });

// //         const empUpdateData = {
// //           first_name: request.first_name,
// //           mid_name: request.mid_name || null,
// //           last_name: request.last_name,
// //           email_id: request.email_id,
// //           phone_number: request.phone_number,
// //           date_of_birth: request.date_of_birth,
// //           gender: request.gender,
// //           department_id: request.department_id,
// //           role_id: request.role_id,
// //           date_of_joining: request.date_of_joining,
// //           date_of_relieving: dorValue,
// //           employment_type: request.employment_type,
// //           work_type: request.work_type,
// //           permanent_address: request.permanent_address,
// //           communication_address: request.communication_address || null,
// //           aadhar_number: request.aadhar_number || null,
// //           pan_number: request.pan_number || null,
// //           passport_number: request.passport_number || null,
// //           father_name: request.father_name || null,
// //           emergency_contact: request.emergency_contact || null,
// //           pf_number: request.pf_number || null,
// //           esic_number: request.esic_number || null,
// //           years_experience:
// //             request.years_experience != null
// //               ? parseInt(request.years_experience)
// //               : null,
// //           status: request.status || "Active",
// //         };

// //         db.query(
// //           "UPDATE employee_master SET ? WHERE emp_id=?",
// //           [empUpdateData, request.emp_id],
// //           (err, result) => {
// //             if (err)
// //               return res
// //                 .status(500)
// //                 .json({ error: "Failed to update employee: " + err.message });

// //             if (result.affectedRows === 0)
// //               return res.status(404).json({ error: "Employee not found" });

// //             db.query(
// //               "UPDATE login_master SET role_id=?, status=? WHERE emp_id=?",
// //               [request.role_id, request.status || "Active", request.emp_id],
// //               (loginErr) => {
// //                 if (loginErr)
// //                   return res.status(500).json({
// //                     error: "Failed to update login role: " + loginErr.message,
// //                   });

// //                 db.query(
// //                   "DELETE FROM education_details WHERE emp_id=?",
// //                   [request.emp_id],
// //                   (delErr) => {
// //                     if (delErr)
// //                       return res.status(500).json({ error: delErr.message });

// //                     db.query(
// //                       `INSERT INTO education_details
// //                        (emp_id, education_level, stream, score, year_of_passout, university, college_name)
// //                        SELECT ?, education_level, stream, score, year_of_passout, university, college_name
// //                        FROM education_pending_request
// //                        WHERE request_id = ?`,
// //                       [request.emp_id, request_id],
// //                       (eduErr) => {
// //                         if (eduErr)
// //                           return res
// //                             .status(500)
// //                             .json({ error: eduErr.message });

// //                         db.query(
// //                           "UPDATE employee_pending_request SET admin_approve='APPROVED' WHERE request_id=?",
// //                           [request_id],
// //                           (err) => {
// //                             if (err)
// //                               return res
// //                                 .status(500)
// //                                 .json({ error: err.message });

// //                             db.query(
// //                               "DELETE FROM education_pending_request WHERE request_id=?",
// //                               [request_id],
// //                             );

// //                             res.json({
// //                               message: "Employee update approved successfully!",
// //                             });
// //                           },
// //                         );
// //                       },
// //                     );
// //                   },
// //                 );
// //               },
// //             );
// //           },
// //         );
// //       } else {
// //         res
// //           .status(400)
// //           .json({ error: "Unknown request type: " + request.request_type });
// //       }
// //     },
// //   );
// // });

// // app.post("/admin/reject-request", (req, res) => {
// //   const { request_id, reject_reason } = req.body;
// //   if (!request_id || !reject_reason)
// //     return res
// //       .status(400)
// //       .json({ error: "Request ID and reject reason are required" });
// //   db.query(
// //     "SELECT * FROM employee_pending_request WHERE request_id=?",
// //     [request_id],
// //     (err, results) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       if (results.length === 0)
// //         return res.status(404).json({ error: "Request not found" });
// //       db.query(
// //         "UPDATE employee_pending_request SET admin_approve='REJECTED', reject_reason=? WHERE request_id=?",
// //         [reject_reason, request_id],
// //         (err) => {
// //           if (err) return res.status(500).json({ error: err.message });
// //           res.json({ message: "Request rejected successfully!" });
// //         },
// //       );
// //     },
// //   );
// // });

// // app.get("/dashboard", (req, res) => {
// //   const today = new Date().toISOString().split("T")[0];
// //   Promise.all([
// //     new Promise((resolve, reject) =>
// //       db.query(
// //         `SELECT COUNT(*) AS v FROM employee_master WHERE status='Active'`,
// //         (e, r) => (e ? reject(e) : resolve(r[0].v)),
// //       ),
// //     ),
// //     new Promise((resolve, reject) =>
// //       db.query(
// //         `SELECT COUNT(DISTINCT employee_id) AS v FROM employee_site_attendance WHERE work_date='${today}'`,
// //         (e, r) => (e ? reject(e) : resolve(r[0].v)),
// //       ),
// //     ),
// //     new Promise((resolve, reject) =>
// //       db.query(
// //         `SELECT COUNT(DISTINCT employee_id) AS v FROM employee_site_attendance WHERE work_date='${today}'`,
// //         (e, r) => (e ? reject(e) : resolve(r[0].v)),
// //       ),
// //     ),
// //     new Promise((resolve, reject) =>
// //       db.query(
// //         `SELECT COUNT(DISTINCT emp_id) AS v FROM employee_location_assignment
// //                WHERE start_date <= '${today}' AND end_date >= '${today}' AND status IN ('Active','Extended')`,
// //         (e, r) => (e ? reject(e) : resolve(r[0].v)),
// //       ),
// //     ),
// //     new Promise((resolve, reject) =>
// //       db.query(
// //         `SELECT COUNT(*) AS v FROM employee_pending_request WHERE admin_approve='PENDING'`,
// //         (e, r) => (e ? reject(e) : resolve(r[0].v)),
// //       ),
// //     ),
// //     new Promise((resolve, reject) =>
// //       db.query(
// //         `SELECT COUNT(*) AS v FROM leave_master WHERE status='Pending' AND leave_start_date>='${today}'`,
// //         (e, r) => (e ? reject(e) : resolve(r[0].v)),
// //       ),
// //     ),
// //     new Promise((resolve, reject) =>
// //       db.query(
// //         `SELECT COUNT(*) AS v FROM employee_master e
// //                LEFT JOIN employee_site_attendance a ON e.emp_id = a.employee_id AND a.work_date='${today}'
// //                WHERE e.status='Active' AND a.id IS NULL`,
// //         (e, r) => (e ? reject(e) : resolve(r[0].v)),
// //       ),
// //     ),
// //   ])
// //     .then(
// //       ([
// //         totalEmployees,
// //         present,
// //         lateEntry,
// //         onSiteToday,
// //         pendingEmpReq,
// //         pendingLeaveReq,
// //         absent,
// //       ]) => {
// //         res.json({
// //           totalEmployees,
// //           present,
// //           absent,
// //           lateEntry,
// //           onSiteToday,
// //           pendingRequests: pendingEmpReq + pendingLeaveReq,
// //         });
// //       },
// //     )
// //     .catch((err) => res.status(500).json({ error: err.message || err }));
// // });

// // app.get("/leaves/pending", (req, res) => {
// //   db.query(
// //     `SELECT
// //         l.leave_id,
// //         l.emp_id,
// //         l.recommended_by,
// //         l.recommended_at,
// //         l.leave_type,
// //         DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS leave_start_date,
// //         DATE_FORMAT(l.leave_end_date,   '%Y-%m-%d') AS leave_end_date,
// //         l.number_of_days,
// //         l.approved_by,
// //         l.status,
// //         l.reason,
// //         l.cancel_reason,
// //         l.rejection_reason,
// //         l.created_at,
// //         l.updated_at
// //      FROM leave_master l
// //      WHERE l.status IN ('Pending_TL','Pending_HR')`,
// //     (err, results) => {
// //       if (err) return res.status(500).send(err);
// //       res.json(results);
// //     },
// //   );
// // });

// // app.put("/leaves/:id", (req, res) => {
// //   const { status, rejectionReason } = req.body;
// //   db.query(
// //     "UPDATE leave_master SET status=?, rejection_reason=? WHERE leave_id=?",
// //     [status, rejectionReason || null, req.params.id],
// //     (err) => {
// //       if (err) return res.status(500).send(err);
// //       res.sendStatus(200);
// //     },
// //   );
// // });

// // app.get("/leaves/pending/details", (req, res) => {
// //   const query = `
// //     SELECT l.leave_id, l.emp_id, CONCAT(e.first_name,' ',e.last_name) AS employee_name,
// //       d.department_name, r.role_name, l.leave_type, l.leave_start_date, l.leave_end_date,
// //       l.number_of_days, l.reason,
// //       IFNULL(SUM(CASE WHEN lm.status='Approved' THEN lm.number_of_days END),0) AS taken_days,
// //       CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
// //            WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
// //            WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END AS total_allowed,
// //       (CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
// //             WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
// //             WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END
// //        - IFNULL(SUM(CASE WHEN lm.status='Approved' THEN lm.number_of_days END),0)) AS remaining_days
// //     FROM leave_master l
// //     JOIN employee_master e ON l.emp_id=e.emp_id
// //     LEFT JOIN department_master d ON e.department_id=d.department_id
// //     LEFT JOIN role_master r ON e.role_id=r.role_id
// //     LEFT JOIN leave_master lm ON lm.emp_id=l.emp_id AND lm.leave_type=l.leave_type AND lm.status='Approved'
// //     WHERE l.status IN ('Pending_TL','Pending_HR')
// //     GROUP BY l.leave_id`;
// //   db.query(query, (err, results) => {
// //     if (err) return res.status(500).json({ success: false });
// //     res.json({ success: true, data: results });
// //   });
// // });

// // app.put("/leave/:leaveId/status", (req, res) => {
// //   const { status, rejection_reason, login_id } = req.body;
// //   if (!status || !login_id)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "status and login_id are required" });
// //   db.query(
// //     "SELECT role FROM login_master WHERE login_id=? AND status='Active'",
// //     [login_id],
// //     (err, roleResult) => {
// //       if (err) return res.status(500).json({ success: false });
// //       if (roleResult.length === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Invalid login user" });
// //       const approvedBy = roleResult[0].role;
// //       if (approvedBy === "Employee")
// //         return res
// //           .status(403)
// //           .json({ success: false, message: "Employees cannot approve leave" });
// //       db.query(
// //         "UPDATE leave_master SET status=?, approved_by=?, rejection_reason=?, updated_at=NOW() WHERE leave_id=?",
// //         [status, approvedBy, rejection_reason || null, req.params.leaveId],
// //         (err2) => {
// //           if (err2) return res.status(500).json({ success: false });
// //           res.json({
// //             success: true,
// //             message: "Leave updated successfully",
// //             approved_by: approvedBy,
// //           });
// //         },
// //       );
// //     },
// //   );
// // });

// // app.get("/leave-status-summary", (req, res) => {
// //   db.query(
// //     "SELECT status, COUNT(*) AS count FROM leave_master WHERE status!='Cancelled' GROUP BY status",
// //     (err, results) => {
// //       if (err) return res.status(500).json({ error: "Database error" });
// //       res.json(
// //         results.map((row) => ({ status: row.status, count: row.count })),
// //       );
// //     },
// //   );
// // });

// // app.get("/departments", (req, res) => {
// //   db.query(
// //     "SELECT department_id AS id, department_name AS name FROM department_master WHERE status='Active'",
// //     (err, result) => {
// //       if (err)
// //         return res
// //           .status(500)
// //           .json({ success: false, message: "Failed to fetch departments" });
// //       res.json({ success: true, data: result });
// //     },
// //   );
// // });

// // app.post("/departments", (req, res) => {
// //   const { department_name } = req.body;
// //   if (!department_name)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Department name is required" });
// //   db.query(
// //     "INSERT INTO department_master (department_name, status, created_at, updated_at) VALUES (?, 'Active', NOW(), NOW())",
// //     [department_name],
// //     (err, result) => {
// //       if (err) {
// //         if (err.code === "ER_DUP_ENTRY")
// //           return res.status(400).json({
// //             success: false,
// //             message: "Department name already exists",
// //           });
// //         return res.status(500).json({ success: false, message: err.message });
// //       }
// //       res.json({
// //         success: true,
// //         message: "Department added successfully",
// //         department_id: result.insertId,
// //       });
// //     },
// //   );
// // });

// // app.put("/departments/:id/status", (req, res) => {
// //   const { status } = req.body;
// //   if (!status || !["Active", "Inactive"].includes(status))
// //     return res.status(400).json({ success: false, message: "Invalid status" });
// //   db.query(
// //     "UPDATE department_master SET status=?, updated_at=NOW() WHERE department_id=?",
// //     [status, parseInt(req.params.id)],
// //     (err) => {
// //       if (err)
// //         return res.status(500).json({ success: false, message: err.message });
// //       res.json({
// //         success: true,
// //         message: `Department ${status.toLowerCase()} successfully`,
// //       });
// //     },
// //   );
// // });

// // app.get("/departments/:id/employees", (req, res) => {
// //   db.query(
// //     "SELECT emp_id, first_name, email_id, department_id FROM employee_master WHERE department_id=?",
// //     [parseInt(req.params.id)],
// //     (err, results) => {
// //       if (err)
// //         return res.status(500).json({ success: false, message: err.message });
// //       res.json(results);
// //     },
// //   );
// // });

// // app.put("/departments/:id/transfer-employee", (req, res) => {
// //   const toDeptId = parseInt(req.params.id);
// //   const { emp_id, reason } = req.body;
// //   if (!emp_id)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Employee ID required" });
// //   db.query(
// //     "SELECT department_id FROM employee_master WHERE emp_id=?",
// //     [emp_id],
// //     (err, result) => {
// //       if (err)
// //         return res.status(500).json({ success: false, message: err.message });
// //       if (result.length === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Employee not found" });
// //       const fromDeptId = result[0].department_id;
// //       db.query(
// //         "UPDATE employee_master SET department_id=?, updated_at=NOW() WHERE emp_id=?",
// //         [toDeptId, emp_id],
// //         (err2) => {
// //           if (err2)
// //             return res
// //               .status(500)
// //               .json({ success: false, message: err2.message });
// //           db.query(
// //             "INSERT INTO employee_transfer_log (emp_id, from_department_id, to_department_id, reason) VALUES (?,?,?,?)",
// //             [emp_id, fromDeptId, toDeptId, reason || "Transferred"],
// //             (err3) => {
// //               if (err3) console.error("Transfer log error:", err3);
// //               res.json({
// //                 success: true,
// //                 message: "Employee transferred successfully",
// //               });
// //             },
// //           );
// //         },
// //       );
// //     },
// //   );
// // });

// // // ─── ALL EMPLOYEES ────────────────────────────────────────────────────────────
// // app.get("/all-employees", (req, res) => {
// //   const query = `
// //     SELECT * FROM (
// //       SELECT e.emp_id, e.first_name, e.mid_name, e.last_name, e.email_id AS email, e.phone_number AS phone,
// //         e.date_of_birth, e.gender, e.department_id, d.department_name, e.role_id, r.role_name,
// //         e.date_of_joining, e.date_of_relieving, e.employment_type, e.work_type,
// //         e.permanent_address, e.communication_address, e.aadhar_number, e.pan_number, e.passport_number,
// //         e.father_name, e.emergency_contact, e.pf_number, e.esic_number, e.years_experience,
// //         e.status AS emp_status, NULL AS admin_approve, NULL AS request_id, 'MASTER' AS source,
// //         e.created_at, e.updated_at
// //       FROM employee_master e
// //       LEFT JOIN department_master d ON e.department_id=d.department_id
// //       LEFT JOIN role_master r ON e.role_id=r.role_id
// //       UNION ALL
// //       SELECT p.emp_id, p.first_name, p.mid_name, p.last_name, p.email_id AS email, p.phone_number AS phone,
// //         p.date_of_birth, p.gender, p.department_id, d2.department_name, p.role_id, r2.role_name,
// //         p.date_of_joining, p.date_of_relieving, p.employment_type, p.work_type,
// //         p.permanent_address, p.communication_address, p.aadhar_number, p.pan_number, p.passport_number,
// //         p.father_name, p.emergency_contact, p.pf_number, p.esic_number, p.years_experience,
// //         NULL AS emp_status, p.admin_approve, p.request_id, 'PENDING' AS source,
// //         p.created_at, p.updated_at
// //       FROM employee_pending_request p
// //       LEFT JOIN department_master d2 ON p.department_id=d2.department_id
// //       LEFT JOIN role_master r2 ON p.role_id=r2.role_id
// //       WHERE p.admin_approve IN ('PENDING','REJECTED')
// //     ) AS combined ORDER BY created_at DESC`;
// //   db.query(query, (err, results) => {
// //     if (err)
// //       return res.status(500).json({
// //         success: false,
// //         message: "Failed to fetch employees",
// //         error: err.message,
// //       });
// //     res.json({ success: true, data: results });
// //   });
// // });

// // // ─── NEW EMPLOYEE PENDING REQUEST ─────────────────────────────────────────────
// // app.post("/employee-pending-request", (req, res) => {
// //   const {
// //     first_name,
// //     mid_name,
// //     last_name,
// //     email_id,
// //     phone_number,
// //     date_of_birth,
// //     gender,
// //     department_id,
// //     role_id,
// //     date_of_joining,
// //     employment_type,
// //     work_type,
// //     permanent_address,
// //     communication_address,
// //     aadhar_number,
// //     pan_number,
// //     passport_number,
// //     father_name,
// //     emergency_contact,
// //     pf_number,
// //     esic_number,
// //     years_experience,
// //     username,
// //     password,
// //     education,
// //   } = req.body;

// //   if (
// //     !first_name ||
// //     !last_name ||
// //     !email_id ||
// //     !phone_number ||
// //     !date_of_birth ||
// //     !gender ||
// //     !department_id ||
// //     !role_id ||
// //     !date_of_joining ||
// //     !employment_type ||
// //     !work_type ||
// //     !permanent_address ||
// //     !username ||
// //     !password
// //   )
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Missing required fields" });

// //   if (!["Male", "Female", "Other"].includes(gender))
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Invalid gender value" });
// //   if (!["Permanent", "Contract", "Intern"].includes(employment_type))
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Invalid employment_type value" });
// //   if (!["Full Time", "Part Time"].includes(work_type))
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Invalid work_type value" });

// //   const safe = (v) => (v && v.toString().trim() !== "" ? v : null);

// //   db.query(
// //     `INSERT INTO employee_pending_request
// //     (first_name, mid_name, last_name, email_id, phone_number, date_of_birth, gender,
// //      department_id, role_id, date_of_joining, employment_type, work_type,
// //      permanent_address, communication_address, aadhar_number, pan_number, passport_number,
// //      father_name, emergency_contact, pf_number, esic_number, years_experience,
// //      admin_approve, username, password, request_type, created_at, updated_at)
// //     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'PENDING',?,?,'NEW',NOW(),NOW())`,
// //     [
// //       first_name,
// //       safe(mid_name),
// //       last_name,
// //       email_id,
// //       phone_number,
// //       date_of_birth,
// //       gender,
// //       department_id,
// //       role_id,
// //       date_of_joining,
// //       employment_type,
// //       work_type,
// //       permanent_address,
// //       safe(communication_address),
// //       safe(aadhar_number),
// //       safe(pan_number),
// //       safe(passport_number),
// //       safe(father_name),
// //       safe(emergency_contact),
// //       safe(pf_number),
// //       safe(esic_number),
// //       years_experience ? parseInt(years_experience) : null,
// //       username,
// //       password,
// //     ],
// //     (err, result) => {
// //       if (err)
// //         return res.status(500).json({
// //           success: false,
// //           message: "Failed to submit employee request",
// //           error: err.message,
// //         });

// //       const requestId = result.insertId;

// //       if (education && Array.isArray(education) && education.length > 0) {
// //         const eduValues = education.map((e) => [
// //           requestId,
// //           e.education_level,
// //           e.stream || null,
// //           e.score ? parseFloat(e.score) : null,
// //           e.year_of_passout || null,
// //           e.university || null,
// //           e.college_name || null,
// //         ]);
// //         db.query(
// //           `INSERT INTO education_pending_request
// //            (request_id, education_level, stream, score, year_of_passout, university, college_name)
// //            VALUES ?`,
// //           [eduValues],
// //           (eduErr) => {
// //             if (eduErr)
// //               console.error("Education pending insert error:", eduErr);
// //           },
// //         );
// //       }

// //       res.json({
// //         success: true,
// //         message: "Employee request submitted successfully",
// //         request_id: requestId,
// //       });
// //     },
// //   );
// // });

// // // ─── EDIT REQUEST ─────────────────────────────────────────────────────────────
// // app.post("/employee-edit-request", (req, res) => {
// //   const {
// //     emp_id,
// //     first_name,
// //     mid_name,
// //     last_name,
// //     email_id,
// //     phone_number,
// //     date_of_birth,
// //     gender,
// //     department_id = 0,
// //     role_id = 0,
// //     date_of_joining,
// //     date_of_relieving,
// //     employment_type,
// //     work_type,
// //     permanent_address,
// //     communication_address,
// //     aadhar_number = null,
// //     pan_number = null,
// //     passport_number = null,
// //     father_name = null,
// //     emergency_contact = null,
// //     pf_number = null,
// //     esic_number = null,
// //     years_experience = null,
// //     admin_approve = "PENDING",
// //     username = "-",
// //     password = "-",
// //     request_type = "UPDATE",
// //     edit_reason,
// //     status,
// //     education,
// //   } = req.body;

// //   const emptyToNull = (v) => (v && v.toString().trim() !== "" ? v : null);

// //   if (
// //     status === "Relieved" &&
// //     (!date_of_relieving || date_of_relieving.trim() === "")
// //   )
// //     return res.status(400).json({
// //       success: false,
// //       message: "Date of Relieving is required when status is Relieved",
// //     });

// //   const dorValue =
// //     status === "Relieved" ? emptyToNull(date_of_relieving) : null;

// //   function saveEducationToPending(requestId, educationList, callback) {
// //     if (
// //       !educationList ||
// //       !Array.isArray(educationList) ||
// //       educationList.length === 0
// //     ) {
// //       db.query(
// //         "DELETE FROM education_pending_request WHERE request_id = ?",
// //         [requestId],
// //         (delErr) => {
// //           if (delErr) console.error("Education delete error:", delErr);
// //           callback(null);
// //         },
// //       );
// //       return;
// //     }
// //     db.query(
// //       "DELETE FROM education_pending_request WHERE request_id = ?",
// //       [requestId],
// //       (delErr) => {
// //         if (delErr) console.error("Education delete error:", delErr);
// //         const eduValues = educationList.map((e) => [
// //           requestId,
// //           e.education_level,
// //           e.stream || null,
// //           e.score ? parseFloat(e.score) : null,
// //           e.year_of_passout || null,
// //           e.university || null,
// //           e.college_name || null,
// //         ]);
// //         db.query(
// //           `INSERT INTO education_pending_request
// //            (request_id, education_level, stream, score, year_of_passout, university, college_name)
// //            VALUES ?`,
// //           [eduValues],
// //           (eduErr) => {
// //             if (eduErr)
// //               console.error("Education pending insert error:", eduErr);
// //             callback(eduErr);
// //           },
// //         );
// //       },
// //     );
// //   }

// //   db.query(
// //     "SELECT * FROM employee_pending_request WHERE emp_id=? AND admin_approve='PENDING'",
// //     [emp_id],
// //     (err, results) => {
// //       if (err)
// //         return res.status(500).json({ success: false, message: err.message });

// //       if (results.length > 0) {
// //         db.query(
// //           `UPDATE employee_pending_request SET
// //             first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?,
// //             date_of_birth=?, gender=?, date_of_joining=?, date_of_relieving=?,
// //             employment_type=?, work_type=?, permanent_address=?, communication_address=?,
// //             department_id=?, role_id=?,
// //             father_name=?, emergency_contact=?, pf_number=?, esic_number=?, years_experience=?,
// //             status=?, edit_reason=?, updated_at=CURRENT_TIMESTAMP
// //           WHERE emp_id=? AND admin_approve='PENDING'`,
// //           [
// //             first_name,
// //             mid_name,
// //             last_name,
// //             email_id,
// //             phone_number,
// //             date_of_birth,
// //             gender,
// //             date_of_joining,
// //             dorValue,
// //             employment_type,
// //             work_type,
// //             permanent_address,
// //             communication_address,
// //             department_id,
// //             role_id,
// //             emptyToNull(father_name),
// //             emptyToNull(emergency_contact),
// //             emptyToNull(pf_number),
// //             emptyToNull(esic_number),
// //             years_experience ? parseInt(years_experience) : null,
// //             status || "Active",
// //             edit_reason,
// //             emp_id,
// //           ],
// //           (err) => {
// //             if (err)
// //               return res
// //                 .status(500)
// //                 .json({ success: false, message: err.message });
// //             db.query(
// //               "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND admin_approve='PENDING' LIMIT 1",
// //               [emp_id],
// //               (err2, rows2) => {
// //                 if (err2)
// //                   return res
// //                     .status(500)
// //                     .json({ success: false, message: err2.message });
// //                 const requestId =
// //                   rows2 && rows2.length > 0 ? rows2[0].request_id : null;
// //                 if (!requestId)
// //                   return res.json({
// //                     success: true,
// //                     message: "Pending request updated!",
// //                     request_id: null,
// //                   });
// //                 saveEducationToPending(requestId, education, () => {
// //                   res.json({
// //                     success: true,
// //                     message: "Pending request updated!",
// //                     request_id: requestId,
// //                   });
// //                 });
// //               },
// //             );
// //           },
// //         );
// //       } else {
// //         db.query(
// //           `INSERT INTO employee_pending_request
// //             (emp_id, first_name, mid_name, last_name, email_id, phone_number, date_of_birth, gender,
// //              department_id, role_id, date_of_joining, date_of_relieving, employment_type, work_type,
// //              permanent_address, communication_address, aadhar_number, pan_number, passport_number,
// //              father_name, emergency_contact, pf_number, esic_number, years_experience,
// //              status, admin_approve, username, password, request_type, edit_reason)
// //           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
// //           [
// //             emp_id,
// //             first_name,
// //             mid_name,
// //             last_name,
// //             email_id,
// //             phone_number,
// //             date_of_birth,
// //             gender,
// //             department_id,
// //             role_id,
// //             date_of_joining,
// //             dorValue,
// //             employment_type,
// //             work_type,
// //             permanent_address,
// //             communication_address,
// //             aadhar_number,
// //             pan_number,
// //             passport_number,
// //             emptyToNull(father_name),
// //             emptyToNull(emergency_contact),
// //             emptyToNull(pf_number),
// //             emptyToNull(esic_number),
// //             years_experience ? parseInt(years_experience) : null,
// //             status || "Active",
// //             admin_approve,
// //             username,
// //             password,
// //             request_type,
// //             edit_reason,
// //           ],
// //           (err, result) => {
// //             if (err)
// //               return res
// //                 .status(500)
// //                 .json({ success: false, message: err.message });
// //             const requestId = result.insertId;
// //             saveEducationToPending(requestId, education, () => {
// //               res.json({
// //                 success: true,
// //                 message: "Pending request submitted!",
// //                 request_id: requestId,
// //               });
// //             });
// //           },
// //         );
// //       }
// //     },
// //   );
// // });

// // // ─── RESUBMIT REJECTED REQUEST ────────────────────────────────────────────────
// // app.put("/admin/resubmit-request/:request_id", (req, res) => {
// //   const {
// //     first_name,
// //     mid_name,
// //     last_name,
// //     email_id,
// //     phone_number,
// //     date_of_birth,
// //     gender,
// //     department_id,
// //     role_id,
// //     date_of_joining,
// //     employment_type,
// //     work_type,
// //     permanent_address,
// //     communication_address,
// //     aadhar_number,
// //     pan_number,
// //     passport_number,
// //     father_name,
// //     emergency_contact,
// //     pf_number,
// //     esic_number,
// //     years_experience,
// //     username,
// //     education,
// //   } = req.body;

// //   db.query(
// //     `UPDATE employee_pending_request SET
// //       first_name=?, mid_name=?, last_name=?, email_id=?, phone_number=?,
// //       date_of_birth=?, gender=?, department_id=?, role_id=?, date_of_joining=?,
// //       employment_type=?, work_type=?, permanent_address=?, communication_address=?,
// //       aadhar_number=?, pan_number=?, passport_number=?,
// //       father_name=?, emergency_contact=?, pf_number=?, esic_number=?, years_experience=?,
// //       username=?, admin_approve='PENDING', reject_reason=NULL, updated_at=NOW()
// //     WHERE request_id=? AND admin_approve='REJECTED'`,
// //     [
// //       first_name,
// //       mid_name || null,
// //       last_name,
// //       email_id,
// //       phone_number,
// //       date_of_birth,
// //       gender,
// //       department_id,
// //       role_id,
// //       date_of_joining,
// //       employment_type,
// //       work_type,
// //       permanent_address,
// //       communication_address || null,
// //       aadhar_number || null,
// //       pan_number || null,
// //       passport_number || null,
// //       father_name || null,
// //       emergency_contact || null,
// //       pf_number || null,
// //       esic_number || null,
// //       years_experience ? parseInt(years_experience) : null,
// //       username,
// //       req.params.request_id,
// //     ],
// //     (err, result) => {
// //       if (err)
// //         return res.status(500).json({ success: false, message: err.message });
// //       if (result.affectedRows === 0)
// //         return res.status(404).json({
// //           success: false,
// //           message: "Request not found or not in REJECTED state",
// //         });

// //       db.query(
// //         "DELETE FROM education_pending_request WHERE request_id=?",
// //         [req.params.request_id],
// //         (delErr) => {
// //           if (delErr)
// //             console.error("Education delete error on resubmit:", delErr);
// //           if (education && Array.isArray(education) && education.length > 0) {
// //             const eduValues = education.map((e) => [
// //               req.params.request_id,
// //               e.education_level,
// //               e.stream || null,
// //               e.score ? parseFloat(e.score) : null,
// //               e.year_of_passout || null,
// //               e.university || null,
// //               e.college_name || null,
// //             ]);
// //             db.query(
// //               `INSERT INTO education_pending_request
// //                (request_id, education_level, stream, score, year_of_passout, university, college_name)
// //                VALUES ?`,
// //               [eduValues],
// //               (eduErr) => {
// //                 if (eduErr)
// //                   console.error("Education resubmit insert error:", eduErr);
// //               },
// //             );
// //           }
// //         },
// //       );

// //       res.json({ success: true, message: "Request resubmitted successfully" });
// //     },
// //   );
// // });

// // app.post("/assign-location-and-get-list", (req, res) => {
// //   const { emp_ids, location_id, about_work, start_date, end_date, assign_by } =
// //     req.body;
// //   if (!emp_ids || !Array.isArray(emp_ids) || emp_ids.length === 0)
// //     return res.status(400).json({ error: "emp_ids array is required" });
// //   if (!location_id || !about_work || !start_date || !end_date)
// //     return res.status(400).json({
// //       error: "location_id, about_work, start_date, and end_date are required",
// //     });

// //   const values = emp_ids.map((id) => [
// //     id,
// //     location_id,
// //     about_work,
// //     start_date,
// //     end_date,
// //     "Active",
// //     assign_by || "Admin",
// //   ]);
// //   db.query(
// //     `INSERT INTO employee_location_assignment (emp_id, location_id, about_work, start_date, end_date, status, done_by) VALUES ?`,
// //     [values],
// //     (err, result) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json({
// //         success: true,
// //         message: `Location assigned to ${emp_ids.length} employee(s) successfully`,
// //         assigned_count: result.affectedRows,
// //       });
// //     },
// //   );
// // });

// // app.get("/locations", (req, res) => {
// //   db.query(
// //     "SELECT location_id,latitude,longitude,start_date,end_date,contact_person_name,contact_person_number,location_nick_name FROM location_master ORDER BY created_at DESC",
// //     (err, results) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json(results);
// //     },
// //   );
// // });

// // app.post("/locations", (req, res) => {
// //   let {
// //     nick_name,
// //     latitude,
// //     longitude,
// //     start_date,
// //     end_date,
// //     contact_person_name,
// //     contact_person_number,
// //   } = req.body;
// //   if (!nick_name || !latitude || !longitude || !start_date)
// //     return res.status(400).json({
// //       error: "Nick name, latitude, longitude, and start date are required",
// //     });
// //   nick_name = nick_name.toString().trim();
// //   contact_person_name = contact_person_name
// //     ? contact_person_name.toString().trim()
// //     : null;
// //   contact_person_number = contact_person_number
// //     ? contact_person_number.toString().trim()
// //     : null;
// //   if (contact_person_number && !/^\d+$/.test(contact_person_number))
// //     return res
// //       .status(400)
// //       .json({ error: "Contact number must contain digits only" });
// //   latitude = parseFloat(latitude);
// //   longitude = parseFloat(longitude);
// //   if (isNaN(latitude) || latitude < -90 || latitude > 90)
// //     return res
// //       .status(400)
// //       .json({ error: "Latitude must be between -90 and 90" });
// //   if (isNaN(longitude) || longitude < -180 || longitude > 180)
// //     return res
// //       .status(400)
// //       .json({ error: "Longitude must be between -180 and 180" });
// //   db.query(
// //     "INSERT INTO location_master (location_nick_name,latitude,longitude,start_date,end_date,contact_person_name,contact_person_number) VALUES (?,?,?,?,?,?,?)",
// //     [
// //       nick_name,
// //       latitude,
// //       longitude,
// //       start_date,
// //       end_date || null,
// //       contact_person_name,
// //       contact_person_number,
// //     ],
// //     (err, result) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.status(201).json({
// //         message: "Location added successfully",
// //         location_id: result.insertId,
// //       });
// //     },
// //   );
// // });

// // app.get("/working-today-and-future", (req, res) => {
// //   db.query(
// //     `SELECT a.assign_id, e.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS emp_name,
// //       l.location_nick_name AS location_name,
// //       DATE_FORMAT(a.start_date, '%Y-%m-%d') AS start_date, DATE_FORMAT(a.end_date, '%Y-%m-%d') AS end_date,
// //       a.about_work, a.status, a.reason AS extend_reason, a.done_by,
// //       CASE WHEN a.status='Completed' THEN 'Completed' WHEN a.status='Relieved' THEN 'Relieved'
// //            WHEN a.status='Extended' THEN 'Extended' WHEN a.start_date > CURDATE() THEN 'Future'
// //            WHEN a.status='Active' AND a.end_date < CURDATE() THEN 'Not Completed' ELSE 'Working' END AS work_status
// //     FROM employee_location_assignment a
// //     JOIN employee_master e ON a.emp_id = e.emp_id
// //     JOIN location_master l ON a.location_id = l.location_id
// //     WHERE a.status IN ('Active', 'Extended') OR (a.status = 'Relieved' AND a.end_date >= CURDATE())
// //     ORDER BY a.start_date ASC`,
// //     (err, result) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json(result);
// //     },
// //   );
// // });

// // app.get("/employees-with-work", (req, res) => {
// //   db.query(
// //     `SELECT e.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS emp_name,
// //       l.location_nick_name AS location_name,
// //       DATE_FORMAT(a.start_date, '%Y-%m-%d') AS start_date, DATE_FORMAT(a.end_date, '%Y-%m-%d') AS end_date,
// //       a.about_work, a.status, a.reason AS extend_reason, a.done_by,
// //       CASE WHEN a.emp_id IS NULL THEN 'Not Assigned' WHEN a.status='Completed' THEN 'Completed'
// //            WHEN a.status='Relieved' THEN 'Relieved' WHEN a.status='Extended' THEN 'Extended'
// //            WHEN a.start_date > CURDATE() THEN 'Future'
// //            WHEN a.status='Active' AND a.end_date < CURDATE() THEN 'Not Completed' ELSE 'Working' END AS work_status
// //     FROM employee_master e
// //     LEFT JOIN employee_location_assignment a ON e.emp_id = a.emp_id
// //       AND a.assign_id = (SELECT assign_id FROM employee_location_assignment WHERE emp_id = e.emp_id ORDER BY end_date DESC LIMIT 1)
// //     LEFT JOIN location_master l ON a.location_id = l.location_id
// //     ORDER BY e.emp_id ASC`,
// //     (err, result) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json(result);
// //     },
// //   );
// // });

// // app.get("/employee-location/:empId", (req, res) => {
// //   db.query(
// //     `SELECT ela.about_work,
// //       CONVERT_TZ(ela.start_date, '+00:00', '+05:30') AS start_date,
// //       CONVERT_TZ(ela.end_date,   '+00:00', '+05:30') AS end_date,
// //       ela.status, ela.reason AS extend_reason, ela.done_by, lm.location_nick_name,
// //       CASE WHEN ela.status='Completed' THEN 'Completed' WHEN ela.status='Relieved' THEN 'Relieved'
// //            WHEN ela.status='Extended' THEN 'Extended'
// //            WHEN ela.status='Active' AND ela.end_date < CURDATE() THEN 'Not Completed' ELSE 'Working' END AS work_status
// //     FROM employee_location_assignment ela
// //     JOIN location_master lm ON ela.location_id = lm.location_id
// //     WHERE ela.emp_id = ? ORDER BY ela.end_date DESC LIMIT 1`,
// //     [req.params.empId],
// //     (err, result) => {
// //       if (err) return res.status(500).json({ error: "DB error" });
// //       if (result.length === 0) return res.json({ assigned: false });
// //       res.json({
// //         assigned: true,
// //         work: result[0].about_work,
// //         locationName: result[0].location_nick_name,
// //         status: result[0].status,
// //         workStatus: result[0].work_status,
// //         extendReason: result[0].extend_reason,
// //         doneBy: result[0].done_by,
// //         startDate: result[0].start_date,
// //         endDate: result[0].end_date,
// //       });
// //     },
// //   );
// // });

// // app.get("/employee-assignments/:empId", (req, res) => {
// //   const empId = parseInt(req.params.empId, 10);
// //   if (isNaN(empId))
// //     return res.status(400).json({ error: "empId must be a number" });
// //   db.query(
// //     `SELECT ela.assign_id, ela.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS emp_name,
// //       lm.location_nick_name AS location_name,
// //       DATE(CONVERT_TZ(ela.start_date, '+00:00', '+05:30')) AS start_date,
// //       DATE(CONVERT_TZ(ela.end_date,   '+00:00', '+05:30')) AS end_date,
// //       ela.about_work, ela.status, ela.reason AS extend_reason, ela.done_by,
// //       CASE WHEN ela.status='Completed' THEN 'Completed' WHEN ela.status='Relieved' THEN 'Relieved'
// //            WHEN ela.status='Extended' THEN 'Extended'
// //            WHEN DATE(CONVERT_TZ(ela.start_date, '+00:00', '+05:30')) > CURDATE() THEN 'Future'
// //            WHEN ela.status='Active' AND DATE(CONVERT_TZ(ela.end_date, '+00:00', '+05:30')) < CURDATE() THEN 'Not Completed'
// //            ELSE 'Working' END AS work_status
// //     FROM employee_location_assignment ela
// //     JOIN employee_master e  ON ela.emp_id      = e.emp_id
// //     JOIN location_master lm ON ela.location_id = lm.location_id
// //     WHERE ela.emp_id = ? ORDER BY ela.start_date DESC`,
// //     [empId],
// //     (err, results) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json(results);
// //     },
// //   );
// // });

// // app.post("/update-work-status", (req, res) => {
// //   const { empId, status, updatedBy, reason, endDate } = req.body;
// //   if (!empId || !status)
// //     return res.status(400).json({ error: "empId and status are required" });
// //   const allowedStatuses = ["Completed", "Relieved", "Extended", "Active"];
// //   if (!allowedStatuses.includes(status))
// //     return res.status(400).json({ error: `Invalid status: ${status}` });

// //   let query = `UPDATE employee_location_assignment SET status=?, reason=?, done_by=?, updated_at=NOW()`;
// //   const params = [status, reason || null, updatedBy || null];
// //   if (status === "Extended") {
// //     if (!endDate)
// //       return res
// //         .status(400)
// //         .json({ error: "endDate is required for Extended status" });
// //     query += `, end_date=?`;
// //     params.push(endDate);
// //   }
// //   query += ` WHERE emp_id=? ORDER BY assign_id DESC LIMIT 1`;
// //   params.push(empId);

// //   db.query(query, params, (err, result) => {
// //     if (err) return res.status(500).json({ error: err.message });
// //     if (result.affectedRows === 0)
// //       return res
// //         .status(404)
// //         .json({ error: "No active assignment found for this employee" });
// //     res.json({ success: true, message: `Status updated to ${status}` });
// //   });
// // });

// // app.post("/assign-location", (req, res) => {
// //   const { emp_id, location_id, about_work, start_date, end_date, done_by } =
// //     req.body;
// //   db.query(
// //     "INSERT INTO employee_location_assignment (emp_id,location_id,about_work,start_date,end_date,status,done_by) VALUES (?,?,?,?,?,'Active',?)",
// //     [emp_id, location_id, about_work, start_date, end_date, done_by],
// //     (err) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json({ success: true, message: "Location assigned successfully" });
// //     },
// //   );
// // });

// // // ─── LEAVE MANAGEMENT ─────────────────────────────────────────────────────────
// // app.get("/leave-history", (req, res) => {
// //   const { emp_id } = req.query;
// //   if (!emp_id)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "emp_id is required" });
// //   const query = `
// //     SELECT l.leave_id, l.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
// //       l.leave_type, DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS from_date,
// //       DATE_FORMAT(l.leave_end_date, '%Y-%m-%d') AS to_date, l.number_of_days AS total_days,
// //       l.recommended_by, l.approved_by, l.status, l.reason, l.rejection_reason, l.cancel_reason
// //     FROM leave_master l
// //     JOIN employee_master e ON l.emp_id = e.emp_id
// //     WHERE l.emp_id = ?
// //     ORDER BY l.updated_at DESC`;
// //   db.query(query, [emp_id], (err, result) => {
// //     if (err)
// //       return res.status(500).json({ success: false, message: err.message });
// //     res.json({ success: true, data: result });
// //   });
// // });

// // app.get("/leaves/all-history", (req, res) => {
// //   const query = `
// //     SELECT l.leave_id, l.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
// //       l.leave_type, DATE_FORMAT(l.leave_start_date, '%Y-%m-%d') AS from_date,
// //       DATE_FORMAT(l.leave_end_date, '%Y-%m-%d') AS to_date, l.number_of_days AS total_days,
// //       l.recommended_by, l.approved_by, l.status, l.reason, l.rejection_reason, l.cancel_reason
// //     FROM leave_master l
// //     JOIN employee_master e ON l.emp_id = e.emp_id
// //     ORDER BY l.updated_at DESC`;
// //   db.query(query, (err, result) => {
// //     if (err)
// //       return res.status(500).json({ success: false, message: err.message });
// //     res.json({ success: true, data: result });
// //   });
// // });

// // app.get("/leaves/pending-tl", (req, res) => {
// //   const query = `
// //     SELECT l.leave_id, l.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
// //       d.department_name, r.role_name, l.leave_type, l.leave_start_date, l.leave_end_date,
// //       l.number_of_days, l.reason, l.status,
// //       IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0) AS taken_days,
// //       CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
// //            WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
// //            WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END AS total_allowed,
// //       (CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
// //             WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
// //             WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END
// //        - IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0)) AS remaining_days
// //     FROM leave_master l
// //     JOIN employee_master e ON l.emp_id = e.emp_id
// //     LEFT JOIN department_master d ON e.department_id = d.department_id
// //     LEFT JOIN role_master r ON e.role_id = r.role_id
// //     LEFT JOIN leave_master lm2 ON lm2.emp_id=l.emp_id AND lm2.leave_type=l.leave_type AND lm2.status='Approved'
// //     WHERE l.status = 'Pending_TL'
// //     GROUP BY l.leave_id ORDER BY l.created_at ASC`;
// //   db.query(query, (err, results) => {
// //     if (err)
// //       return res.status(500).json({ success: false, message: err.message });
// //     res.json({ success: true, data: results });
// //   });
// // });

// // app.put("/leave/:leaveId/tl-action", (req, res) => {
// //   const { action, rejection_reason, login_id } = req.body;
// //   if (!action || !login_id)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "action and login_id are required" });
// //   if (!["recommend", "not_recommend"].includes(action))
// //     return res.status(400).json({
// //       success: false,
// //       message: "action must be recommend or not_recommend",
// //     });
// //   if (
// //     action === "not_recommend" &&
// //     (!rejection_reason || rejection_reason.trim() === "")
// //   )
// //     return res.status(400).json({
// //       success: false,
// //       message: "rejection_reason is required when not recommending",
// //     });

// //   db.query(
// //     `SELECT lm.login_id, r.role_name
// //      FROM login_master lm
// //      JOIN role_master r ON lm.role_id = r.role_id
// //      WHERE lm.login_id = ? AND lm.status = 'Active'`,
// //     [login_id],
// //     (err, rows) => {
// //       if (err)
// //         return res.status(500).json({ success: false, message: err.message });
// //       if (rows.length === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Invalid login user" });

// //       const roleName = rows[0].role_name;
// //       if (!["TL", "Team Lead", "Team_Lead", "TeamLead"].includes(roleName))
// //         return res.status(403).json({
// //           success: false,
// //           message:
// //             "Only Team Leads can perform this action. Your role: " + roleName,
// //         });

// //       const newStatus =
// //         action === "recommend" ? "Pending_HR" : "Rejected_By_TL";
// //       const rejReason =
// //         action === "not_recommend" ? rejection_reason.trim() : null;
// //       const recommendedBy = action === "recommend" ? login_id : null;
// //       const recommendedAt = action === "recommend" ? new Date() : null;

// //       db.query(
// //         `UPDATE leave_master
// //          SET status=?, rejection_reason=?, recommended_by=?, recommended_at=?, updated_at=NOW()
// //          WHERE leave_id=? AND status='Pending_TL'`,
// //         [
// //           newStatus,
// //           rejReason,
// //           recommendedBy,
// //           recommendedAt,
// //           req.params.leaveId,
// //         ],
// //         (err2, result) => {
// //           if (err2)
// //             return res
// //               .status(500)
// //               .json({ success: false, message: err2.message });
// //           if (result.affectedRows === 0)
// //             return res.status(400).json({
// //               success: false,
// //               message: "Leave not found or already actioned",
// //             });
// //           res.json({
// //             success: true,
// //             message:
// //               action === "recommend"
// //                 ? "Leave recommended to HR"
// //                 : "Leave rejected by TL",
// //           });
// //         },
// //       );
// //     },
// //   );
// // });

// // app.get("/leaves/all-pending", (req, res) => {
// //   const query = `
// //     SELECT l.leave_id, l.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
// //       d.department_name, r.role_name, l.leave_type, l.leave_start_date, l.leave_end_date,
// //       l.number_of_days, l.reason, l.status, l.recommended_by, l.recommended_at,
// //       IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0) AS taken_days,
// //       CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
// //            WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
// //            WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END AS total_allowed,
// //       (CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
// //             WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
// //             WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END
// //        - IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0)) AS remaining_days
// //     FROM leave_master l
// //     JOIN employee_master e ON l.emp_id = e.emp_id
// //     LEFT JOIN department_master d ON e.department_id = d.department_id
// //     LEFT JOIN role_master r ON e.role_id = r.role_id
// //     LEFT JOIN leave_master lm2 ON lm2.emp_id=l.emp_id AND lm2.leave_type=l.leave_type AND lm2.status='Approved'
// //     WHERE l.status IN ('Pending_TL', 'Pending_HR')
// //     GROUP BY l.leave_id ORDER BY l.created_at ASC`;
// //   db.query(query, (err, results) => {
// //     if (err)
// //       return res.status(500).json({ success: false, message: err.message });
// //     res.json({ success: true, data: results });
// //   });
// // });

// app.get("/leaves/pending-hr", (req, res) => {
//   const query = `
//     SELECT l.leave_id, l.emp_id, CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
//       d.department_name, r.role_name, l.leave_type, l.leave_start_date, l.leave_end_date,
//       l.number_of_days, l.reason, l.status, l.recommended_by, l.recommended_at,
//       IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0) AS taken_days,
//       CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
//            WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
//            WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END AS total_allowed,
//       (CASE WHEN l.leave_type='Sick' THEN 12 WHEN l.leave_type='Casual' THEN 12
//             WHEN l.leave_type='Paid' THEN 15 WHEN l.leave_type='Maternity' THEN 90
//             WHEN l.leave_type='Paternity' THEN 15 ELSE 12 END
//        - IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END), 0)) AS remaining_days
//     FROM leave_master l
//     JOIN employee_master e ON l.emp_id = e.emp_id
//     LEFT JOIN department_master d ON e.department_id = d.department_id
//     LEFT JOIN role_master r ON e.role_id = r.role_id
//     LEFT JOIN leave_master lm2 ON lm2.emp_id=l.emp_id AND lm2.leave_type=l.leave_type AND lm2.status='Approved'
//     WHERE l.status = 'Pending_HR'
//     GROUP BY l.leave_id ORDER BY l.recommended_at ASC`;
//   db.query(query, (err, results) => {
//     if (err)
//       return res.status(500).json({ success: false, message: err.message });
//     res.json({ success: true, data: results });
//   });
// });

// // app.put("/leave/:leaveId/hr-action", (req, res) => {
// //   const { status, rejection_reason, login_id } = req.body;
// //   if (!status || !login_id)
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "status and login_id are required" });
// //   if (!["Approved", "Rejected_By_HR"].includes(status))
// //     return res.status(400).json({
// //       success: false,
// //       message: "status must be Approved or Rejected_By_HR",
// //     });
// //   if (
// //     status === "Rejected_By_HR" &&
// //     (!rejection_reason || rejection_reason.trim() === "")
// //   )
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "rejection_reason is required" });

// //   db.query(
// //     `SELECT login_id, role_id FROM login_master WHERE login_id = ? AND status = 'Active'`,
// //     [login_id],
// //     (err, rows) => {
// //       if (err)
// //         return res.status(500).json({ success: false, message: err.message });
// //       if (rows.length === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Invalid login user" });

// //       const roleId = rows[0].role_id;
// //       db.query(
// //         `SELECT role_id FROM role_master WHERE LOWER(role_name) LIKE '%hr%' OR LOWER(role_name) LIKE '%admin%'`,
// //         [],
// //         (err2, roleRows) => {
// //           if (err2)
// //             return res
// //               .status(500)
// //               .json({ success: false, message: err2.message });
// //           const hrRoleIds = roleRows.map((r) => r.role_id);
// //           if (!hrRoleIds.includes(roleId))
// //             return res.status(403).json({
// //               success: false,
// //               message: `Only HR or Admin can approve/reject. Your role_id: ${roleId}`,
// //             });

// //           db.query(
// //             `UPDATE leave_master SET status=?, approved_by=?, rejection_reason=?, updated_at=NOW()
// //              WHERE leave_id=? AND status='Pending_HR'`,
// //             [status, login_id, rejection_reason || null, req.params.leaveId],
// //             (err3, result) => {
// //               if (err3)
// //                 return res
// //                   .status(500)
// //                   .json({ success: false, message: err3.message });
// //               if (result.affectedRows === 0)
// //                 return res.status(400).json({
// //                   success: false,
// //                   message: "Leave not found or not in Pending_HR state",
// //                 });
// //               res.json({
// //                 success: true,
// //                 message:
// //                   status === "Approved" ? "Leave approved" : "Leave rejected",
// //               });
// //             },
// //           );
// //         },
// //       );
// //     },
// //   );
// // });

// // // ─── EDUCATION ROUTES ─────────────────────────────────────────────────────────
// // app.get("/employees/:empId/education", (req, res) => {
// //   db.query(
// //     `SELECT edu_id, emp_id, education_level, stream, score,
// //             year_of_passout, university, college_name, created_at
// //      FROM education_details
// //      WHERE emp_id = ?
// //      ORDER BY FIELD(education_level,'10','12','Diploma','UG','PG','PhD') ASC`,
// //     [req.params.empId],
// //     (err, results) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       res.json({ success: true, data: results });
// //     },
// //   );
// // });

// // app.post("/employees/:empId/education", (req, res) => {
// //   const {
// //     education_level,
// //     stream,
// //     score,
// //     year_of_passout,
// //     university,
// //     college_name,
// //   } = req.body;
// //   db.query(
// //     "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND admin_approve='PENDING'",
// //     [req.params.empId],
// //     (err, rows) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (rows.length > 0)
// //         return res.status(403).json({
// //           success: false,
// //           pending: true,
// //           request_id: rows[0].request_id,
// //           message: "Employee has a pending request. Use pending education API.",
// //         });

// //       const validLevels = ["10", "12", "Diploma", "UG", "PG", "PhD"];
// //       if (!education_level || !validLevels.includes(education_level))
// //         return res.status(400).json({
// //           success: false,
// //           message: "Valid education_level is required",
// //         });

// //       db.query(
// //         "SELECT edu_id FROM education_details WHERE emp_id=? AND education_level=?",
// //         [req.params.empId, education_level],
// //         (err, existing) => {
// //           if (err)
// //             return res.status(500).json({ success: false, error: err.message });
// //           if (existing.length > 0)
// //             return res.status(409).json({
// //               success: false,
// //               message: `Education level '${education_level}' already exists`,
// //             });

// //           db.query(
// //             `INSERT INTO education_details (emp_id, education_level, stream, score, year_of_passout, university, college_name) VALUES (?, ?, ?, ?, ?, ?, ?)`,
// //             [
// //               req.params.empId,
// //               education_level,
// //               stream || null,
// //               score != null && score !== "" ? parseFloat(score) : null,
// //               year_of_passout || null,
// //               university || null,
// //               college_name || null,
// //             ],
// //             (err2, result) => {
// //               if (err2)
// //                 return res
// //                   .status(500)
// //                   .json({ success: false, error: err2.message });
// //               res.json({
// //                 success: true,
// //                 message: "Education record added",
// //                 edu_id: result.insertId,
// //               });
// //             },
// //           );
// //         },
// //       );
// //     },
// //   );
// // });

// // app.put("/education/:eduId", (req, res) => {
// //   const { stream, score, year_of_passout, university, college_name } = req.body;
// //   db.query(
// //     "SELECT emp_id FROM education_details WHERE edu_id=?",
// //     [req.params.eduId],
// //     (err, rows) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (rows.length === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Education record not found" });
// //       const empId = rows[0].emp_id;
// //       db.query(
// //         "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND admin_approve='PENDING'",
// //         [empId],
// //         (err2, pendingRows) => {
// //           if (err2)
// //             return res
// //               .status(500)
// //               .json({ success: false, error: err2.message });
// //           if (pendingRows.length > 0)
// //             return res.status(403).json({
// //               success: false,
// //               pending: true,
// //               request_id: pendingRows[0].request_id,
// //               message:
// //                 "Employee has a pending request. Edit education via the pending request instead.",
// //             });
// //           db.query(
// //             `UPDATE education_details SET stream=?, score=?, year_of_passout=?, university=?, college_name=? WHERE edu_id=?`,
// //             [
// //               stream || null,
// //               score != null && score !== "" ? parseFloat(score) : null,
// //               year_of_passout || null,
// //               university || null,
// //               college_name || null,
// //               req.params.eduId,
// //             ],
// //             (err3, result) => {
// //               if (err3)
// //                 return res
// //                   .status(500)
// //                   .json({ success: false, error: err3.message });
// //               if (result.affectedRows === 0)
// //                 return res.status(404).json({
// //                   success: false,
// //                   message: "Education record not found",
// //                 });
// //               res.json({ success: true, message: "Education record updated" });
// //             },
// //           );
// //         },
// //       );
// //     },
// //   );
// // });

// // app.delete("/education/:eduId", (req, res) => {
// //   db.query(
// //     "SELECT emp_id FROM education_details WHERE edu_id=?",
// //     [req.params.eduId],
// //     (err, rows) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (rows.length === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Education record not found" });
// //       const empId = rows[0].emp_id;
// //       db.query(
// //         "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND admin_approve='PENDING'",
// //         [empId],
// //         (err2, pendingRows) => {
// //           if (err2)
// //             return res
// //               .status(500)
// //               .json({ success: false, error: err2.message });
// //           if (pendingRows.length > 0)
// //             return res.status(403).json({
// //               success: false,
// //               pending: true,
// //               request_id: pendingRows[0].request_id,
// //               message:
// //                 "Employee has a pending request. Delete education via the pending request instead.",
// //             });
// //           db.query(
// //             "DELETE FROM education_details WHERE edu_id=?",
// //             [req.params.eduId],
// //             (err3, result) => {
// //               if (err3)
// //                 return res
// //                   .status(500)
// //                   .json({ success: false, error: err3.message });
// //               if (result.affectedRows === 0)
// //                 return res.status(404).json({
// //                   success: false,
// //                   message: "Education record not found",
// //                 });
// //               res.json({ success: true, message: "Education record deleted" });
// //             },
// //           );
// //         },
// //       );
// //     },
// //   );
// // });

// // app.get("/employees/:empId/pending-request", (req, res) => {
// //   db.query(
// //     "SELECT request_id FROM employee_pending_request WHERE emp_id=? AND admin_approve='PENDING' ORDER BY created_at DESC LIMIT 1",
// //     [req.params.empId],
// //     (err, rows) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (rows.length === 0)
// //         return res.json({ success: true, pending: false, request_id: null });
// //       res.json({
// //         success: true,
// //         pending: true,
// //         request_id: rows[0].request_id,
// //       });
// //     },
// //   );
// // });

// // app.get("/requests/:requestId/education", (req, res) => {
// //   db.query(
// //     `SELECT edu_req_id, request_id, education_level, stream, score,
// //             year_of_passout, university, college_name, created_at
// //      FROM education_pending_request
// //      WHERE request_id = ?
// //      ORDER BY FIELD(education_level,'10','12','Diploma','UG','PG','PhD') ASC`,
// //     [req.params.requestId],
// //     (err, results) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       res.json({ success: true, data: results });
// //     },
// //   );
// // });

// // app.post("/requests/:requestId/education", (req, res) => {
// //   const {
// //     education_level,
// //     stream,
// //     score,
// //     year_of_passout,
// //     university,
// //     college_name,
// //   } = req.body;
// //   const validLevels = ["10", "12", "Diploma", "UG", "PG", "PhD"];
// //   if (!education_level || !validLevels.includes(education_level))
// //     return res
// //       .status(400)
// //       .json({ success: false, message: "Valid education_level is required" });

// //   db.query(
// //     `SELECT edu_req_id FROM education_pending_request WHERE request_id=? AND education_level=?`,
// //     [req.params.requestId, education_level],
// //     (err, existing) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (existing.length > 0)
// //         return res.status(409).json({
// //           success: false,
// //           message: `Education level '${education_level}' already exists`,
// //         });

// //       db.query(
// //         `INSERT INTO education_pending_request (request_id, education_level, stream, score, year_of_passout, university, college_name) VALUES (?, ?, ?, ?, ?, ?, ?)`,
// //         [
// //           req.params.requestId,
// //           education_level,
// //           stream || null,
// //           score != null && score !== "" ? parseFloat(score) : null,
// //           year_of_passout || null,
// //           university || null,
// //           college_name || null,
// //         ],
// //         (err2, result) => {
// //           if (err2)
// //             return res
// //               .status(500)
// //               .json({ success: false, error: err2.message });
// //           res.json({
// //             success: true,
// //             message: "Pending education added",
// //             edu_req_id: result.insertId,
// //           });
// //         },
// //       );
// //     },
// //   );
// // });

// // app.put("/requests/education/:eduReqId", (req, res) => {
// //   const { stream, score, year_of_passout, university, college_name } = req.body;
// //   db.query(
// //     `UPDATE education_pending_request SET stream=?, score=?, year_of_passout=?, university=?, college_name=? WHERE edu_req_id=?`,
// //     [
// //       stream || null,
// //       score != null && score !== "" ? parseFloat(score) : null,
// //       year_of_passout || null,
// //       university || null,
// //       college_name || null,
// //       req.params.eduReqId,
// //     ],
// //     (err, result) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (result.affectedRows === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Pending education not found" });
// //       res.json({ success: true, message: "Pending education updated" });
// //     },
// //   );
// // });

// // app.delete("/requests/education/:eduReqId", (req, res) => {
// //   db.query(
// //     "DELETE FROM education_pending_request WHERE edu_req_id=?",
// //     [req.params.eduReqId],
// //     (err, result) => {
// //       if (err)
// //         return res.status(500).json({ success: false, error: err.message });
// //       if (result.affectedRows === 0)
// //         return res
// //           .status(404)
// //           .json({ success: false, message: "Pending education not found" });
// //       res.json({ success: true, message: "Pending education deleted" });
// //     },
// //   );
// // });

// // // ─── SITES ────────────────────────────────────────────────────────────────────
// // app.post("/sites", (req, res) => {
// //   const { site_name, polygon_json, start_date, end_date } = req.body;
// //   if (!site_name || !polygon_json || !start_date || !end_date)
// //     return res.status(400).json({ message: "Missing required fields" });
// //   db.query(
// //     `INSERT INTO sites (site_name, polygon_json, start_date, end_date) VALUES (?, ?, ?, ?)`,
// //     [site_name, JSON.stringify(polygon_json), start_date, end_date],
// //     (err, result) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json({ message: "Site saved", id: result.insertId });
// //     },
// //   );
// // });

// // app.get("/sites", (req, res) => {
// //   db.query(
// //     `SELECT id, site_name, polygon_json,
// //       DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
// //       DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
// //       created_at FROM sites`,
// //     (err, results) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json(results);
// //     },
// //   );
// // });

// // app.put("/sites/:id", (req, res) => {
// //   const { id } = req.params;
// //   const { site_name, polygon_json, start_date, end_date } = req.body;
// //   if (!site_name || !polygon_json || !start_date || !end_date)
// //     return res.status(400).json({ message: "Missing required fields" });
// //   db.query(
// //     `UPDATE sites SET site_name = ?, polygon_json = ?, start_date = ?, end_date = ? WHERE id = ?`,
// //     [site_name, JSON.stringify(polygon_json), start_date, end_date, id],
// //     (err) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json({ message: "Site updated successfully" });
// //     },
// //   );
// // });

// // // ─── LOCATION CHECK ───────────────────────────────────────────────────────────
// // app.post("/attendance/check-location", (req, res) => {
// //   const { lat, lng } = req.body;
// //   if (lat == null || lng == null)
// //     return res.status(400).json({ message: "lat and lng are required" });

// //   db.query(
// //     `SELECT id, site_name, polygon_json FROM sites WHERE CURDATE() BETWEEN start_date AND end_date`,
// //     (err, rows) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       for (const site of rows) {
// //         const polygon = JSON.parse(site.polygon_json);
// //         if (
// //           isPointInPolygon(lat, lng, polygon) ||
// //           isNearPolygon(lat, lng, polygon)
// //         ) {
// //           return res.json({
// //             inside: true,
// //             site_id: site.id,
// //             site_name: site.site_name,
// //           });
// //         }
// //       }
// //       res.json({ inside: false });
// //     },
// //   );
// // });

// // function isPointInPolygon(lat, lng, polygon) {
// //   const pts = [...polygon];
// //   if (
// //     pts[0].lat !== pts[pts.length - 1].lat ||
// //     pts[0].lng !== pts[pts.length - 1].lng
// //   )
// //     pts.push({ lat: pts[0].lat, lng: pts[0].lng });
// //   let intersect = 0;
// //   for (let i = 0; i < pts.length - 1; i++) {
// //     const p1 = pts[i],
// //       p2 = pts[i + 1];
// //     if (
// //       p1.lng > lng !== p2.lng > lng &&
// //       lat < ((p2.lat - p1.lat) * (lng - p1.lng)) / (p2.lng - p1.lng) + p1.lat
// //     )
// //       intersect++;
// //   }
// //   return intersect % 2 === 1;
// // }

// // function getDistance(lat1, lng1, lat2, lng2) {
// //   const R = 6371000;
// //   const dLat = ((lat2 - lat1) * Math.PI) / 180;
// //   const dLng = ((lng2 - lng1) * Math.PI) / 180;
// //   const a =
// //     Math.sin(dLat / 2) ** 2 +
// //     Math.cos((lat1 * Math.PI) / 180) *
// //       Math.cos((lat2 * Math.PI) / 180) *
// //       Math.sin(dLng / 2) ** 2;
// //   return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
// // }

// // function isNearPolygon(lat, lng, polygon, bufferMeters = 35) {
// //   const pts = [...polygon];
// //   if (
// //     pts[0].lat !== pts[pts.length - 1].lat ||
// //     pts[0].lng !== pts[pts.length - 1].lng
// //   )
// //     pts.push({ lat: pts[0].lat, lng: pts[0].lng });
// //   for (let i = 0; i < pts.length - 1; i++) {
// //     if (getDistance(lat, lng, pts[i].lat, pts[i].lng) <= bufferMeters)
// //       return true;
// //     if (isNearSegment(lat, lng, pts[i], pts[i + 1], bufferMeters)) return true;
// //   }
// //   return false;
// // }

// // function isNearSegment(lat, lng, p1, p2, bufferMeters) {
// //   const dx = p2.lat - p1.lat,
// //     dy = p2.lng - p1.lng;
// //   const lenSq = dx * dx + dy * dy;
// //   if (lenSq === 0) return getDistance(lat, lng, p1.lat, p1.lng) <= bufferMeters;
// //   const t = Math.max(
// //     0,
// //     Math.min(1, ((lat - p1.lat) * dx + (lng - p1.lng) * dy) / lenSq),
// //   );
// //   return (
// //     getDistance(lat, lng, p1.lat + t * dx, p1.lng + t * dy) <= bufferMeters
// //   );
// // }

// // app.post("/attendance/in", (req, res) => {
// //   const { employee_id, site_id } = req.body;
// //   if (!employee_id || !site_id)
// //     return res
// //       .status(400)
// //       .json({ message: "employee_id and site_id are required" });

// //   // Check site is active today
// //   db.query(
// //     `SELECT id FROM sites WHERE id = ? AND CURDATE() BETWEEN start_date AND end_date`,
// //     [site_id],
// //     (err, siteRows) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       if (siteRows.length === 0)
// //         return res.status(400).json({ message: "Site not active today" });

// //       // Close any open record at a DIFFERENT site first
// //       db.query(
// //         `UPDATE employee_site_attendance
// //          SET out_time = NOW(), updated_at = NOW(), status = 'completed'
// //          WHERE employee_id = ? AND site_id != ? AND work_date = CURDATE() AND out_time IS NULL`,
// //         [employee_id, site_id],
// //         (err) => {
// //           if (err) return res.status(500).json({ message: "Database error" });

// //           // Check current site's most recent row today
// //           db.query(
// //             `SELECT id, out_time,
// //                TIMESTAMPDIFF(MINUTE, out_time, NOW()) AS minutes_since_out
// //              FROM employee_site_attendance
// //              WHERE employee_id = ? AND site_id = ? AND work_date = CURDATE()
// //              ORDER BY id DESC LIMIT 1`,
// //             [employee_id, site_id],
// //             (err, rows) => {
// //               if (err)
// //                 return res.status(500).json({ message: "Database error" });

// //               if (rows.length === 0) {
// //                 // Rule 5: No row for this site today — create fresh
// //                 return createNewAttendanceRow(employee_id, site_id, res);
// //               }

// //               const row = rows[0];

// //               if (row.out_time === null) {
// //                 // Rule 1: Already open — do nothing
// //                 return res.json({ message: "Already IN at this site" });
// //               }

// //               if (
// //                 row.minutes_since_out !== null &&
// //                 row.minutes_since_out < 15
// //               ) {
// //                 // Rule 2: Returned within 15 min — reopen same row
// //                 db.query(
// //                   `UPDATE employee_site_attendance
// //                    SET out_time = NULL, updated_at = NOW(), status = 'active'
// //                    WHERE id = ?`,
// //                   [row.id],
// //                   (err) => {
// //                     if (err)
// //                       return res
// //                         .status(500)
// //                         .json({ message: "Database error" });
// //                     res.json({
// //                       message: "IN marked (returned within 15min)",
// //                       id: row.id,
// //                     });
// //                   },
// //                 );
// //               } else {
// //                 // Rule 3: Been away >= 15 min — new row
// //                 return createNewAttendanceRow(employee_id, site_id, res);
// //               }
// //             },
// //           );
// //         },
// //       );
// //     },
// //   );
// // });

// // function createNewAttendanceRow(employee_id, site_id, res) {
// //   db.query(
// //     `INSERT INTO employee_site_attendance (employee_id, site_id, in_time, work_date, status, updated_at)
// //      VALUES (?, ?, NOW(), CURDATE(), 'active', NOW())`,
// //     [employee_id, site_id],
// //     (err, result) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json({ message: "IN marked (new row)", id: result.insertId });
// //     },
// //   );
// // }

// // /* ======================
// //    MARK OUT
// // ====================== */
// // app.post("/attendance/out", (req, res) => {
// //   const { employee_id } = req.body;
// //   if (!employee_id)
// //     return res.status(400).json({ message: "employee_id is required" });

// //   db.query(
// //     `UPDATE employee_site_attendance
// //      SET out_time = NOW(), updated_at = NOW(), status = 'completed'
// //      WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
// //     [employee_id],
// //     (err) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json({ message: "OUT marked" });
// //     },
// //   );
// // });

// // app.put("/attendance/heartbeat", (req, res) => {
// //   const { employee_id } = req.body;
// //   if (!employee_id)
// //     return res.status(400).json({ message: "employee_id is required" });

// //   db.query(
// //     `UPDATE employee_site_attendance
// //      SET out_time = NOW(), updated_at = NOW()
// //      WHERE employee_id = ? AND work_date = CURDATE() AND status = 'active'
// //      ORDER BY id DESC LIMIT 1`,
// //     [employee_id],
// //     (err, result) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json({ message: "ok", updated: result.affectedRows });
// //     },
// //   );
// // });

// // app.post("/attendance/end-day", (req, res) => {
// //   const { employee_id } = req.body;
// //   if (!employee_id)
// //     return res.status(400).json({ message: "employee_id is required" });

// //   db.query(
// //     `UPDATE employee_site_attendance
// //      SET out_time = NOW(), updated_at = NOW(), status = 'ended_manually'
// //      WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
// //     [employee_id],
// //     (err) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json({ message: "Day ended" });
// //     },
// //   );
// // });

// // app.get("/attendance/status/:empId", (req, res) => {
// //   db.query(
// //     `SELECT status FROM employee_site_attendance
// //      WHERE employee_id = ? AND work_date = CURDATE()
// //      ORDER BY id DESC LIMIT 1`,
// //     [req.params.empId],
// //     (err, rows) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       if (rows.length === 0) return res.json({ status: "not_started" });

// //       const s = rows[0].status;
// //       // Only 'ended_manually' means the user deliberately pressed END
// //       if (s === "ended_manually") return res.json({ status: "completed" });
// //       // 'active' (inside site) or 'completed' (between sites) = still working
// //       return res.json({ status: "in_progress" });
// //     },
// //   );
// // });

// // /* ======================
// //    TODAY'S LOGS
// //    All site visits for an employee today.
// //    Returns site name, in_time, out_time, duration, total_time_in_site.
// // ====================== */
// // app.get("/attendance/today/:empId", (req, res) => {
// //   db.query(
// //     `SELECT
// //        a.id,
// //        a.site_id,
// //        s.site_name,
// //        DATE_FORMAT(a.in_time,  '%H:%i:%s') AS in_time,
// //        DATE_FORMAT(a.out_time, '%H:%i:%s') AS out_time,
// //        a.work_date,
// //        a.status,
// //        a.total_time_in_site,
// //        TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS duration_minutes
// //      FROM employee_site_attendance a
// //      JOIN sites s ON a.site_id = s.id
// //      WHERE a.employee_id = ? AND a.work_date = CURDATE()
// //      ORDER BY a.in_time ASC`,
// //     [req.params.empId],
// //     (err, results) => {
// //       if (err) return res.status(500).json({ message: "Database error" });
// //       res.json(results);
// //     },
// //   );
// // });

// // /* ======================
// //    ATTENDANCE BY DATE (Admin view)
// //    Shows all active employees with present/absent status for a given date.
// // ====================== */
// // app.get("/attendance/by-date", (req, res) => {
// //   db.query(
// //     `SELECT e.emp_id, CONCAT(e.first_name,' ',IFNULL(e.mid_name,''),' ',e.last_name) AS name,
// //     CASE WHEN a.id IS NULL THEN 'ABSENT' ELSE 'PRESENT' END AS attendance_status,
// //     a.in_time, a.out_time, a.total_time_in_site, a.status AS attendance_record_status
// //     FROM employee_master e
// //     LEFT JOIN (
// //       SELECT employee_id, MIN(in_time) AS in_time, MAX(out_time) AS out_time,
// //              MAX(total_time_in_site) AS total_time_in_site, MAX(id) AS id,
// //              MAX(status) AS status
// //       FROM employee_site_attendance
// //       WHERE work_date = ?
// //       GROUP BY employee_id
// //     ) a ON e.emp_id = a.employee_id
// //     WHERE e.status = 'Active'
// //     ORDER BY e.emp_id`,
// //     [req.query.date],
// //     (err, rows) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       res.json(rows);
// //     },
// //   );
// // });

// // /* ======================
// //    EMPLOYEE WORK HOURS SUMMARY
// //    Today's total duration and this week's total.
// // ====================== */
// // app.get("/employee-work-hours/:empId", (req, res) => {
// //   const empId = req.params.empId;

// //   // Today's total minutes across all site visits
// //   db.query(
// //     `SELECT IFNULL(SUM(TIMESTAMPDIFF(MINUTE, in_time, IFNULL(out_time, NOW()))), 0) AS minutes
// //      FROM employee_site_attendance
// //      WHERE employee_id = ? AND work_date = CURDATE()`,
// //     [empId],
// //     (err, todayRows) => {
// //       if (err) return res.status(500).json({ error: err.message });
// //       const todayMins = todayRows[0].minutes ?? 0;

// //       // This week's total (Mon–today)
// //       db.query(
// //         `SELECT IFNULL(SUM(TIMESTAMPDIFF(MINUTE, in_time, IFNULL(out_time, NOW()))), 0) AS minutes
// //          FROM employee_site_attendance
// //          WHERE employee_id = ?
// //            AND work_date >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)
// //            AND work_date <= CURDATE()`,
// //         [empId],
// //         (err, weekRows) => {
// //           if (err) return res.status(500).json({ error: err.message });
// //           const weekMins = weekRows[0].minutes ?? 0;
// //           const fmt = (m) => `${Math.floor(m / 60)}h ${m % 60}m`;
// //           res.json({ today: fmt(todayMins), week: fmt(weekMins) });
// //         },
// //       );
// //     },
// //   );
// // });

// // app.post("/attendance/batch-sync", (req, res) => {
// //   const { events } = req.body;
// //   if (!events || !Array.isArray(events) || events.length === 0)
// //     return res.status(400).json({ message: "events array required" });

// //   // Process sequentially — order matters (in before out, etc.)
// //   const processNext = async (index, results) => {
// //     if (index >= events.length)
// //       return res.json({ success: true, processed: results });

// //     const e = events[index];
// //     const { type, employee_id, site_id, timestamp } = e;

// //     try {
// //       switch (type) {
// //         case "mark_in": {
// //           if (!employee_id || !site_id)
// //             throw new Error("mark_in requires employee_id and site_id");

// //           // Close any open row at a different site
// //           await dbRun(
// //             `UPDATE employee_site_attendance
// //              SET out_time = ?, updated_at = NOW(), status = 'completed'
// //              WHERE employee_id = ? AND site_id != ? AND work_date = CURDATE() AND out_time IS NULL`,
// //             [timestamp, employee_id, site_id],
// //           );

// //           // Check if we already have an open or recent row for this site
// //           const existing = await dbGet(
// //             `SELECT id, out_time,
// //                TIMESTAMPDIFF(MINUTE, out_time, ?) AS mins_since_out
// //              FROM employee_site_attendance
// //              WHERE employee_id = ? AND site_id = ? AND work_date = CURDATE()
// //              ORDER BY id DESC LIMIT 1`,
// //             [timestamp, employee_id, site_id],
// //           );

// //           if (!existing) {
// //             // No row yet today for this site → create
// //             await dbRun(
// //               `INSERT INTO employee_site_attendance
// //                (employee_id, site_id, in_time, work_date, status, updated_at)
// //                VALUES (?, ?, ?, DATE(?), 'active', NOW())`,
// //               [employee_id, site_id, timestamp, timestamp],
// //             );
// //           } else if (existing.out_time === null) {
// //             // Already open — nothing to do
// //           } else if (
// //             existing.mins_since_out !== null &&
// //             existing.mins_since_out < 15
// //           ) {
// //             // Returned within 15 min → reopen
// //             await dbRun(
// //               `UPDATE employee_site_attendance
// //                SET out_time = NULL, updated_at = NOW(), status = 'active'
// //                WHERE id = ?`,
// //               [existing.id],
// //             );
// //           } else {
// //             // Been away 15+ min → new row
// //             await dbRun(
// //               `INSERT INTO employee_site_attendance
// //                (employee_id, site_id, in_time, work_date, status, updated_at)
// //                VALUES (?, ?, ?, DATE(?), 'active', NOW())`,
// //               [employee_id, site_id, timestamp, timestamp],
// //             );
// //           }
// //           results.push({ id: index, type, status: "ok" });
// //           break;
// //         }

// //         case "mark_out": {
// //           if (!employee_id) throw new Error("mark_out requires employee_id");
// //           await dbRun(
// //             `UPDATE employee_site_attendance
// //              SET out_time = ?, updated_at = NOW(), status = 'completed'
// //              WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
// //             [timestamp, employee_id],
// //           );
// //           results.push({ id: index, type, status: "ok" });
// //           break;
// //         }

// //         case "end_day": {
// //           if (!employee_id) throw new Error("end_day requires employee_id");
// //           await dbRun(
// //             `UPDATE employee_site_attendance
// //              SET out_time = ?, updated_at = NOW(), status = 'ended_manually'
// //              WHERE employee_id = ? AND work_date = CURDATE() AND out_time IS NULL`,
// //             [timestamp, employee_id],
// //           );
// //           results.push({ id: index, type, status: "ok" });
// //           break;
// //         }

// //         default:
// //           results.push({ id: index, type, status: "unknown_type" });
// //       }
// //     } catch (err) {
// //       console.error(`Batch event ${index} (${type}) failed:`, err.message);
// //       results.push({ id: index, type, status: "error", message: err.message });
// //     }

// //     return processNext(index + 1, results);
// //   };

// //   processNext(0, []).catch((err) =>
// //     res.status(500).json({ message: err.message }),
// //   );
// // });

// // // ─── Promise wrappers for mysql callbacks ─────────────────────────────────────
// // function dbRun(sql, params) {
// //   return new Promise((resolve, reject) =>
// //     db.query(sql, params, (err, result) =>
// //       err ? reject(err) : resolve(result),
// //     ),
// //   );
// // }
// // function dbGet(sql, params) {
// //   return new Promise((resolve, reject) =>
// //     db.query(sql, params, (err, rows) =>
// //       err ? reject(err) : resolve(rows[0] || null),
// //     ),
// //   );
// // }
// // const PORT = 3000;
// // app.listen(PORT, "0.0.0.0", () =>
// //   console.log(`Server running on http://0.0.0.0:${PORT}`),
// // );
// /**
//  * Employee Attendance System — Express Server
//  * Fixed issues:
//  *  1. Added /auth/login route (was missing, ApiService called /auth/login)
//  *  2. batch-sync now uses DATE(timestamp) instead of CURDATE() so offline
//  *     events synced after midnight land on the correct work_date
//  *  3. attendance/status returns correct state including cross-device "done"
//  *  4. All routes use consistent error handling and response shapes
//  */

// const express = require("express");
// const mysql = require("mysql2");
// const cors = require("cors");

// const app = express();
// app.use(express.json());
// app.use(cors());

// // ─── DATABASE ────────────────────────────────────────────────────────────────
// const db = mysql.createPool({
//   host: process.env.DB_HOST || "localhost",
//   user: process.env.DB_USER || "root",
//   password: process.env.DB_PASS || "2026",
//   database: process.env.DB_NAME || "kavidhan",
//   waitForConnections: true,
//   connectionLimit: 10,
//   queueLimit: 0,
// });

// // Promise wrappers — used throughout
// function dbRun(sql, params = []) {
//   return new Promise((resolve, reject) =>
//     db.query(sql, params, (err, result) =>
//       err ? reject(err) : resolve(result),
//     ),
//   );
// }
// function dbGet(sql, params = []) {
//   return new Promise((resolve, reject) =>
//     db.query(sql, params, (err, rows) =>
//       err ? reject(err) : resolve(rows[0] || null),
//     ),
//   );
// }
// function dbAll(sql, params = []) {
//   return new Promise((resolve, reject) =>
//     db.query(sql, params, (err, rows) => (err ? reject(err) : resolve(rows))),
//   );
// }

// db.getConnection((err) => {
//   if (err) {
//     console.error("DB connection error:", err);
//     process.exit(1);
//   }
//   console.log("MySQL connected!");
// });

// // ─── HEALTH CHECK ─────────────────────────────────────────────────────────────
// app.get("/", (req, res) => res.json({ ok: true, time: new Date() }));

// // ─── AUTH ─────────────────────────────────────────────────────────────────────
// // FIX: ApiService calls /auth/login — added this route alias
// app.post("/auth/login", handleLogin);
// app.post("/login", handleLogin);

// async function handleLogin(req, res) {
//   try {
//     // Support both {login_id, password} (mobile) and {username, password} (web)
//     const loginId = req.body.login_id || req.body.username;
//     const { password } = req.body;

//     if (!loginId || !password)
//       return res
//         .status(400)
//         .json({ message: "Login ID and password required" });

//     const user = await dbGet(
//       `SELECT login_id, emp_id, role_id, username
//        FROM login_master
//        WHERE TRIM(LOWER(username)) = TRIM(LOWER(?))
//          AND password = ?
//          AND status = 'Active'`,
//       [loginId, password],
//     );

//     if (!user)
//       return res.status(401).json({ message: "Invalid username or password" });

//     res.json({
//       loginId: user.login_id,
//       empId: user.emp_id,
//       roleId: user.role_id,
//       username: user.username.trim(),
//     });
//   } catch (err) {
//     console.error("[Login]", err);
//     res.status(500).json({ message: "Server error" });
//   }
// }

// app.get("/login", (req, res) =>
//   res.send("Login API is live. Use POST method."),
// );

// app.get("/login-user/:loginId", async (req, res) => {
//   try {
//     const u = await dbGet(
//       `SELECT lm.emp_id, lm.username, r.role_name,
//           CONCAT(e.first_name,
//             CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != ''
//               THEN CONCAT(' ', e.mid_name) ELSE '' END,
//             ' ', e.last_name) AS full_name
//        FROM login_master lm
//        LEFT JOIN employee_master e  ON lm.emp_id  = e.emp_id
//        LEFT JOIN role_master     r  ON lm.role_id = r.role_id
//        WHERE lm.login_id = ?`,
//       [req.params.loginId],
//     );
//     if (!u)
//       return res.status(404).json({ success: false, message: "Not found" });
//     res.json({
//       success: true,
//       login_id: req.params.loginId,
//       emp_id: u.emp_id,
//       full_name: u.full_name?.trim() || u.username,
//       role_name: u.role_name || "-",
//     });
//   } catch (err) {
//     res.status(500).json({ success: false, error: err.message });
//   }
// });

// // ─── ROLES ────────────────────────────────────────────────────────────────────
// app.get("/roles", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       "SELECT role_id AS id, role_name AS name FROM role_master ORDER BY role_name ASC",
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// // ─── EMPLOYEE ─────────────────────────────────────────────────────────────────
// app.get("/employees/:empId", async (req, res) => {
//   try {
//     const row = await dbGet(
//       `SELECT e.*, d.department_name, r.role_name,
//           DATE_FORMAT(e.date_of_birth,     '%Y-%m-%d') AS date_of_birth,
//           DATE_FORMAT(e.date_of_joining,   '%Y-%m-%d') AS date_of_joining,
//           DATE_FORMAT(e.date_of_relieving, '%Y-%m-%d') AS date_of_relieving
//        FROM employee_master e
//        LEFT JOIN department_master d ON e.department_id = d.department_id
//        LEFT JOIN role_master r       ON e.role_id       = r.role_id
//        WHERE e.emp_id = ?`,
//       [req.params.empId],
//     );
//     if (!row) return res.status(404).json({ error: "Employee not found" });
//     res.json(row);
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── LEAVE ────────────────────────────────────────────────────────────────────
// app.get("/employees/:empId/leaves", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT leave_id, emp_id, leave_type,
//           DATE_FORMAT(leave_start_date, '%Y-%m-%d') AS leave_start_date,
//           DATE_FORMAT(leave_end_date,   '%Y-%m-%d') AS leave_end_date,
//           number_of_days, recommended_by,
//           DATE_FORMAT(recommended_at, '%Y-%m-%d %H:%i:%s') AS recommended_at,
//           approved_by, status, reason, cancel_reason, rejection_reason,
//           DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
//           DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at
//        FROM leave_master WHERE emp_id = ? ORDER BY leave_start_date DESC`,
//       [req.params.empId],
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.post("/employees/:empId/apply-leave", async (req, res) => {
//   const { leave_type, leave_start_date, leave_end_date, reason } = req.body;
//   if (!leave_type || !leave_start_date || !leave_end_date)
//     return res
//       .status(400)
//       .json({ success: false, message: "Leave type and dates are required" });
//   try {
//     await dbRun(
//       `INSERT INTO leave_master
//          (emp_id, leave_type, leave_start_date, leave_end_date, reason, status, created_at, updated_at)
//        VALUES (?, ?, ?, ?, ?, 'Pending_TL', NOW(), NOW())`,
//       [
//         req.params.empId,
//         leave_type,
//         leave_start_date,
//         leave_end_date,
//         reason || "",
//       ],
//     );
//     res.json({ success: true, message: "Leave applied successfully" });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.put("/leave/:leaveId", async (req, res) => {
//   const { leave_type, leave_start_date, leave_end_date, reason } = req.body;
//   if (!leave_type || !leave_start_date || !leave_end_date)
//     return res
//       .status(400)
//       .json({ success: false, message: "Leave type and dates required" });
//   try {
//     const result = await dbRun(
//       `UPDATE leave_master SET leave_type=?, leave_start_date=?, leave_end_date=?,
//           reason=?, updated_at=NOW()
//        WHERE leave_id=? AND status='Pending_TL'`,
//       [
//         leave_type,
//         leave_start_date,
//         leave_end_date,
//         reason || "",
//         req.params.leaveId,
//       ],
//     );
//     if (result.affectedRows === 0)
//       return res.status(400).json({
//         success: false,
//         message: "Only Pending_TL leaves can be edited",
//       });
//     res.json({ success: true, message: "Leave updated" });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.put("/leave/:leaveId/cancel", async (req, res) => {
//   const { cancel_reason } = req.body;
//   if (!cancel_reason?.trim())
//     return res
//       .status(400)
//       .json({ success: false, message: "Cancel reason required" });
//   try {
//     const result = await dbRun(
//       `UPDATE leave_master SET status='Cancelled', cancel_reason=?
//        WHERE leave_id=? AND status='Pending_TL'`,
//       [cancel_reason, req.params.leaveId],
//     );
//     if (result.affectedRows === 0)
//       return res.status(400).json({
//         success: false,
//         message: "Only Pending_TL leaves can be cancelled",
//       });
//     res.json({ success: true, message: "Leave cancelled" });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// // ─── SITES ────────────────────────────────────────────────────────────────────
// app.get("/sites", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT id, site_name, polygon_json,
//           DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
//           DATE_FORMAT(end_date,   '%Y-%m-%d') AS end_date,
//           created_at
//        FROM sites`,
//     );
//     res.json(rows);
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// app.post("/sites", async (req, res) => {
//   const { site_name, polygon_json, start_date, end_date } = req.body;
//   if (!site_name || !polygon_json || !start_date || !end_date)
//     return res.status(400).json({ message: "Missing required fields" });
//   try {
//     const result = await dbRun(
//       `INSERT INTO sites (site_name, polygon_json, start_date, end_date) VALUES (?, ?, ?, ?)`,
//       [site_name, JSON.stringify(polygon_json), start_date, end_date],
//     );
//     res.json({ message: "Site saved", id: result.insertId });
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// app.put("/sites/:id", async (req, res) => {
//   const { site_name, polygon_json, start_date, end_date } = req.body;
//   if (!site_name || !polygon_json || !start_date || !end_date)
//     return res.status(400).json({ message: "Missing required fields" });
//   try {
//     await dbRun(
//       `UPDATE sites SET site_name=?, polygon_json=?, start_date=?, end_date=? WHERE id=?`,
//       [
//         site_name,
//         JSON.stringify(polygon_json),
//         start_date,
//         end_date,
//         req.params.id,
//       ],
//     );
//     res.json({ message: "Site updated" });
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// // ─── ATTENDANCE — STATUS ───────────────────────────────────────────────────────
// /**
//  * FIX: Returns correct tri-state:
//  *   "not_started"  → no rows today
//  *   "in_progress"  → has rows but NOT ended_manually
//  *   "completed"    → last row is ended_manually
//  */
// app.get("/attendance/status/:empId", async (req, res) => {
//   try {
//     const row = await dbGet(
//       `SELECT status FROM employee_site_attendance
//        WHERE employee_id = ? AND work_date = CURDATE()
//        ORDER BY id DESC LIMIT 1`,
//       [req.params.empId],
//     );

//     if (!row) return res.json({ status: "not_started" });

//     if (row.status === "ended_manually")
//       return res.json({ status: "completed" });

//     return res.json({ status: "in_progress" });
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// // ─── ATTENDANCE — TODAY'S LOGS ────────────────────────────────────────────────
// app.get("/attendance/today/:empId", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT a.id, a.site_id, s.site_name,
//           DATE_FORMAT(a.in_time,  '%H:%i:%s') AS in_time,
//           DATE_FORMAT(a.out_time, '%H:%i:%s') AS out_time,
//           a.work_date, a.status,
//           TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS duration_minutes
//        FROM employee_site_attendance a
//        JOIN sites s ON a.site_id = s.id
//        WHERE a.employee_id = ? AND a.work_date = CURDATE()
//        ORDER BY a.in_time ASC`,
//       [req.params.empId],
//     );
//     res.json(rows);
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// // ─── ATTENDANCE — MARK IN ────────────────────────────────────────────────────
// app.post("/attendance/in", async (req, res) => {
//   const { employee_id, site_id } = req.body;
//   if (!employee_id || !site_id)
//     return res
//       .status(400)
//       .json({ message: "employee_id and site_id required" });

//   try {
//     // Verify site is active today
//     const site = await dbGet(
//       `SELECT id FROM sites WHERE id=? AND CURDATE() BETWEEN start_date AND end_date`,
//       [site_id],
//     );
//     if (!site)
//       return res.status(400).json({ message: "Site not active today" });

//     // Close any open row at a DIFFERENT site
//     await dbRun(
//       `UPDATE employee_site_attendance
//        SET out_time=NOW(), updated_at=NOW(), status='completed'
//        WHERE employee_id=? AND site_id!=? AND work_date=CURDATE() AND out_time IS NULL`,
//       [employee_id, site_id],
//     );

//     // Check current site's latest row today
//     const existing = await dbGet(
//       `SELECT id, out_time,
//           TIMESTAMPDIFF(MINUTE, out_time, NOW()) AS minutes_since_out
//        FROM employee_site_attendance
//        WHERE employee_id=? AND site_id=? AND work_date=CURDATE()
//        ORDER BY id DESC LIMIT 1`,
//       [employee_id, site_id],
//     );

//     if (!existing) {
//       const r = await dbRun(
//         `INSERT INTO employee_site_attendance
//            (employee_id, site_id, in_time, work_date, status, updated_at)
//          VALUES (?, ?, NOW(), CURDATE(), 'active', NOW())`,
//         [employee_id, site_id],
//       );
//       return res.json({ message: "IN marked (new)", id: r.insertId });
//     }

//     if (existing.out_time === null)
//       return res.json({ message: "Already IN at this site", id: existing.id });

//     if (
//       existing.minutes_since_out !== null &&
//       existing.minutes_since_out < 15
//     ) {
//       await dbRun(
//         `UPDATE employee_site_attendance
//          SET out_time=NULL, updated_at=NOW(), status='active' WHERE id=?`,
//         [existing.id],
//       );
//       return res.json({
//         message: "IN marked (returned <15m)",
//         id: existing.id,
//       });
//     }

//     const r = await dbRun(
//       `INSERT INTO employee_site_attendance
//          (employee_id, site_id, in_time, work_date, status, updated_at)
//        VALUES (?, ?, NOW(), CURDATE(), 'active', NOW())`,
//       [employee_id, site_id],
//     );
//     res.json({ message: "IN marked (new row)", id: r.insertId });
//   } catch (err) {
//     console.error("[mark_in]", err);
//     res.status(500).json({ message: "Database error" });
//   }
// });

// // ─── ATTENDANCE — MARK OUT ───────────────────────────────────────────────────
// app.post("/attendance/out", async (req, res) => {
//   const { employee_id } = req.body;
//   if (!employee_id)
//     return res.status(400).json({ message: "employee_id required" });
//   try {
//     await dbRun(
//       `UPDATE employee_site_attendance
//        SET out_time=NOW(), updated_at=NOW(), status='completed'
//        WHERE employee_id=? AND work_date=CURDATE() AND out_time IS NULL`,
//       [employee_id],
//     );
//     res.json({ message: "OUT marked" });
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// // ─── ATTENDANCE — END DAY ────────────────────────────────────────────────────
// app.post("/attendance/end-day", async (req, res) => {
//   const { employee_id } = req.body;
//   if (!employee_id)
//     return res.status(400).json({ message: "employee_id required" });
//   try {
//     await dbRun(
//       `UPDATE employee_site_attendance
//        SET out_time=NOW(), updated_at=NOW(), status='ended_manually'
//        WHERE employee_id=? AND work_date=CURDATE() AND out_time IS NULL`,
//       [employee_id],
//     );
//     res.json({ message: "Day ended" });
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// // ─── ATTENDANCE — HEARTBEAT ──────────────────────────────────────────────────
// app.put("/attendance/heartbeat", async (req, res) => {
//   const { employee_id } = req.body;
//   if (!employee_id)
//     return res.status(400).json({ message: "employee_id required" });
//   try {
//     const result = await dbRun(
//       `UPDATE employee_site_attendance
//        SET out_time=NOW(), updated_at=NOW()
//        WHERE employee_id=? AND work_date=CURDATE() AND status='active'
//        ORDER BY id DESC LIMIT 1`,
//       [employee_id],
//     );
//     res.json({ message: "ok", updated: result.affectedRows });
//   } catch (err) {
//     res.status(500).json({ message: "Database error" });
//   }
// });

// // ─── ATTENDANCE — BATCH SYNC ─────────────────────────────────────────────────
// /**
//  * FIX: Uses DATE(timestamp) instead of CURDATE() so events recorded before
//  * midnight are stored on the correct work_date even when synced late.
//  * Also uses the event's own timestamp for in_time/out_time.
//  */
// app.post("/attendance/batch-sync", async (req, res) => {
//   const { events } = req.body;
//   if (!Array.isArray(events) || events.length === 0)
//     return res.status(400).json({ message: "events array required" });

//   const results = [];

//   for (let i = 0; i < events.length; i++) {
//     const e = events[i];
//     const { type, employee_id, site_id, timestamp } = e;

//     // Use the event's own timestamp; fall back to NOW() if missing
//     const ts = timestamp || new Date().toISOString();
//     const workDate = ts.slice(0, 10); // "YYYY-MM-DD"

//     try {
//       switch (type) {
//         case "mark_in": {
//           if (!employee_id || !site_id)
//             throw new Error("mark_in requires employee_id and site_id");

//           // Close open row at a different site on the same work_date
//           await dbRun(
//             `UPDATE employee_site_attendance
//              SET out_time=?, updated_at=NOW(), status='completed'
//              WHERE employee_id=? AND site_id!=? AND work_date=? AND out_time IS NULL`,
//             [ts, employee_id, site_id, workDate],
//           );

//           const existing = await dbGet(
//             `SELECT id, out_time,
//                 TIMESTAMPDIFF(MINUTE, out_time, ?) AS mins_since_out
//              FROM employee_site_attendance
//              WHERE employee_id=? AND site_id=? AND work_date=?
//              ORDER BY id DESC LIMIT 1`,
//             [ts, employee_id, site_id, workDate],
//           );

//           if (!existing) {
//             await dbRun(
//               `INSERT INTO employee_site_attendance
//                  (employee_id, site_id, in_time, work_date, status, updated_at)
//                VALUES (?, ?, ?, ?, 'active', NOW())`,
//               [employee_id, site_id, ts, workDate],
//             );
//           } else if (existing.out_time !== null) {
//             if (
//               existing.mins_since_out !== null &&
//               existing.mins_since_out < 15
//             ) {
//               await dbRun(
//                 `UPDATE employee_site_attendance
//                  SET out_time=NULL, updated_at=NOW(), status='active' WHERE id=?`,
//                 [existing.id],
//               );
//             } else {
//               await dbRun(
//                 `INSERT INTO employee_site_attendance
//                    (employee_id, site_id, in_time, work_date, status, updated_at)
//                  VALUES (?, ?, ?, ?, 'active', NOW())`,
//                 [employee_id, site_id, ts, workDate],
//               );
//             }
//           }
//           // else: already open, nothing to do

//           results.push({ index: i, type, status: "ok" });
//           break;
//         }

//         case "mark_out": {
//           if (!employee_id) throw new Error("mark_out requires employee_id");
//           await dbRun(
//             `UPDATE employee_site_attendance
//              SET out_time=?, updated_at=NOW(), status='completed'
//              WHERE employee_id=? AND work_date=? AND out_time IS NULL`,
//             [ts, employee_id, workDate],
//           );
//           results.push({ index: i, type, status: "ok" });
//           break;
//         }

//         case "end_day": {
//           if (!employee_id) throw new Error("end_day requires employee_id");
//           await dbRun(
//             `UPDATE employee_site_attendance
//              SET out_time=?, updated_at=NOW(), status='ended_manually'
//              WHERE employee_id=? AND work_date=? AND out_time IS NULL`,
//             [ts, employee_id, workDate],
//           );
//           results.push({ index: i, type, status: "ok" });
//           break;
//         }

//         default:
//           results.push({ index: i, type, status: "unknown_type" });
//       }
//     } catch (err) {
//       console.error(`[batch-sync] event ${i} (${type}):`, err.message);
//       results.push({ index: i, type, status: "error", message: err.message });
//     }
//   }

//   res.json({ success: true, processed: results });
// });

// // ─── ATTENDANCE — BY DATE (Admin) ────────────────────────────────────────────
// app.get("/attendance/by-date", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT e.emp_id,
//           CONCAT(e.first_name,' ',IFNULL(e.mid_name,''),' ',e.last_name) AS name,
//           CASE WHEN a.id IS NULL THEN 'ABSENT' ELSE 'PRESENT' END AS attendance_status,
//           a.in_time, a.out_time, a.status AS attendance_record_status
//        FROM employee_master e
//        LEFT JOIN (
//          SELECT employee_id, MIN(in_time) AS in_time, MAX(out_time) AS out_time,
//                 MAX(id) AS id, MAX(status) AS status
//          FROM employee_site_attendance WHERE work_date=?
//          GROUP BY employee_id
//        ) a ON e.emp_id = a.employee_id
//        WHERE e.status='Active'
//        ORDER BY e.emp_id`,
//       [req.query.date],
//     );
//     res.json(rows);
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── EMPLOYEE WORK HOURS ─────────────────────────────────────────────────────
// app.get("/employee-work-hours/:empId", async (req, res) => {
//   const { empId } = req.params;
//   try {
//     const todayRow = await dbGet(
//       `SELECT IFNULL(SUM(TIMESTAMPDIFF(MINUTE, in_time, IFNULL(out_time,NOW()))),0) AS minutes
//        FROM employee_site_attendance WHERE employee_id=? AND work_date=CURDATE()`,
//       [empId],
//     );
//     const weekRow = await dbGet(
//       `SELECT IFNULL(SUM(TIMESTAMPDIFF(MINUTE, in_time, IFNULL(out_time,NOW()))),0) AS minutes
//        FROM employee_site_attendance
//        WHERE employee_id=?
//          AND work_date >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)
//          AND work_date <= CURDATE()`,
//       [empId],
//     );
//     const fmt = (m) => `${Math.floor(m / 60)}h ${m % 60}m`;
//     res.json({ today: fmt(todayRow.minutes), week: fmt(weekRow.minutes) });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── DASHBOARD ────────────────────────────────────────────────────────────────
// app.get("/dashboard", async (req, res) => {
//   const today = new Date().toISOString().split("T")[0];
//   try {
//     const [
//       [{ v: totalEmployees }],
//       [{ v: present }],
//       [{ v: onSiteToday }],
//       [{ v: pendingEmpReq }],
//       [{ v: pendingLeaveReq }],
//       [{ v: absent }],
//     ] = await Promise.all([
//       dbAll(`SELECT COUNT(*) AS v FROM employee_master WHERE status='Active'`),
//       dbAll(
//         `SELECT COUNT(DISTINCT employee_id) AS v FROM employee_site_attendance WHERE work_date=?`,
//         [today],
//       ),
//       dbAll(
//         `SELECT COUNT(DISTINCT emp_id) AS v FROM employee_location_assignment
//          WHERE start_date<=? AND end_date>=? AND status IN ('Active','Extended')`,
//         [today, today],
//       ),
//       dbAll(
//         `SELECT COUNT(*) AS v FROM employee_pending_request WHERE admin_approve='PENDING'`,
//       ),
//       dbAll(
//         `SELECT COUNT(*) AS v FROM leave_master WHERE status='Pending' AND leave_start_date>=?`,
//         [today],
//       ),
//       dbAll(
//         `SELECT COUNT(*) AS v FROM employee_master e
//          LEFT JOIN employee_site_attendance a
//            ON e.emp_id=a.employee_id AND a.work_date=?
//          WHERE e.status='Active' AND a.id IS NULL`,
//         [today],
//       ),
//     ]);

//     res.json({
//       totalEmployees,
//       present,
//       absent,
//       onSiteToday,
//       pendingRequests: pendingEmpReq + pendingLeaveReq,
//     });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── DEPARTMENTS ──────────────────────────────────────────────────────────────
// app.get("/departments", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT department_id AS id, department_name AS name
//        FROM department_master WHERE status='Active'`,
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.post("/departments", async (req, res) => {
//   const { department_name } = req.body;
//   if (!department_name)
//     return res
//       .status(400)
//       .json({ success: false, message: "Department name required" });
//   try {
//     const result = await dbRun(
//       `INSERT INTO department_master (department_name, status, created_at, updated_at)
//        VALUES (?, 'Active', NOW(), NOW())`,
//       [department_name],
//     );
//     res.json({
//       success: true,
//       message: "Department added",
//       department_id: result.insertId,
//     });
//   } catch (err) {
//     if (err.code === "ER_DUP_ENTRY")
//       return res
//         .status(400)
//         .json({ success: false, message: "Department already exists" });
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.put("/departments/:id/status", async (req, res) => {
//   const { status } = req.body;
//   if (!["Active", "Inactive"].includes(status))
//     return res.status(400).json({ success: false, message: "Invalid status" });
//   try {
//     await dbRun(
//       `UPDATE department_master SET status=?, updated_at=NOW() WHERE department_id=?`,
//       [status, req.params.id],
//     );
//     res.json({ success: true, message: `Department ${status.toLowerCase()}` });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// // ─── LOCATIONS ────────────────────────────────────────────────────────────────
// app.get("/locations", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT location_id, latitude, longitude, start_date, end_date,
//           contact_person_name, contact_person_number, location_nick_name
//        FROM location_master ORDER BY created_at DESC`,
//     );
//     res.json(rows);
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// app.post("/locations", async (req, res) => {
//   let {
//     nick_name,
//     latitude,
//     longitude,
//     start_date,
//     end_date,
//     contact_person_name,
//     contact_person_number,
//   } = req.body;

//   if (!nick_name || !latitude || !longitude || !start_date)
//     return res
//       .status(400)
//       .json({ error: "nick_name, lat, lng, start_date required" });

//   latitude = parseFloat(latitude);
//   longitude = parseFloat(longitude);
//   if (isNaN(latitude) || latitude < -90 || latitude > 90)
//     return res.status(400).json({ error: "Invalid latitude" });
//   if (isNaN(longitude) || longitude < -180 || longitude > 180)
//     return res.status(400).json({ error: "Invalid longitude" });

//   try {
//     const result = await dbRun(
//       `INSERT INTO location_master
//          (location_nick_name, latitude, longitude, start_date, end_date,
//           contact_person_name, contact_person_number)
//        VALUES (?,?,?,?,?,?,?)`,
//       [
//         nick_name.trim(),
//         latitude,
//         longitude,
//         start_date,
//         end_date || null,
//         contact_person_name?.trim() || null,
//         contact_person_number?.trim() || null,
//       ],
//     );
//     res
//       .status(201)
//       .json({ message: "Location added", location_id: result.insertId });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── EMPLOYEE LOCATION ASSIGNMENT ────────────────────────────────────────────
// app.get("/employee-assignments/:empId", async (req, res) => {
//   const empId = parseInt(req.params.empId, 10);
//   if (isNaN(empId))
//     return res.status(400).json({ error: "empId must be a number" });
//   try {
//     const rows = await dbAll(
//       `SELECT ela.assign_id, ela.emp_id,
//           CONCAT(e.first_name,' ',e.last_name) AS emp_name,
//           lm.location_nick_name AS location_name,
//           DATE(CONVERT_TZ(ela.start_date,'+00:00','+05:30')) AS start_date,
//           DATE(CONVERT_TZ(ela.end_date,  '+00:00','+05:30')) AS end_date,
//           ela.about_work, ela.status, ela.reason AS extend_reason, ela.done_by,
//           CASE
//             WHEN ela.status='Completed' THEN 'Completed'
//             WHEN ela.status='Relieved'  THEN 'Relieved'
//             WHEN ela.status='Extended'  THEN 'Extended'
//             WHEN DATE(CONVERT_TZ(ela.start_date,'+00:00','+05:30')) > CURDATE() THEN 'Future'
//             WHEN ela.status='Active' AND DATE(CONVERT_TZ(ela.end_date,'+00:00','+05:30')) < CURDATE()
//               THEN 'Not Completed'
//             ELSE 'Working'
//           END AS work_status
//        FROM employee_location_assignment ela
//        JOIN employee_master e  ON ela.emp_id      = e.emp_id
//        JOIN location_master lm ON ela.location_id = lm.location_id
//        WHERE ela.emp_id=? ORDER BY ela.start_date DESC`,
//       [empId],
//     );
//     res.json(rows);
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// app.post("/assign-location", async (req, res) => {
//   const { emp_id, location_id, about_work, start_date, end_date, done_by } =
//     req.body;
//   try {
//     await dbRun(
//       `INSERT INTO employee_location_assignment
//          (emp_id, location_id, about_work, start_date, end_date, status, done_by)
//        VALUES (?,?,?,?,?,'Active',?)`,
//       [emp_id, location_id, about_work, start_date, end_date, done_by],
//     );
//     res.json({ success: true, message: "Location assigned" });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// app.post("/update-work-status", async (req, res) => {
//   const { empId, status, updatedBy, reason, endDate } = req.body;
//   if (!empId || !status)
//     return res.status(400).json({ error: "empId and status required" });

//   const allowed = ["Completed", "Relieved", "Extended", "Active"];
//   if (!allowed.includes(status))
//     return res.status(400).json({ error: `Invalid status: ${status}` });

//   let sql = `UPDATE employee_location_assignment
//              SET status=?, reason=?, done_by=?, updated_at=NOW()`;
//   const params = [status, reason || null, updatedBy || null];

//   if (status === "Extended") {
//     if (!endDate) return res.status(400).json({ error: "endDate required" });
//     sql += `, end_date=?`;
//     params.push(endDate);
//   }
//   sql += ` WHERE emp_id=? ORDER BY assign_id DESC LIMIT 1`;
//   params.push(empId);

//   try {
//     const result = await dbRun(sql, params);
//     if (result.affectedRows === 0)
//       return res.status(404).json({ error: "No active assignment found" });
//     res.json({ success: true, message: `Status updated to ${status}` });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── ADMIN REQUESTS ───────────────────────────────────────────────────────────
// app.get("/admin/pending-requests", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT p.request_id, p.emp_id,
//           COALESCE(p.first_name, e.first_name) AS first_name,
//           COALESCE(p.last_name,  e.last_name)  AS last_name,
//           COALESCE(p.email_id,   e.email_id)   AS email_id,
//           COALESCE(p.department_id, e.department_id) AS department_id,
//           COALESCE(p.role_id,    e.role_id)    AS role_id,
//           p.admin_approve, p.request_type, p.edit_reason, p.reject_reason,
//           p.created_at, p.updated_at,
//           d.department_name, r.role_name
//        FROM employee_pending_request p
//        LEFT JOIN employee_master    e ON p.emp_id        = e.emp_id
//        LEFT JOIN department_master  d ON COALESCE(p.department_id, e.department_id) = d.department_id
//        LEFT JOIN role_master        r ON COALESCE(p.role_id,       e.role_id)       = r.role_id
//        WHERE p.admin_approve='PENDING'
//        ORDER BY p.created_at DESC`,
//     );
//     res.json(rows);
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// app.post("/admin/reject-request", async (req, res) => {
//   const { request_id, reject_reason } = req.body;
//   if (!request_id || !reject_reason)
//     return res
//       .status(400)
//       .json({ error: "request_id and reject_reason required" });
//   try {
//     await dbRun(
//       `UPDATE employee_pending_request
//        SET admin_approve='REJECTED', reject_reason=? WHERE request_id=?`,
//       [reject_reason, request_id],
//     );
//     res.json({ message: "Request rejected" });
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── ALL EMPLOYEES ────────────────────────────────────────────────────────────
// app.get("/all-employees", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT * FROM (
//          SELECT e.emp_id, e.first_name, e.mid_name, e.last_name,
//            e.email_id AS email, e.phone_number AS phone, e.date_of_birth, e.gender,
//            e.department_id, d.department_name, e.role_id, r.role_name,
//            e.date_of_joining, e.employment_type, e.work_type, e.status AS emp_status,
//            NULL AS admin_approve, NULL AS request_id, 'MASTER' AS source,
//            e.created_at, e.updated_at
//          FROM employee_master e
//          LEFT JOIN department_master d ON e.department_id=d.department_id
//          LEFT JOIN role_master r       ON e.role_id=r.role_id
//          UNION ALL
//          SELECT p.emp_id, p.first_name, p.mid_name, p.last_name,
//            p.email_id AS email, p.phone_number AS phone, p.date_of_birth, p.gender,
//            p.department_id, d2.department_name, p.role_id, r2.role_name,
//            p.date_of_joining, p.employment_type, p.work_type,
//            NULL AS emp_status, p.admin_approve, p.request_id, 'PENDING' AS source,
//            p.created_at, p.updated_at
//          FROM employee_pending_request p
//          LEFT JOIN department_master d2 ON p.department_id=d2.department_id
//          LEFT JOIN role_master r2       ON p.role_id=r2.role_id
//          WHERE p.admin_approve IN ('PENDING','REJECTED')
//        ) combined ORDER BY created_at DESC`,
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// // ─── LEAVE MANAGEMENT ─────────────────────────────────────────────────────────
// app.get("/leaves/pending-tl", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT l.leave_id, l.emp_id,
//           CONCAT(e.first_name,' ',e.last_name) AS employee_name,
//           d.department_name, r.role_name, l.leave_type,
//           l.leave_start_date, l.leave_end_date, l.number_of_days, l.reason, l.status,
//           IFNULL(SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END),0) AS taken_days
//        FROM leave_master l
//        JOIN employee_master e  ON l.emp_id=e.emp_id
//        LEFT JOIN department_master d ON e.department_id=d.department_id
//        LEFT JOIN role_master r       ON e.role_id=r.role_id
//        LEFT JOIN leave_master lm2
//          ON lm2.emp_id=l.emp_id AND lm2.leave_type=l.leave_type AND lm2.status='Approved'
//        WHERE l.status='Pending_TL'
//        GROUP BY l.leave_id ORDER BY l.created_at ASC`,
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.put("/leave/:leaveId/tl-action", async (req, res) => {
//   const { action, rejection_reason, login_id } = req.body;
//   if (!action || !login_id)
//     return res
//       .status(400)
//       .json({ success: false, message: "action and login_id required" });
//   if (!["recommend", "not_recommend"].includes(action))
//     return res.status(400).json({ success: false, message: "Invalid action" });

//   try {
//     const user = await dbGet(
//       `SELECT lm.login_id, r.role_name
//        FROM login_master lm JOIN role_master r ON lm.role_id=r.role_id
//        WHERE lm.login_id=? AND lm.status='Active'`,
//       [login_id],
//     );
//     if (!user)
//       return res.status(404).json({ success: false, message: "Invalid user" });

//     const tlRoles = ["TL", "Team Lead", "Team_Lead", "TeamLead"];
//     if (!tlRoles.includes(user.role_name))
//       return res
//         .status(403)
//         .json({ success: false, message: "Only TL can action" });

//     const newStatus = action === "recommend" ? "Pending_HR" : "Rejected_By_TL";
//     await dbRun(
//       `UPDATE leave_master
//        SET status=?, rejection_reason=?, recommended_by=?, recommended_at=?, updated_at=NOW()
//        WHERE leave_id=? AND status='Pending_TL'`,
//       [
//         newStatus,
//         action === "not_recommend" ? rejection_reason?.trim() : null,
//         action === "recommend" ? login_id : null,
//         action === "recommend" ? new Date() : null,
//         req.params.leaveId,
//       ],
//     );
//     res.json({ success: true, message: newStatus });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.put("/leave/:leaveId/hr-action", async (req, res) => {
//   const { status, rejection_reason, login_id } = req.body;
//   if (!status || !login_id)
//     return res
//       .status(400)
//       .json({ success: false, message: "status and login_id required" });
//   if (!["Approved", "Rejected_By_HR"].includes(status))
//     return res.status(400).json({ success: false, message: "Invalid status" });

//   try {
//     const user = await dbGet(
//       `SELECT lm.role_id FROM login_master lm WHERE lm.login_id=? AND lm.status='Active'`,
//       [login_id],
//     );
//     if (!user)
//       return res.status(404).json({ success: false, message: "Invalid user" });

//     const hrRoles = await dbAll(
//       `SELECT role_id FROM role_master WHERE LOWER(role_name) LIKE '%hr%' OR LOWER(role_name) LIKE '%admin%'`,
//     );
//     if (!hrRoles.some((r) => r.role_id === user.role_id))
//       return res
//         .status(403)
//         .json({ success: false, message: "Only HR/Admin can action" });

//     const result = await dbRun(
//       `UPDATE leave_master
//        SET status=?, approved_by=?, rejection_reason=?, updated_at=NOW()
//        WHERE leave_id=? AND status='Pending_HR'`,
//       [status, login_id, rejection_reason || null, req.params.leaveId],
//     );
//     if (result.affectedRows === 0)
//       return res
//         .status(400)
//         .json({ success: false, message: "Leave not in Pending_HR state" });
//     res.json({ success: true, message: status });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// app.get("/leaves/all-history", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT l.leave_id, l.emp_id,
//           CONCAT(e.first_name,' ',e.last_name) AS employee_name,
//           l.leave_type,
//           DATE_FORMAT(l.leave_start_date,'%Y-%m-%d') AS from_date,
//           DATE_FORMAT(l.leave_end_date,  '%Y-%m-%d') AS to_date,
//           l.number_of_days AS total_days, l.recommended_by, l.approved_by,
//           l.status, l.reason, l.rejection_reason, l.cancel_reason
//        FROM leave_master l
//        JOIN employee_master e ON l.emp_id=e.emp_id
//        ORDER BY l.updated_at DESC`,
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

// // ─── EDUCATION ────────────────────────────────────────────────────────────────
// app.get("/employees/:empId/education", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT edu_id, emp_id, education_level, stream, score,
//           year_of_passout, university, college_name, created_at
//        FROM education_details WHERE emp_id=?
//        ORDER BY FIELD(education_level,'10','12','Diploma','UG','PG','PhD') ASC`,
//       [req.params.empId],
//     );
//     res.json({ success: true, data: rows });
//   } catch (err) {
//     res.status(500).json({ success: false, error: err.message });
//   }
// });

// // ─── WORKING TODAY & FUTURE ───────────────────────────────────────────────────
// app.get("/working-today-and-future", async (req, res) => {
//   try {
//     const rows = await dbAll(
//       `SELECT a.assign_id, e.emp_id,
//           CONCAT(e.first_name,' ',e.last_name) AS emp_name,
//           l.location_nick_name AS location_name,
//           DATE_FORMAT(a.start_date,'%Y-%m-%d') AS start_date,
//           DATE_FORMAT(a.end_date,  '%Y-%m-%d') AS end_date,
//           a.about_work, a.status, a.reason AS extend_reason, a.done_by,
//           CASE
//             WHEN a.status='Completed' THEN 'Completed'
//             WHEN a.status='Relieved'  THEN 'Relieved'
//             WHEN a.status='Extended'  THEN 'Extended'
//             WHEN a.start_date > CURDATE() THEN 'Future'
//             WHEN a.status='Active' AND a.end_date < CURDATE() THEN 'Not Completed'
//             ELSE 'Working'
//           END AS work_status
//        FROM employee_location_assignment a
//        JOIN employee_master e  ON a.emp_id      = e.emp_id
//        JOIN location_master l  ON a.location_id = l.location_id
//        WHERE a.status IN ('Active','Extended')
//           OR (a.status='Relieved' AND a.end_date >= CURDATE())
//        ORDER BY a.start_date ASC`,
//     );
//     res.json(rows);
//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// });

// // ─── START SERVER ─────────────────────────────────────────────────────────────
// const PORT = process.env.PORT || 3000;
// app.listen(PORT, "0.0.0.0", () =>
//   console.log(`✅ Server running on http://0.0.0.0:${PORT}`),
// );
/**
 * Employee Attendance System — Express Server
 * Fixed issues:
 *  1. Added /auth/login route (was missing, ApiService called /auth/login)
 *  2. batch-sync now uses DATE(timestamp) instead of CURDATE() so offline
 *     events synced after midnight land on the correct work_date
 *  3. attendance/status returns correct state including cross-device "done"
 *  4. All routes use consistent error handling and response shapes
 */

const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");

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

// Promise wrappers — used throughout
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
// FIX: ApiService calls /auth/login — added this route alias
app.post("/auth/login", handleLogin);
app.post("/login", handleLogin);

async function handleLogin(req, res) {
  try {
    const loginId = req.body.login_id || req.body.username;
    const { password, device_id } = req.body;

    if (!loginId || !password)
      return res
        .status(400)
        .json({ message: "Login ID and password required" });

    const user = await dbGet(
      `SELECT login_id, emp_id, role_id, username, session_token, session_device
       FROM login_master
       WHERE TRIM(LOWER(username)) = TRIM(LOWER(?))
         AND password = ?
         AND status = 'Active'`,
      [loginId, password],
    );

    if (!user)
      return res.status(401).json({ message: "Invalid username or password" });

    // ✅ Block if already logged in on a DIFFERENT device
    if (
      user.session_token &&
      user.session_device &&
      user.session_device !== (device_id || "unknown")
    ) {
      return res.status(403).json({
        message: "Already logged in on another device. Please logout first.",
        alreadyLoggedIn: true,
      });
    }

    // ✅ Generate new session token
    const crypto = require("crypto");
    const sessionToken = crypto.randomUUID();

    // ✅ Update ALL columns: session_token, session_device, device_logged_in, last_login_at
    await dbRun(
      `UPDATE login_master 
       SET session_token = ?,
           session_device = ?,
           device_logged_in = 1,
           last_login_at = NOW(),
           updated_at = NOW()
       WHERE login_id = ?`,
      [sessionToken, device_id || "unknown", user.login_id],
    );

    res.json({
      loginId: user.login_id,
      empId: user.emp_id,
      roleId: user.role_id,
      username: user.username.trim(),
      sessionToken,
    });
  } catch (err) {
    console.error("[Login]", err);
    res.status(500).json({ message: "Server error" });
  }
}
// ─── LOGOUT ──────────────────────────────────────────────────────────────────
app.post("/auth/logout", async (req, res) => {
  const { login_id } = req.body;
  if (!login_id) return res.status(400).json({ message: "login_id required" });
  try {
    await dbRun(
      `UPDATE login_master 
       SET session_token = NULL,
           session_device = NULL,
           device_logged_in = 0,
           updated_at = NOW()
       WHERE login_id = ?`,
      [login_id],
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
    return res.status(400).json({ valid: false, message: "Missing fields" });
  try {
    const user = await dbGet(
      `SELECT session_token, session_device, device_logged_in 
       FROM login_master 
       WHERE login_id = ? AND status = 'Active'`,
      [login_id],
    );

    if (!user)
      return res.status(404).json({ valid: false, message: "User not found" });

    // ✅ Check token AND device match
    if (
      user.session_token !== session_token ||
      user.session_device !== (device_id || "unknown")
    ) {
      return res.status(401).json({
        valid: false,
        message: "Session invalid or logged in on another device",
      });
    }

    res.json({ valid: true });
  } catch (err) {
    res.status(500).json({ valid: false, message: "Server error" });
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
          DATE_FORMAT(e.date_of_birth,     '%Y-%m-%d') AS date_of_birth,
          DATE_FORMAT(e.date_of_joining,   '%Y-%m-%d') AS date_of_joining,
          DATE_FORMAT(e.date_of_relieving, '%Y-%m-%d') AS date_of_relieving
       FROM employee_master e
       LEFT JOIN department_master d ON e.department_id = d.department_id
       LEFT JOIN role_master r       ON e.role_id       = r.role_id
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

app.post("/employees/:empId/apply-leave", async (req, res) => {
  const { leave_type, leave_start_date, leave_end_date, reason } = req.body;
  if (!leave_type || !leave_start_date || !leave_end_date)
    return res
      .status(400)
      .json({ success: false, message: "Leave type and dates are required" });
  try {
    await dbRun(
      `INSERT INTO leave_master
         (emp_id, leave_type, leave_start_date, leave_end_date, reason, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, 'Pending_TL', NOW(), NOW())`,
      [
        req.params.empId,
        leave_type,
        leave_start_date,
        leave_end_date,
        reason || "",
      ],
    );
    res.json({ success: true, message: "Leave applied successfully" });
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

// ─── ATTENDANCE — STATUS ───────────────────────────────────────────────────────
/**
 * FIX: Returns correct tri-state:
 *   "not_started"  → no rows today
 *   "in_progress"  → has rows but NOT ended_manually
 *   "completed"    → last row is ended_manually
 */
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

// ─── ATTENDANCE — TODAY'S LOGS ────────────────────────────────────────────────
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

// ─── ATTENDANCE — MARK IN ────────────────────────────────────────────────────
app.post("/attendance/in", async (req, res) => {
  const { employee_id, site_id } = req.body;
  if (!employee_id || !site_id)
    return res
      .status(400)
      .json({ message: "employee_id and site_id required" });

  try {
    // GUARD: Block mark_in if the employee already ended their day
    const dayEnded = await dbGet(
      `SELECT id FROM employee_site_attendance
       WHERE employee_id=? AND work_date=CURDATE() AND status='ended_manually'
       LIMIT 1`,
      [employee_id],
    );
    if (dayEnded)
      return res.status(409).json({ message: "Day already ended for today" });

    // Verify site is active today
    const site = await dbGet(
      `SELECT id FROM sites WHERE id=? AND CURDATE() BETWEEN start_date AND end_date`,
      [site_id],
    );
    if (!site)
      return res.status(400).json({ message: "Site not active today" });

    // Close any open row at a DIFFERENT site
    await dbRun(
      `UPDATE employee_site_attendance
       SET out_time=NOW(), updated_at=NOW(), status='completed'
       WHERE employee_id=? AND site_id!=? AND work_date=CURDATE() AND out_time IS NULL`,
      [employee_id, site_id],
    );

    // Check current site's latest row today
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

// ─── ATTENDANCE — MARK OUT ───────────────────────────────────────────────────
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

// ─── ATTENDANCE — END DAY ────────────────────────────────────────────────────
app.post("/attendance/end-day", async (req, res) => {
  const { employee_id } = req.body;
  if (!employee_id)
    return res.status(400).json({ message: "employee_id required" });
  try {
    // GUARD: If already ended, return success (idempotent)
    const alreadyEnded = await dbGet(
      `SELECT id FROM employee_site_attendance
       WHERE employee_id=? AND work_date=CURDATE() AND status='ended_manually'
       LIMIT 1`,
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

// ─── ATTENDANCE — HEARTBEAT ──────────────────────────────────────────────────
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

// ─── ATTENDANCE — BATCH SYNC ─────────────────────────────────────────────────
/**
 * FIX: Uses DATE(timestamp) instead of CURDATE() so events recorded before
 * midnight are stored on the correct work_date even when synced late.
 * Also uses the event's own timestamp for in_time/out_time.
 */
app.post("/attendance/batch-sync", async (req, res) => {
  const { events } = req.body;
  if (!Array.isArray(events) || events.length === 0)
    return res.status(400).json({ message: "events array required" });

  const results = [];

  for (let i = 0; i < events.length; i++) {
    const e = events[i];
    const { type, employee_id, site_id, timestamp } = e;

    // Use the event's own timestamp; fall back to NOW() if missing
    const ts = timestamp || new Date().toISOString();
    const workDate = ts.slice(0, 10); // "YYYY-MM-DD"

    try {
      switch (type) {
        case "mark_in": {
          if (!employee_id || !site_id)
            throw new Error("mark_in requires employee_id and site_id");

          // GUARD: Skip mark_in if day already ended on that work_date
          const dayEnded = await dbGet(
            `SELECT id FROM employee_site_attendance
             WHERE employee_id=? AND work_date=? AND status='ended_manually'
             LIMIT 1`,
            [employee_id, workDate],
          );
          if (dayEnded) {
            results.push({ index: i, type, status: "skipped_day_ended" });
            break;
          }

          // Close open row at a different site on the same work_date
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
          // else: already open, nothing to do

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

// ─── ATTENDANCE — BY DATE (Admin) ────────────────────────────────────────────
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

// ─── EMPLOYEE WORK HOURS ─────────────────────────────────────────────────────
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
      dbAll(
        `SELECT COUNT(*) AS v FROM leave_master WHERE status='Pending' AND leave_start_date>=?`,
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
              FROM education_pending_request ep
              WHERE ep.request_id = p.request_id
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

// ─── LEAVE MANAGEMENT ─────────────────────────────────────────────────────────
app.get("/leaves/pending-tl", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT 
          l.leave_id,
          l.emp_id,
          CONCAT(e.first_name,' ',e.last_name) AS employee_name,
          d.department_name,
          r.role_name,
          l.leave_type,

          DATE_FORMAT(l.leave_start_date,'%d.%m.%Y') AS leave_start_date,
          DATE_FORMAT(l.leave_end_date,'%d.%m.%Y') AS leave_end_date,

          l.number_of_days,
          l.reason,
          l.status,

          IFNULL(
            SUM(CASE WHEN lm2.status='Approved' THEN lm2.number_of_days END),
            0
          ) AS taken_days

       FROM leave_master l

       JOIN employee_master e 
       ON l.emp_id = e.emp_id

       LEFT JOIN department_master d 
       ON e.department_id = d.department_id

       LEFT JOIN role_master r 
       ON e.role_id = r.role_id

       LEFT JOIN leave_master lm2
       ON lm2.emp_id = l.emp_id 
       AND lm2.leave_type = l.leave_type 
       AND lm2.status = 'Approved'

       WHERE l.status = 'Pending_TL'

       GROUP BY l.leave_id
       ORDER BY l.created_at ASC`,
    );

    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// app.put("/leave/:leaveId/tl-action", async (req, res) => {
//   const { action, rejection_reason, login_id } = req.body;
//   if (!action || !login_id)
//     return res
//       .status(400)
//       .json({ success: false, message: "action and login_id required" });
//   if (!["recommend", "not_recommend"].includes(action))
//     return res.status(400).json({ success: false, message: "Invalid action" });

//   try {
//     const user = await dbGet(
//       `SELECT lm.login_id, r.role_name
//        FROM login_master lm JOIN role_master r ON lm.role_id=r.role_id
//        WHERE lm.login_id=? AND lm.status='Active'`,
//       [login_id],
//     );
//     if (!user)
//       return res.status(404).json({ success: false, message: "Invalid user" });

//     const tlRoles = ["TL", "Team Lead", "Team_Lead", "TeamLead"];
//     if (!tlRoles.includes(user.role_name))
//       return res
//         .status(403)
//         .json({ success: false, message: "Only TL can action" });

//     const newStatus =
//       action === "recommend" ? "Pending_HR" : "Not_Recommended_By_TL";
//     await dbRun(
//       `UPDATE leave_master
//    SET status=?, rejection_reason=?, recommended_by=?, recommended_at=?, updated_at=NOW()
//    WHERE leave_id=? AND status='Pending_TL'`,
//       [
//         newStatus,
//         action === "not_recommend" ? rejection_reason?.trim() : null,
//         login_id, // ← always store TL's login_id (was: only on recommend)
//         new Date(), // ← always store timestamp (was: only on recommend)
//         req.params.leaveId,
//       ],
//     );
//     res.json({ success: true, message: newStatus });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// });

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
      action === "recommend" ? "Pending_HR" : "Not_Recommended_By_TL";

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
        login_id, // ← store TL login_id in approved_by
        req.params.leaveId,
      ],
    );

    res.json({ success: true, message: newStatus });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});
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
      `SELECT role_id FROM role_master WHERE LOWER(role_name) LIKE '%hr%' OR LOWER(role_name) LIKE '%admin%'`,
    );
    if (!hrRoles.some((r) => r.role_id === user.role_id))
      return res
        .status(403)
        .json({ success: false, message: "Only HR/Admin can action" });

    const result = await dbRun(
      `UPDATE leave_master
       SET status=?, approved_by=?, rejection_reason=?, updated_at=NOW()
       WHERE leave_id=? AND status='Pending_HR'`,
      [status, login_id, rejection_reason || null, req.params.leaveId],
    );
    if (result.affectedRows === 0)
      return res
        .status(400)
        .json({ success: false, message: "Leave not in Pending_HR state" });
    res.json({ success: true, message: status });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Get user info by emp_id (replaces login-user by loginId)
app.get("/employee-user/:empId", async (req, res) => {
  try {
    const u = await dbGet(
      `SELECT lm.login_id, lm.emp_id, lm.username, r.role_name,
          CONCAT(e.first_name,
            CASE WHEN e.mid_name IS NOT NULL AND e.mid_name != ''
              THEN CONCAT(' ', e.mid_name) ELSE '' END,
            ' ', e.last_name) AS full_name
       FROM login_master lm
       LEFT JOIN employee_master e ON lm.emp_id = e.emp_id
       LEFT JOIN role_master r ON lm.role_id = r.role_id
       WHERE lm.emp_id = ?`,
      [req.params.empId],
    );
    if (!u)
      return res.status(404).json({ success: false, message: "Not found" });
    res.json({
      success: true,
      emp_id: u.emp_id,
      login_id: u.login_id,
      full_name: u.full_name?.trim() || u.username,
      role_name: u.role_name || "-",
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

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
          -- TL who recommended or not-recommended
          CASE 
            WHEN l.recommended_by IS NOT NULL 
            THEN CONCAT(tl_emp.first_name,' ',tl_emp.last_name)
            ELSE NULL
          END AS recommended_by_name,
          -- HR who approved or rejected
          CASE 
            WHEN l.approved_by IS NOT NULL 
            THEN CONCAT(hr_emp.first_name,' ',hr_emp.last_name)
            ELSE NULL
          END AS approved_by_name
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       LEFT JOIN login_master tl_lm ON l.recommended_by = tl_lm.login_id
       LEFT JOIN employee_master tl_emp ON tl_lm.emp_id = tl_emp.emp_id
       LEFT JOIN login_master hr_lm ON l.approved_by = hr_lm.login_id
       LEFT JOIN employee_master hr_emp ON hr_lm.emp_id = hr_emp.emp_id
       ORDER BY l.updated_at DESC`,
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

// ─── WORKING TODAY & FUTURE ───────────────────────────────────────────────────
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

// ─── ATTENDANCE — BY DATE WITH LOCATION BREAKDOWN (Admin) ───────────────────
app.get("/attendance/by-date-detail", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          e.emp_id,
          TRIM(CONCAT(e.first_name, ' ', IFNULL(e.mid_name, ''), ' ', e.last_name)) AS name,
          s.site_name AS location_name,
          a.id AS visit_id,
          a.in_time,
          a.out_time,
          a.work_date,
          a.status,
          TIMESTAMPDIFF(MINUTE, a.in_time, IFNULL(a.out_time, NOW())) AS worked_minutes
       FROM employee_master e
       LEFT JOIN employee_site_attendance a ON e.emp_id = a.employee_id AND a.work_date = ?
       LEFT JOIN sites s ON a.site_id = s.id
       WHERE e.status = 'Active'
       ORDER BY e.emp_id ASC, a.in_time ASC`,
      [req.query.date],
    );

    // Group by employee
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

// ─── ALL PENDING LEAVES (TL + HR combined) ───────────────────────────────────
app.get("/leaves/all-pending", async (req, res) => {
  try {
    const rows = await dbAll(
      `SELECT
          l.leave_id, l.emp_id,
          CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
          d.department_name, r.role_name,
          l.leave_type, l.leave_start_date, l.leave_end_date,
          l.number_of_days, l.reason, l.status,
          l.recommended_by, l.recommended_at,
          IFNULL(SUM(CASE WHEN lm2.status = 'Approved' THEN lm2.number_of_days END), 0) AS taken_days,
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
          - IFNULL(SUM(CASE WHEN lm2.status = 'Approved' THEN lm2.number_of_days END), 0)
          ) AS remaining_days
       FROM leave_master l
       JOIN employee_master e ON l.emp_id = e.emp_id
       LEFT JOIN department_master d  ON e.department_id = d.department_id
       LEFT JOIN role_master r        ON e.role_id       = r.role_id
       LEFT JOIN leave_master lm2
         ON lm2.emp_id = l.emp_id
        AND lm2.leave_type = l.leave_type
        AND lm2.status = 'Approved'
       WHERE l.status IN ('Pending_TL', 'Pending_HR')
       GROUP BY l.leave_id
       ORDER BY l.created_at ASC`,
    );
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
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
    date_of_joining,
    employment_type,
    work_type,
    permanent_address,
    communication_address,
    aadhar_number,
    pan_number,
    passport_number,
    father_name,
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

  if (!["Male", "Female", "Other"].includes(gender))
    return res.status(400).json({ success: false, message: "Invalid gender" });
  if (!["Permanent", "Contract", "Intern"].includes(employment_type))
    return res
      .status(400)
      .json({ success: false, message: "Invalid employment_type" });
  if (!["Full Time", "Part Time"].includes(work_type))
    return res
      .status(400)
      .json({ success: false, message: "Invalid work_type" });

  const safe = (v) => (v && v.toString().trim() !== "" ? v : null);

  try {
    const result = await dbRun(
      `INSERT INTO employee_pending_request
        (first_name, mid_name, last_name, email_id, phone_number, date_of_birth, gender,
         department_id, role_id, date_of_joining, employment_type, work_type,
         permanent_address, communication_address, aadhar_number, pan_number, passport_number,
         father_name, emergency_contact, pf_number, esic_number, years_experience,
         admin_approve, username, password, request_type, created_at, updated_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'PENDING',?,?,'NEW',NOW(),NOW())`,
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
        date_of_joining,
        employment_type,
        work_type,
        permanent_address,
        safe(communication_address),
        safe(aadhar_number),
        safe(pan_number),
        safe(passport_number),
        safe(father_name),
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

  try {
    const request = await dbGet(
      "SELECT * FROM employee_pending_request WHERE request_id=?",
      [request_id],
    );
    if (!request) return res.status(404).json({ error: "Request not found" });

    if (request.request_type === "NEW") {
      // ── Duplicate check ────────────────────────────────────────────────────
      const dupEmail = await dbGet(
        "SELECT emp_id FROM employee_master WHERE email_id=?",
        [request.email_id],
      );
      if (dupEmail) {
        await dbRun(
          "UPDATE employee_pending_request SET admin_approve='REJECTED', reject_reason=? WHERE request_id=?",
          ["Duplicate email: " + request.email_id, request_id],
        );
        return res.status(409).json({
          error: "Duplicate email address — request auto-rejected.",
        });
      }

      const empResult = await dbRun("INSERT INTO employee_master SET ?", {
        first_name: request.first_name,
        mid_name: request.mid_name || null,
        last_name: request.last_name,
        email_id: request.email_id,
        phone_number: request.phone_number,
        date_of_birth: request.date_of_birth,
        gender: request.gender,
        department_id: request.department_id,
        role_id: request.role_id,
        date_of_joining: request.date_of_joining,
        date_of_relieving: request.date_of_relieving || null,
        employment_type: request.employment_type,
        work_type: request.work_type,
        permanent_address: request.permanent_address,
        communication_address: request.communication_address || null,
        aadhar_number: request.aadhar_number || null,
        pan_number: request.pan_number || null,
        passport_number: request.passport_number || null,
        father_name: request.father_name || null,
        emergency_contact: request.emergency_contact || null,
        pf_number: request.pf_number || null,
        esic_number: request.esic_number || null,
        years_experience:
          request.years_experience != null
            ? parseInt(request.years_experience)
            : null,
        status: "Active",
      });

      const empId = empResult.insertId;

      await dbRun(
        `INSERT INTO education_details
           (emp_id, education_level, stream, score, year_of_passout, university, college_name)
         SELECT ?, education_level, stream, score, year_of_passout, university, college_name
         FROM education_pending_request WHERE request_id=?`,
        [empId, request_id],
      );

      await dbRun("INSERT INTO login_master SET ?", {
        emp_id: empId,
        username: request.username,
        password: request.password,
        role_id: request.role_id,
        status: "Active",
      });

      await dbRun(
        "UPDATE employee_pending_request SET admin_approve='APPROVED', emp_id=? WHERE request_id=?",
        [empId, request_id],
      );
      await dbRun("DELETE FROM education_pending_request WHERE request_id=?", [
        request_id,
      ]);

      return res.json({
        message: "New employee approved successfully!",
        emp_id: empId,
      });
    } else if (request.request_type === "UPDATE") {
      if (!request.emp_id)
        return res
          .status(400)
          .json({ error: "emp_id missing for update request" });

      const dorValue =
        request.status === "Relieved"
          ? request.date_of_relieving || null
          : null;

      await dbRun("UPDATE employee_master SET ? WHERE emp_id=?", [
        {
          first_name: request.first_name,
          mid_name: request.mid_name || null,
          last_name: request.last_name,
          email_id: request.email_id,
          phone_number: request.phone_number,
          date_of_birth: request.date_of_birth,
          gender: request.gender,
          department_id: request.department_id,
          role_id: request.role_id,
          date_of_joining: request.date_of_joining,
          date_of_relieving: dorValue,
          employment_type: request.employment_type,
          work_type: request.work_type,
          permanent_address: request.permanent_address,
          communication_address: request.communication_address || null,
          aadhar_number: request.aadhar_number || null,
          pan_number: request.pan_number || null,
          passport_number: request.passport_number || null,
          father_name: request.father_name || null,
          emergency_contact: request.emergency_contact || null,
          pf_number: request.pf_number || null,
          esic_number: request.esic_number || null,
          years_experience:
            request.years_experience != null
              ? parseInt(request.years_experience)
              : null,
          status: request.status || "Active",
        },
        request.emp_id,
      ]);

      await dbRun(
        "UPDATE login_master SET role_id=?, status=? WHERE emp_id=?",
        [request.role_id, request.status || "Active", request.emp_id],
      );

      await dbRun("DELETE FROM education_details WHERE emp_id=?", [
        request.emp_id,
      ]);
      await dbRun(
        `INSERT INTO education_details
           (emp_id, education_level, stream, score, year_of_passout, university, college_name)
         SELECT ?, education_level, stream, score, year_of_passout, university, college_name
         FROM education_pending_request WHERE request_id=?`,
        [request.emp_id, request_id],
      );

      await dbRun(
        "UPDATE employee_pending_request SET admin_approve='APPROVED' WHERE request_id=?",
        [request_id],
      );
      await dbRun("DELETE FROM education_pending_request WHERE request_id=?", [
        request_id,
      ]);

      return res.json({ message: "Employee update approved successfully!" });
    } else {
      return res
        .status(400)
        .json({ error: "Unknown request type: " + request.request_type });
    }
  } catch (err) {
    console.error("[approve-request]", err);
    res.status(500).json({ error: err.message });
  }
});
// ─── START SERVER ─────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(` Server running on http://0.0.0.0:${PORT}`),
);
