from flask import Flask, request, jsonify
from deepface import DeepFace
from scipy.spatial.distance import cosine
import numpy as np
import tempfile
import os

app = Flask(__name__)

REFERENCE_IMAGE = r"C:\Users\LENOVO\Downloads\bala.png"
THRESHOLD = 0.65

print("Loading reference embedding...")
ref = DeepFace.represent(
    img_path=REFERENCE_IMAGE,
    model_name="ArcFace",
    enforce_detection=False,
    align=True
)[0]["embedding"]
ref_embedding = np.array(ref)
ref_embedding = ref_embedding / np.linalg.norm(ref_embedding)
print("✅ Reference embedding loaded!")


def get_embedding(img_path):
    # Try strict detection first (face must be found clearly)
    try:
        result = DeepFace.represent(
            img_path=img_path,
            model_name="ArcFace",
            enforce_detection=True,   # strict — rejects blurry/no-face frames
            align=True,
            detector_backend="retinaface"  # best detector
        )
        emb = np.array(result[0]["embedding"])
        return emb / np.linalg.norm(emb), True  # (embedding, face_detected)
    except:
        return None, False  # face not clearly detected — reject this frame


@app.route("/compare", methods=["POST"])
def compare():
    file = request.files.get("image")
    if not file:
        return jsonify({"error": "No image"}), 400

    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
        file.save(tmp.name)
        tmp_path = tmp.name

    try:
        live, detected = get_embedding(tmp_path)

        if not detected:
            print("⚠️  No clear face detected — frame rejected")
            return jsonify({
                "match": False,
                "distance": None,
                "error": "No clear face detected. Look directly at camera."
            })

        distance = cosine(ref_embedding, live)
        match = distance < THRESHOLD

        print(f"Distance: {distance:.4f} → {'✅ MATCH' if match else '❌ NO MATCH'}")
        return jsonify({"match": bool(match), "distance": round(float(distance), 6)})

    finally:
        os.unlink(tmp_path)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)