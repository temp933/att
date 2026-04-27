const express = require("express");
const multer = require("multer");
const axios = require("axios");
const FormData = require("form-data");
const cors = require("cors");

const app = express();
app.use(cors());

const upload = multer({ storage: multer.memoryStorage() });
const FLASK_URL = "http://127.0.0.1:5000";

app.post("/api/compare", upload.single("image"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "No image uploaded" });

    const form = new FormData();
    form.append("image", req.file.buffer, {
      filename: "image.jpg",
      contentType: "image/jpeg",
    });

    const response = await axios.post(`${FLASK_URL}/compare`, form, {
      headers: form.getHeaders(),
      timeout: 15000,
    });

    return res.json(response.data);
  } catch (err) {
    const msg = err.response?.data?.error || err.message;
    console.error("Error:", msg);
    return res.status(500).json({ error: msg });
  }
});

app.listen(3000, "0.0.0.0", () => console.log("Node running on port 3000"));
