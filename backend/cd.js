const nodemailer = require("nodemailer");
const crypto = require("crypto");

// ── Configure your SMTP (edit these values) ───────────────────────────────────
const mailer = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: parseInt(process.env.SMTP_PORT || "465"),
  secure: true, // true for port 465
  auth: {
    user: process.env.SMTP_USER || "your-noreply@kavidhan.com",
    pass: process.env.SMTP_PASS || "your-app-password",
  },
});

// Base URL where the candidate web form is hosted (e.g. your Express server or Netlify)
const CANDIDATE_FORM_BASE_URL =
  process.env.CANDIDATE_FORM_URL || "http://192.168.29.216:3000";


app.post("/hr/invite-candidate", async (req, res) => {
  const { candidate_name, email, phone, invited_by } = req.body;

  if (
    !candidate_name?.trim() ||
    !email?.trim() ||
    !phone?.trim() ||
    !invited_by
  ) {
    return res.status(400).json({
      success: false,
      message: "candidate_name, email, phone and invited_by are required",
    });
  }

  // Basic email format check
  const emailRx = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRx.test(email.trim())) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid email format" });
  }

  // Phone: digits only, 10 chars
  const phoneClean = phone.trim().replace(/\D/g, "");
  if (phoneClean.length < 10) {
    return res
      .status(400)
      .json({ success: false, message: "Invalid phone number" });
  }

  try {
    // Check if this email already exists in employee_master or has a PENDING invite
    const existingEmp = await dbGet(
      `SELECT emp_id FROM employee_master WHERE email_id = ?`,
      [email.trim()],
    );
    if (existingEmp) {
      return res.status(409).json({
        success: false,
        message: "This email is already registered as an employee",
      });
    }

    const existingInvite = await dbGet(
      `SELECT invite_id, status FROM candidate_invites
       WHERE email = ? AND status = 'PENDING' AND expires_at > NOW()`,
      [email.trim()],
    );
    if (existingInvite) {
      return res.status(409).json({
        success: false,
        message:
          "An active invite already exists for this email. Wait for it to expire or ask the candidate to check their inbox.",
      });
    }

    // Generate a secure 48-char hex token
    const token = crypto.randomBytes(24).toString("hex");
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // +24 hrs

    await dbRun(
      `INSERT INTO candidate_invites
         (token, candidate_name, email, phone, invited_by, status, expires_at)
       VALUES (?, ?, ?, ?, ?, 'PENDING', ?)`,
      [
        token,
        candidate_name.trim(),
        email.trim(),
        phoneClean,
        invited_by,
        expiresAt,
      ],
    );

    const formLink = `${CANDIDATE_FORM_BASE_URL}/candidate-form?token=${token}`;

    // ── Send email ────────────────────────────────────────────────────────────
    await mailer.sendMail({
      from: `"Kavidhan HR" <${process.env.SMTP_USER || "noreply@yourdomain.com"}>`,
      to: email.trim(),
      subject: "Complete Your Employee Onboarding — Action Required",
      html: _buildInviteEmailHtml(candidate_name.trim(), formLink),
    });

    res.json({
      success: true,
      message: `Invite sent to ${email.trim()}. Link expires in 24 hours.`,
      token, // useful for testing; remove in production if you prefer
    });
  } catch (err) {
    console.error("[invite-candidate]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. Validate Token (candidate opens the link)
//    GET /candidate/validate-token?token=xxx
// ─────────────────────────────────────────────────────────────────────────────
app.get("/candidate/validate-token", async (req, res) => {
  const { token } = req.query;
  if (!token)
    return res.status(400).json({ valid: false, message: "Token missing" });

  try {
    const invite = await dbGet(
      `SELECT invite_id, candidate_name, email, phone, status, expires_at
       FROM candidate_invites WHERE token = ?`,
      [token],
    );

    if (!invite) {
      return res.json({
        valid: false,
        reason: "invalid",
        message: "This link is invalid.",
      });
    }
    if (invite.status === "SUBMITTED") {
      return res.json({
        valid: false,
        reason: "submitted",
        message: "You have already submitted your details.",
      });
    }
    if (
      invite.status === "EXPIRED" ||
      new Date(invite.expires_at) < new Date()
    ) {
      // Mark expired if not already
      await dbRun(
        `UPDATE candidate_invites SET status='EXPIRED' WHERE token=?`,
        [token],
      );
      return res.json({
        valid: false,
        reason: "expired",
        message: "This invitation link has expired. Please contact HR.",
      });
    }

    res.json({
      valid: true,
      candidate_name: invite.candidate_name,
      email: invite.email,
      phone: invite.phone,
      expires_at: invite.expires_at,
    });
  } catch (err) {
    res.status(500).json({ valid: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 3. Candidate submits the form
//    POST /candidate/submit-form
//    Body: { token, ...all employee fields, education: [] }
// ─────────────────────────────────────────────────────────────────────────────
app.post("/candidate/submit-form", async (req, res) => {
  const { token, ...formData } = req.body;
  if (!token)
    return res.status(400).json({ success: false, message: "Token missing" });

  try {
    // ── 1. Validate token ─────────────────────────────────────────────────────
    const invite = await dbGet(
      `SELECT * FROM candidate_invites WHERE token = ?`,
      [token],
    );
    if (!invite) {
      return res.status(400).json({ success: false, message: "Invalid token" });
    }
    if (invite.status !== "PENDING") {
      return res.status(400).json({
        success: false,
        message:
          invite.status === "SUBMITTED"
            ? "You have already submitted. Please wait for admin approval."
            : "This invitation link has expired.",
      });
    }
    if (new Date(invite.expires_at) < new Date()) {
      await dbRun(
        `UPDATE candidate_invites SET status='EXPIRED' WHERE token=?`,
        [token],
      );
      return res.status(400).json({
        success: false,
        message: "Invitation link has expired. Contact HR.",
      });
    }

    // ── 2. Uniqueness checks ──────────────────────────────────────────────────
    const checks = [
      { field: "email_id", value: formData.email_id, label: "Email" },
      {
        field: "phone_number",
        value: formData.phone_number,
        label: "Phone number",
      },
      {
        field: "aadhar_number",
        value: formData.aadhar_number,
        label: "Aadhar number",
      },
      { field: "pan_number", value: formData.pan_number, label: "PAN number" },
    ];

    for (const c of checks) {
      if (!c.value || c.value.toString().trim() === "") continue;
      const dup = await dbGet(
        `SELECT emp_id FROM employee_master WHERE ${c.field} = ?`,
        [c.value.trim()],
      );
      if (dup) {
        return res.status(409).json({
          success: false,
          field: c.field,
          message: `${c.label} is already registered. Please verify and try again.`,
        });
      }
    }

    // ── 3. Validate required fields ───────────────────────────────────────────
    const required = [
      "first_name",
      "last_name",
      "email_id",
      "phone_number",
      "date_of_birth",
      "gender",
      "department_id",
      "role_id",
      "date_of_joining",
      "employment_type",
      "work_type",
      "permanent_address",
      "aadhar_number",
      "pan_number",
    ];
    const missing = required.filter(
      (k) => !formData[k] || formData[k].toString().trim() === "",
    );
    if (missing.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Missing required fields: ${missing.join(", ")}`,
      });
    }

    const safe = (v) => (v && v.toString().trim() !== "" ? v : null);
    const safeInt = (v) => (v != null && v !== "" ? parseInt(v) : null);

    // ── 4. Insert into employee_pending_request ───────────────────────────────
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
        formData.first_name,
        safe(formData.mid_name),
        formData.last_name,
        formData.email_id,
        formData.phone_number,
        formData.date_of_birth,
        formData.gender,
        safeInt(formData.department_id),
        safeInt(formData.role_id),
        safeInt(formData.tl_id),
        formData.date_of_joining,
        formData.employment_type,
        formData.work_type,
        formData.permanent_address,
        safe(formData.communication_address),
        safe(formData.aadhar_number),
        safe(formData.pan_number),
        safe(formData.passport_number),
        safe(formData.father_name),
        safe(formData.emergency_contact_relation),
        safe(formData.emergency_contact),
        safe(formData.pf_number),
        safe(formData.esic_number),
        safeInt(formData.years_experience),
        // username = email prefix, temp password = phone number
        formData.email_id.split("@")[0],
        formData.phone_number,
      ],
    );

    const requestId = result.insertId;

    // Education records
    const education = Array.isArray(formData.education)
      ? formData.education
      : [];
    if (education.length > 0) {
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

    // ── 5. Mark invite as submitted ───────────────────────────────────────────
    await dbRun(
      `UPDATE candidate_invites
       SET status='SUBMITTED', submitted_at=NOW(), request_id=?
       WHERE token=?`,
      [requestId, token],
    );

    // ── 6. Send confirmation email to candidate ───────────────────────────────
    try {
      await mailer.sendMail({
        from: `"Kavidhan HR" <${process.env.SMTP_USER}>`,
        to: formData.email_id,
        subject: "We received your details — Pending Admin Review",
        html: _buildConfirmationEmailHtml(formData.first_name),
      });
    } catch (mailErr) {
      console.warn("[submit-form] confirmation email failed:", mailErr.message);
      // Don't fail the request just because of email
    }

    res.json({
      success: true,
      message:
        "Details submitted successfully! You will be notified once approved.",
      request_id: requestId,
    });
  } catch (err) {
    console.error("[submit-form]", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 4. HR — Get all invites (to track status)
//    GET /hr/invites?invited_by=emp_id
// ─────────────────────────────────────────────────────────────────────────────
app.get("/hr/invites", async (req, res) => {
  const { invited_by } = req.query;
  try {
    const where = invited_by ? "WHERE ci.invited_by = ?" : "";
    const params = invited_by ? [invited_by] : [];
    const rows = await dbAll(
      `SELECT ci.*,
          CONCAT(e.first_name, ' ', e.last_name) AS invited_by_name
       FROM candidate_invites ci
       LEFT JOIN employee_master e ON ci.invited_by = e.emp_id
       ${where}
       ORDER BY ci.created_at DESC`,
      params,
    );
    // Auto-expire stale PENDING invites in response
    const now = new Date();
    const enriched = rows.map((r) => ({
      ...r,
      status:
        r.status === "PENDING" && new Date(r.expires_at) < now
          ? "EXPIRED"
          : r.status,
    }));
    res.json({ success: true, data: enriched });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// 5. Serve the candidate HTML form  (static file route)
//    GET /candidate-form?token=xxx  → serves candidate_form.html
// ─────────────────────────────────────────────────────────────────────────────
const path = require("path");
app.get("/candidate-form", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "candidate_form.html"));
});
// Make sure to: app.use(express.static(path.join(__dirname, 'public')));
// Add that line near the top of server.js after app.use(express.json())

// ─────────────────────────────────────────────────────────────────────────────
// Email HTML builders
// ─────────────────────────────────────────────────────────────────────────────
function _buildInviteEmailHtml(candidateName, formLink) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Employee Onboarding Invitation</title>
</head>
<body style="margin:0;padding:0;background:#F0F4FF;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0F4FF;padding:40px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:580px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(26,86,219,0.12);">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#1A56DB 0%,#1E3A8A 60%,#1e1b4b 100%);padding:36px 40px;text-align:center;">
            <div style="display:inline-block;background:rgba(255,255,255,0.15);border-radius:12px;padding:10px 20px;margin-bottom:16px;">
              <span style="color:#fff;font-size:18px;font-weight:700;letter-spacing:1px;">KAVIDHAN</span>
            </div>
            <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;line-height:1.3;">
              You're Invited to Join Us 🎉
            </h1>
            <p style="margin:8px 0 0;color:rgba(255,255,255,0.7);font-size:13px;">
              Employee Onboarding — Action Required
            </p>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="padding:36px 40px;">
            <p style="margin:0 0 16px;color:#0F172A;font-size:15px;font-weight:600;">
              Hello ${candidateName},
            </p>
            <p style="margin:0 0 20px;color:#64748B;font-size:14px;line-height:1.7;">
              Our HR team has initiated your onboarding process at <strong>Kavidhan</strong>.
              Please click the button below to complete your employee details form.
            </p>

            <!-- Info box -->
            <div style="background:#EEF2FF;border-radius:10px;padding:16px 20px;margin-bottom:28px;border-left:4px solid #1A56DB;">
              <p style="margin:0;color:#1E3A8A;font-size:13px;font-weight:600;">⏰ Important</p>
              <p style="margin:6px 0 0;color:#3730A3;font-size:13px;line-height:1.6;">
                This link is valid for <strong>24 hours only</strong>. After that, you will need to
                contact HR for a new invite.
              </p>
            </div>

            <!-- CTA Button -->
            <div style="text-align:center;margin:0 0 32px;">
              <a href="${formLink}"
                 style="display:inline-block;background:linear-gradient(135deg,#1A56DB,#1E3A8A);color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;padding:14px 40px;border-radius:10px;letter-spacing:0.3px;">
                Complete My Details →
              </a>
            </div>

            <p style="margin:0 0 8px;color:#94A3B8;font-size:12px;">
              Or copy this link into your browser:
            </p>
            <p style="margin:0;background:#F8FAFF;border:1px solid #E2E8F0;border-radius:8px;padding:10px 12px;word-break:break-all;font-size:12px;color:#1A56DB;">
              ${formLink}
            </p>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background:#F8FAFF;border-top:1px solid #E2E8F0;padding:20px 40px;text-align:center;">
            <p style="margin:0;color:#94A3B8;font-size:12px;line-height:1.6;">
              This is an automated message from Kavidhan HR System. Please do not reply to this email.<br>
              If you did not expect this invitation, please ignore this email.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function _buildConfirmationEmailHtml(firstName) {
  return `
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Submission Received</title></head>
<body style="margin:0;padding:0;background:#F0F4FF;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0F4FF;padding:40px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(26,86,219,0.1);">
        <tr>
          <td style="background:linear-gradient(135deg,#0E9F6E,#065F46);padding:32px 40px;text-align:center;">
            <div style="font-size:40px;margin-bottom:8px;">✅</div>
            <h1 style="margin:0;color:#fff;font-size:20px;font-weight:700;">Details Received!</h1>
            <p style="margin:6px 0 0;color:rgba(255,255,255,0.75);font-size:13px;">Pending admin approval</p>
          </td>
        </tr>
        <tr>
          <td style="padding:32px 40px;">
            <p style="margin:0 0 14px;color:#0F172A;font-size:15px;font-weight:600;">Hi ${firstName},</p>
            <p style="margin:0 0 20px;color:#64748B;font-size:14px;line-height:1.7;">
              Thank you for completing your employee details form. Your information has been successfully submitted
              and is now awaiting review by our admin team.
            </p>
            <div style="background:#ECFDF5;border-radius:10px;padding:16px 20px;border-left:4px solid #0E9F6E;margin-bottom:20px;">
              <p style="margin:0;color:#065F46;font-size:13px;line-height:1.6;">
                You will receive a confirmation once your profile has been approved.
                If you have any questions, please reach out to your HR contact directly.
              </p>
            </div>
          </td>
        </tr>
        <tr>
          <td style="background:#F8FAFF;border-top:1px solid #E2E8F0;padding:18px 40px;text-align:center;">
            <p style="margin:0;color:#94A3B8;font-size:12px;">
              This is an automated message. Please do not reply to this email.
            </p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}
