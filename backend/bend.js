// bend.js

const express = require("express");
const multer = require("multer");
const tf = require("@tensorflow/tfjs"); // ✅ correct
const faceapi = require("face-api.js");
const canvas = require("canvas");
const mysql = require("mysql2/promise");

const { Canvas, Image, ImageData } = canvas;
faceapi.env.monkeyPatch({ Canvas, Image, ImageData });

const app = express();
const upload = multer({ storage: multer.memoryStorage() });

// ✅ MySQL connection
const db = mysql.createPool({
  host: "localhost",
  user: "root",
  password: "2026",
  database: "kavidhan",
});

// ✅ Helpers (MySQL FIX)
const dbAll = async (query) => {
  const [rows] = await db.query(query);
  return rows;
};

const dbRun = async (query, params) => {
  const [result] = await db.query(query, params);
  return result;
};

// 🔥 INIT TensorFlow (VERY IMPORTANT)
async function initTF() {
  await tf.setBackend("cpu");
  await tf.ready();
  console.log("✅ TF Ready");
}

// 🔥 Load models
async function loadModels() {
  await faceapi.nets.ssdMobilenetv1.loadFromDisk("./models");
  await faceapi.nets.faceLandmark68Net.loadFromDisk("./models");
  await faceapi.nets.faceRecognitionNet.loadFromDisk("./models");

  console.log("✅ Models Loaded");
}

// 🧠 Convert image → descriptor
async function getDescriptor(buffer) {
  try {
    const img = await canvas.loadImage(buffer);

    const detection = await faceapi
      .detectSingleFace(img)
      .withFaceLandmarks()
      .withFaceDescriptor();

    if (!detection) return null;

    return Array.from(detection.descriptor);
  } catch (err) {
    console.log("❌ Descriptor error:", err.message);
    return null;
  }
}

// 🧬 Generate descriptors
app.get("/generate", async (req, res) => {
  try {
    const rows = await dbAll(`SELECT id, emp_id, profile_photo FROM pic_ck`);

    console.log("Total rows:", rows.length);

    for (let row of rows) {
      console.log("Processing emp:", row.emp_id);

      if (!row.profile_photo) {
        console.log("❌ No image for", row.emp_id);
        continue;
      }

      const descriptor = await getDescriptor(row.profile_photo);

      if (!descriptor) {
        console.log(`❌ No face detected for ${row.emp_id}`);
        continue;
      }

      await dbRun(
        `UPDATE pic_ck 
         SET face_descriptor=?, face_detected=1 
         WHERE id=?`,
        [JSON.stringify(descriptor), row.id],
      );

      console.log(`✅ Done ${row.emp_id}`);
    }

    res.send("✅ Descriptors generated");
  } catch (e) {
    console.log("🔥 ERROR:", e);
    res.send("Error generating descriptors");
  }
});

// 🎯 Recognize face
app.post("/recognize-face", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.json({ success: false, message: "No image uploaded" });
    }

    const input = await getDescriptor(req.file.buffer);

    if (!input) {
      return res.json({ success: false, message: "No face detected" });
    }

    const rows = await dbAll(`
      SELECT emp_id, face_descriptor 
      FROM pic_ck 
      WHERE face_descriptor IS NOT NULL
    `);

    let best = null;
    let min = 1;

    for (let row of rows) {
      const stored = JSON.parse(row.face_descriptor);
      const dist = faceapi.euclideanDistance(input, stored);

      if (dist < min) {
        min = dist;
        best = row;
      }
    }

    if (best && min < 0.45) {
      return res.json({
        success: true,
        emp_id: best.emp_id,
        distance: min,
      });
    }

    res.json({ success: false, message: "No match" });
  } catch (e) {
    console.log("🔥 ERROR:", e);
    res.json({ success: false, error: e.message });
  }
});

// 🚀 START SERVER (FIXED FLOW)
(async () => {
  await initTF(); // ✅ REQUIRED
  await loadModels(); // ✅ REQUIRED

  app.listen(3000, "0.0.0.0", () => {
    console.log("🚀 Server running on 3000");
  });
})();
