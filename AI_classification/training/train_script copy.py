import os
import json
import base64
from pathlib import Path

import argparse
import numpy as np
import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
from tqdm import tqdm
import cv2
from tensorflow import lite as tflite

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

INPUT_SIZE = 224
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def load_tflite_interpreter(tflite_path: Path) -> tflite.Interpreter:
    interpreter = tflite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    print(f"TFLite input shape: {input_details['shape']}")
    print(f"TFLite output shape: {output_details['shape']}")
    return interpreter


def preprocess_image_dart_compatible(pil_img: Image.Image) -> np.ndarray:
    pil_img = pil_img.convert("RGB")
    w, h = pil_img.size
    shortest = min(w, h)
    scale = 256 / shortest
    new_w, new_h = round(w * scale), round(h * scale)
    pil_img = pil_img.resize((new_w, new_h), Image.BICUBIC)
    crop_x = round((new_w - INPUT_SIZE) / 2)
    crop_y = round((new_h - INPUT_SIZE) / 2)
    pil_img = pil_img.crop((crop_x, crop_y, crop_x + INPUT_SIZE, crop_y + INPUT_SIZE))
    return np.array(pil_img, dtype=np.float32)


def run_tflite_embedder(
    interpreter: tflite.Interpreter, image_array: np.ndarray
) -> np.ndarray:
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    image_norm = (image_array / 255.0 - MEAN) / STD
    tensor = np.expand_dims(image_norm, axis=0).astype(input_details["dtype"])
    interpreter.set_tensor(input_details["index"], tensor)
    interpreter.invoke()
    embedding = interpreter.get_tensor(output_details["index"]).squeeze()
    norm = np.linalg.norm(embedding)
    if norm > 1e-6:
        embedding = embedding / norm
    return embedding.astype(np.float32)


def compute_orb_features_dart_compatible(image_path: Path):
    img = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
    if img is None:
        return [], np.array([]), 0, 0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    orb = cv2.ORB_create(nfeatures=5000)
    kp, desc = orb.detectAndCompute(gray, None)
    if desc is None or len(kp) == 0:
        return [], np.array([]), 0, 0
    kp_coords = [[float(k.pt[0]), float(k.pt[1])] for k in kp]
    desc = desc.astype(np.uint8)
    rows, cols = desc.shape
    return kp_coords, desc, rows, cols


def create_training_index_with_tflite(
    tflite_model_path: Path,
    dataset_root: Path,
    output_json: Path,
    tour_id: int,
):
    print(f"\n🚀 Generating TFLite-based index for tour {tour_id}")
    interpreter = load_tflite_interpreter(tflite_model_path)
    index = []
    processed = 0

    for waypoint_dir in sorted(dataset_root.iterdir()):
        if not waypoint_dir.is_dir():
            continue
        waypoint_name = waypoint_dir.name
        print(f"\n📁 Waypoint: {waypoint_name}")
        for img_path in sorted(waypoint_dir.glob("*.jpg")):
            try:
                pil_image = Image.open(img_path)
                processed_array = preprocess_image_dart_compatible(pil_image)
                embedding = run_tflite_embedder(interpreter, processed_array)
                kp_coords, descriptors, rows, cols = (
                    compute_orb_features_dart_compatible(img_path)
                )
                descriptors_b64 = ""
                if rows > 0 and cols > 0 and descriptors.size > 0:
                    descriptors_b64 = base64.b64encode(descriptors.tobytes()).decode(
                        "utf-8"
                    )
                entry = {
                    "waypoint_name": waypoint_name,
                    "image_path": str(img_path.relative_to(dataset_root.parent)),
                    "embedding": embedding.tolist(),
                    "keypoints": [[coord, 0, 0, 0, 0, 0, 0] for coord in kp_coords],
                    "desc_rows": rows,
                    "desc_cols": cols,
                    "descriptors_b64": descriptors_b64,
                }
                index.append(entry)
                processed += 1
                print(
                    f"  ✅ {img_path.name}: emb {len(embedding)}, kpts {len(kp_coords)}"
                )
            except Exception as e:
                print(f"  ❌ {img_path.name}: {e}")

    output_json.parent.mkdir(parents=True, exist_ok=True)
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    print(f"\n✅ TFLite index saved to {output_json} ({processed} images)")


def get_embedding_extractor():
    model = models.resnet50(weights=models.ResNet50_Weights.DEFAULT)
    feature_extractor = torch.nn.Sequential(*list(model.children())[:-1])
    feature_extractor.eval()
    return feature_extractor


def get_image_transform():
    return transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ]
    )


def extract_embedding(image_path, model, transform):
    try:
        image = Image.open(image_path).convert("RGB")
        image_t = transform(image).unsqueeze(0).to(device)
        with torch.no_grad():
            embedding = model(image_t)
            embedding = embedding.flatten()
        return embedding
    except Exception as e:
        print(f"Errore durante l'elaborazione di {image_path}: {e}")
        return None


def compute_orb_features(image_path):
    try:
        img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
        if img is None:
            return None, None
        orb = cv2.ORB_create(nfeatures=5000)
        kp, des = orb.detectAndCompute(img, None)
        return kp, des
    except Exception as e:
        print(f"Errore durante il calcolo delle feature ORB per {image_path}: {e}")
        return None, None


def _save_index_json(index, json_path):
    out = []
    for item in index:
        emb = item["embedding"]
        if isinstance(emb, torch.Tensor):
            emb = emb.detach().cpu().numpy()
        emb_list = emb.astype(np.float32).reshape(-1).tolist()

        kps = item.get("keypoints", [])

        des = item.get("descriptors")
        if isinstance(des, torch.Tensor):
            des = des.detach().cpu().numpy()
        if des is None:
            rows, cols = 0, 0
            des_b64 = ""
        else:
            des = des.astype(np.uint8)
            if des.ndim == 2:
                rows, cols = int(des.shape[0]), int(des.shape[1])
            else:
                rows, cols = 0, 0
            des_b64 = base64.b64encode(des.tobytes()).decode("ascii")

        out.append(
            {
                "waypoint_name": item["waypoint_name"],
                "image_path": item["image_path"],
                "embedding": emb_list,
                "keypoints": kps,
                "descriptors_b64": des_b64,
                "desc_rows": rows,
                "desc_cols": cols,
            }
        )

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)


def index_waypoints(waypoints_dir, model, transform, cache_path, json_path):
    print("Indicizzazione delle immagini dei waypoint con PyTorch...")
    index = []
    waypoint_folders = [
        d
        for d in os.listdir(waypoints_dir)
        if os.path.isdir(os.path.join(waypoints_dir, d))
    ]

    for waypoint_name in tqdm(waypoint_folders, desc="Waypoints"):
        folder_path = os.path.join(waypoints_dir, waypoint_name)
        for image_name in os.listdir(folder_path):
            if image_name.lower().endswith((".png", ".jpg", ".jpeg")):
                image_path = os.path.join(folder_path, image_name)
                embedding = extract_embedding(image_path, model, transform)
                kp, des = compute_orb_features(image_path)

                if embedding is not None and des is not None:
                    kp_serializable = [
                        (p.pt, p.size, p.angle, p.response, p.octave, p.class_id)
                        for p in kp
                    ]
                    index.append(
                        {
                            "waypoint_name": waypoint_name,
                            "image_path": image_path,
                            "embedding": embedding.cpu(),
                            "keypoints": kp_serializable,
                            "descriptors": des,
                        }
                    )
    print(f"Indicizzazione completata. Trovate {len(index)} immagini.")
    torch.save(index, cache_path)
    print(f"Indice salvato in: {cache_path}")

    if json_path:
        _save_index_json(index, json_path)
        print(f"Indice JSON salvato in: {json_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Estrae embedding e feature geometriche dalle immagini di training."
    )
    parser.add_argument(
        "--input-dir", required=True, help="Percorso della cartella di training."
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Cartella in cui salvare i risultati (model.pt, training_data.json).",
    )
    parser.add_argument(
        "--tflite-model",
        required=True,
        help="Percorso al modello TFLite usato nell'app mobile.",
    )
    parser.add_argument(
        "--tour-id",
        type=int,
        default=3,
        help="ID del tour per cui si genera l'indice.",
    )
    parser.add_argument(
        "--skip-pytorch",
        action="store_true",
        help="Se impostato, salta la generazione dell'indice PyTorch.",
    )

    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    train_dir = input_dir / "train"
    pt_cache_path = output_dir / "model.pt"
    json_path = output_dir / "training_data.json"

    output_dir.mkdir(parents=True, exist_ok=True)

    create_training_index_with_tflite(
        tflite_model_path=Path(args.tflite_model),
        dataset_root=train_dir,
        output_json=json_path,
        tour_id=args.tour_id,
    )

    if not args.skip_pytorch:
        extractor = get_embedding_extractor().to(device)
        transform = get_image_transform()
        index_waypoints(
            str(train_dir),
            extractor,
            transform,
            str(pt_cache_path),
            str(output_dir / "training_data_pytorch.json"),
        )

    print("Done.")
