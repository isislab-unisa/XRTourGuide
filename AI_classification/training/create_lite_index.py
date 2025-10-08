# V1 ######################################################
# import base64
# import json
# from pathlib import Path
# import cv2
# import numpy as np
# from tensorflow import lite as tflite
# from PIL import Image


# INPUT_SIZE = 224
# MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
# STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


# def load_interpreter(tflite_path: Path) -> tflite.Interpreter:
#     interpreter = tflite.Interpreter(model_path=str(tflite_path))
#     interpreter.allocate_tensors()
#     return interpreter


# def preprocess_image_dart_compatible(pil_img: Image.Image) -> np.ndarray:
#     """Replica il preprocessing di _preprocessImage in Dart."""
#     pil_img = pil_img.convert("RGB")
#     w, h = pil_img.size
#     shortest = min(w, h)

#     if shortest == 0:
#         pil_img = pil_img.resize((INPUT_SIZE, INPUT_SIZE), Image.BICUBIC)
#     else:
#         scale = 256 / shortest
#         new_w, new_h = int(w * scale), int(h * scale)
#         pil_img = pil_img.resize((new_w, new_h), Image.BICUBIC)

#         crop_x = (new_w - INPUT_SIZE) // 2
#         crop_y = (new_h - INPUT_SIZE) // 2
#         pil_img = pil_img.crop(
#             (crop_x, crop_y, crop_x + INPUT_SIZE, crop_y + INPUT_SIZE)
#         )
    
#     img_array = np.array(pil_img, dtype=np.float32)
#     return img_array



# def run_embedder(interpreter: tflite.Interpreter, image: np.ndarray) -> np.ndarray:
#     input_details = interpreter.get_input_details()[0]
#     output_details = interpreter.get_output_details()[0]

#     print(f"Expected input shape: {input_details['shape']}")

#     # Normalizza con ImageNet mean/std
#     mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
#     std = np.array([0.229, 0.224, 0.225], dtype=np.float32)

#     # Image è HWC [224, 224, 3]
#     # Normalizza pixel per pixel mantenendo HWC
#     image_norm = (image / 255.0 - mean) / std

#     # Verifica se il modello vuole NHWC o NCHW
#     expected_shape = input_details["shape"]

#     if expected_shape[1] == 3:  # NCHW format [1, 3, 224, 224]
#         image_norm = np.transpose(image_norm, (2, 0, 1))  # HWC → CHW
#         tensor = np.expand_dims(image_norm, axis=0).astype(input_details["dtype"])
#     else:  # NHWC format [1, 224, 224, 3]
#         tensor = np.expand_dims(image_norm, axis=0).astype(input_details["dtype"])

#     print(f"Tensor shape: {tensor.shape}, dtype: {tensor.dtype}")
#     print(f"First 30 normalized values: {tensor.flatten()[:30]}")

#     interpreter.set_tensor(input_details["index"], tensor)
#     interpreter.invoke()
#     embedding = interpreter.get_tensor(output_details["index"]).squeeze()

#     norm = np.linalg.norm(embedding)
#     print(f"Embedding norm: {norm:.6f}")
#     embedding = (embedding / norm) if norm > 1e-6 else embedding
#     print(f"First 10 values: {embedding[:10]}")

#     return embedding.astype(np.float32)

# def rebuild_index(
#     embedder_path: Path,
#     dataset_root: str,
#     output_path: Path,
#     existing_index_path: Path,
# ) -> None:
#     interpreter = load_interpreter(embedder_path)

#     with existing_index_path.open("r", encoding="utf-8") as f:
#         entries = json.load(f)

#     print(f"Dataset root: {dataset_root}")
#     new_entries = []
#     for entry in entries:
#         image_path = Path(dataset_root + entry["image_path"])
#         print(f"Processing: {image_path}")
#         if not image_path.exists():
#             print(f"[WARN] Immagine mancante: {image_path}")
#             continue

#         image = Image.open(image_path)
#         processed = preprocess_image_dart_compatible(image)
#         print(f"Shape: {processed.shape}, Range: [{processed.min():.3f}, {processed.max():.3f}]")
#         embedding = run_embedder(interpreter, processed).tolist()

#         descriptors_b64 = entry.get("descriptors_b64", "")
#         keypoints = entry.get("keypoints", [])
#         desc_rows = entry.get("desc_rows", 0)
#         desc_cols = entry.get("desc_cols", 0)

#         new_entries.append(
#             {
#                 "waypoint_name": entry["waypoint_name"],
#                 "image_path": entry["image_path"],
#                 "embedding": embedding,
#                 "keypoints": keypoints,
#                 "desc_rows": desc_rows,
#                 "desc_cols": desc_cols,
#                 "descriptors_b64": descriptors_b64,
#             }
#         )

#     output_path.parent.mkdir(parents=True, exist_ok=True)
#     with output_path.open("w", encoding="utf-8") as f:
#         json.dump(new_entries, f, ensure_ascii=False, indent=2)

#     print(f"[OK] Nuovo index salvato in {output_path} con {len(new_entries)} immagini")


# if __name__ == "__main__":
#     rebuild_index(
#         embedder_path=Path("resnet50.tflite"),
#         dataset_root="/mnt/c/Users/andal/Downloads/3/3/",
#         output_path=Path("new_index.json"),
#         existing_index_path=Path("training_data.json"),
#     )
    
# V2 ######################################################
# create_lite_index.py (MODIFIED VERSION)

# import json
# from pathlib import Path
# import numpy as np
# from tensorflow import lite as tflite
# from PIL import Image

# INPUT_SIZE = 224
# MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
# STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


# def load_interpreter(tflite_path: Path) -> tflite.Interpreter:
#     interpreter = tflite.Interpreter(model_path=str(tflite_path))
#     interpreter.allocate_tensors()
#     return interpreter


# def preprocess_image(pil_img: Image.Image) -> np.ndarray:
#     """Preprocesses the image to be identical to the Dart implementation."""
#     pil_img = pil_img.convert("RGB")
#     w, h = pil_img.size
#     shortest = min(w, h)

#     # 1. Resize
#     scale = 256 / shortest
#     # Use round() to match Dart's behavior
#     new_w, new_h = round(w * scale), round(h * scale)
#     pil_img = pil_img.resize((new_w, new_h), Image.BICUBIC)
#     print(f"  [Py] Resized shape: ({new_w}, {new_h})")

#     # 2. Center Crop
#     crop_x = round((new_w - INPUT_SIZE) / 2)
#     crop_y = round((new_h - INPUT_SIZE) / 2)
#     pil_img = pil_img.crop((crop_x, crop_y, crop_x + INPUT_SIZE, crop_y + INPUT_SIZE))

#     img_array = np.array(pil_img, dtype=np.float32)

#     # --- DEBUG LOGGING ---
#     # Print the first 10 RGB pixels of the cropped image
#     pixels_flat = img_array.reshape(-1, 3)
#     print(f"  [Py] First 10 cropped RGB pixels:\n{pixels_flat[:10].astype(int)}")

#     return img_array


# def run_embedder(
#     interpreter: tflite.Interpreter, image_array: np.ndarray
# ) -> np.ndarray:
#     input_details = interpreter.get_input_details()[0]
#     output_details = interpreter.get_output_details()[0]

#     # 3. Normalize
#     image_norm = (image_array / 255.0 - MEAN) / STD

#     # --- DEBUG LOGGING ---
#     print(f"  [Py] First 30 normalized values:\n{image_norm.flatten()[:30]}")

#     # 4. Prepare Tensor
#     tensor = np.expand_dims(image_norm, axis=0).astype(input_details["dtype"])

#     interpreter.set_tensor(input_details["index"], tensor)
#     interpreter.invoke()
#     embedding = interpreter.get_tensor(output_details["index"]).squeeze()

#     # 5. L2 Normalize Embedding
#     norm = np.linalg.norm(embedding)
#     if norm > 1e-6:
#         embedding = embedding / norm

#     print(f"  [Py] Embedding norm: {norm:.6f}")
#     print(f"  [Py] First 10 embedding values:\n{embedding[:10]}")

#     return embedding.astype(np.float32)


# def rebuild_index(
#     embedder_path: Path,
#     dataset_root: str,
#     output_path: Path,
#     existing_index_path: Path,
# ) -> None:
#     # ... (rest of the function is the same, just calls the new functions)
#     interpreter = load_interpreter(embedder_path)
#     with existing_index_path.open("r", encoding="utf-8") as f:
#         entries = json.load(f)
#     print(f"Dataset root: {dataset_root}")
#     new_entries = []
#     for entry in entries:
#         image_path = Path(dataset_root + entry["image_path"])
#         print(f"\nProcessing: {image_path}")
#         if not image_path.exists():
#             print(f"[WARN] Immagine mancante: {image_path}")
#             continue
#         image = Image.open(image_path)
#         processed_array = preprocess_image(image)
#         embedding = run_embedder(interpreter, processed_array).tolist()
#         # ... (rest of the loop is the same)
#         new_entries.append(
#             {
#                 "waypoint_name": entry["waypoint_name"],
#                 "image_path": entry["image_path"],
#                 "embedding": embedding,
#                 # ... other keys
#             }
#         )
#     output_path.parent.mkdir(parents=True, exist_ok=True)
#     with output_path.open("w", encoding="utf-8") as f:
#         json.dump(new_entries, f, ensure_ascii=False, indent=2)
#     print(
#         f"\n[OK] Nuovo index salvato in {output_path} con {len(new_entries)} immagini"
#     )


# if __name__ == "__main__":
#     rebuild_index(
#         embedder_path=Path("resnet50.tflite"),  # Make sure this path is correct
#         dataset_root="/mnt/c/Users/andal/Downloads/3/3/",  # Make sure this path is correct
#         output_path=Path("new_index.json"),
#         existing_index_path=Path(
#             "training_data.json"
#         ),  # Make sure this path is correct
#     )

## V3 ######################################################
import json
import base64
from pathlib import Path
import numpy as np
import cv2
from tensorflow import lite as tflite
from PIL import Image
import argparse

INPUT_SIZE = 224
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def load_interpreter(tflite_path: Path) -> tflite.Interpreter:
    """Carica l'interprete TFLite."""
    interpreter = tflite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()

    # Debug info
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    print(f"Model input shape: {input_details['shape']}")
    print(f"Model output shape: {output_details['shape']}")

    return interpreter


def preprocess_image(pil_img: Image.Image) -> np.ndarray:
    """Replica ESATTAMENTE il preprocessing di _preprocessImage in Dart."""
    pil_img = pil_img.convert("RGB")
    w, h = pil_img.size
    shortest = min(w, h)

    # 1. Resize con scala 256/shortest (identico a Dart)
    scale = 256 / shortest
    new_w, new_h = round(w * scale), round(h * scale)
    pil_img = pil_img.resize((new_w, new_h), Image.BICUBIC)
    print(f"  [Py] Resized shape: ({new_w}, {new_h})")

    # 2. Center Crop (identico a Dart)
    crop_x = round((new_w - INPUT_SIZE) / 2)
    crop_y = round((new_h - INPUT_SIZE) / 2)
    pil_img = pil_img.crop((crop_x, crop_y, crop_x + INPUT_SIZE, crop_y + INPUT_SIZE))

    img_array = np.array(pil_img, dtype=np.float32)

    # Debug: primi 10 pixel RGB
    pixels_flat = img_array.reshape(-1, 3)
    print(f"  [Py] First 10 cropped RGB pixels:\n{pixels_flat[:10].astype(int)}")

    return img_array


def run_embedder(
    interpreter: tflite.Interpreter, image_array: np.ndarray
) -> np.ndarray:
    """Estrae embedding usando TFLite (identico a Dart)."""
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    # 3. Normalize (identico a Dart)
    image_norm = (image_array / 255.0 - MEAN) / STD
    print(f"  [Py] First 30 normalized values:\n{image_norm.flatten()[:30]}")

    # 4. Prepare Tensor NHWC [1, 224, 224, 3]
    tensor = np.expand_dims(image_norm, axis=0).astype(input_details["dtype"])

    # 5. Run inference
    interpreter.set_tensor(input_details["index"], tensor)
    interpreter.invoke()
    embedding = interpreter.get_tensor(output_details["index"]).squeeze()

    # 6. L2 Normalize (identico a Dart)
    norm = np.linalg.norm(embedding)
    if norm > 1e-6:
        embedding = embedding / norm

    print(f"  [Py] Embedding norm: {norm:.6f}")
    print(f"  [Py] Embedding length: {len(embedding)}")
    print(f"  [Py] First 10 embedding values:\n{embedding[:10]}")

    return embedding.astype(np.float32)


def compute_orb_features_dart_compatible(image_path: Path):
    """
    Calcola feature ORB identiche a quelle in offline_recognition_service.dart.
    Replica esattamente la logica di cv.ORB.create(nFeatures: 5000).
    """
    try:
        # Carica immagine come fa OpenCV Dart
        img = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if img is None:
            print(f"  [Py] Failed to load image: {image_path}")
            return [], np.array([]), 0, 0

        # Converti a grayscale (come in Dart)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # Crea ORB con STESSI parametri di Dart: nFeatures=5000
        orb = cv2.ORB_create(nfeatures=5000)

        # Rileva keypoints e descriptors
        kp, desc = orb.detectAndCompute(gray, None)

        if desc is None or len(kp) == 0:
            print(f"  [Py] No ORB features found for: {image_path}")
            return [], np.array([]), 0, 0

        # Converte keypoints nel formato compatibile con Dart
        # Dart usa: dbKps[m.trainIdx] dove dbKps è List<List<double>> con [x, y]
        kp_coords = [[float(k.pt[0]), float(k.pt[1])] for k in kp]

        # Descriptors come matrice uint8 (identico a Dart)
        desc = desc.astype(np.uint8)
        rows, cols = desc.shape

        print(f"  [Py] ORB features: {len(kp)} keypoints, {rows}x{cols} descriptors")

        return kp_coords, desc, rows, cols

    except Exception as e:
        print(f"  [Py] Error computing ORB features for {image_path}: {e}")
        return [], np.array([]), 0, 0


def create_training_index(
    tflite_model_path: Path, dataset_root: Path, output_json: Path, tour_id: int = 3
):
    """
    Crea un indice di training compatibile con offline_recognition_service.dart
    usando lo stesso modello TFLite dell'app mobile.
    """
    print(f"🚀 Creating training index for tour {tour_id}")
    print(f"   Model: {tflite_model_path}")
    print(f"   Dataset: {dataset_root}")
    print(f"   Output: {output_json}")

    # Carica modello TFLite
    interpreter = load_interpreter(tflite_model_path)

    index = []
    processed_count = 0

    # Itera su tutte le cartelle waypoint
    for waypoint_dir in sorted(dataset_root.iterdir()):
        if not waypoint_dir.is_dir():
            continue

        waypoint_name = waypoint_dir.name
        print(f"\n📁 Processing waypoint: {waypoint_name}")

        # Itera su tutte le immagini della cartella
        for img_path in sorted(waypoint_dir.glob("*.jpg")):
            try:
                print(f"  📷 Processing: {img_path.name}")

                # 1. Estrai embedding con TFLite (identico a Dart)
                pil_image = Image.open(img_path)
                processed_array = preprocess_image(pil_image)
                embedding = run_embedder(interpreter, processed_array)

                # 2. Estrai feature ORB (identico a Dart)
                kp_coords, descriptors, desc_rows, desc_cols = (
                    compute_orb_features_dart_compatible(img_path)
                )

                # 3. Prepara descriptors per JSON (base64 encoding)
                descriptors_b64 = ""
                if desc_rows > 0 and desc_cols > 0 and descriptors.size > 0:
                    descriptors_b64 = base64.b64encode(descriptors.tobytes()).decode(
                        "utf-8"
                    )

                # 4. Crea entry compatibile con offline_recognition_service.dart
                # Struttura identica a train_script.py ma con keypoints formato Dart
                entry = {
                    "waypoint_name": waypoint_name,
                    "image_path": str(
                        img_path.relative_to(dataset_root.parent)
                    ),  # Path relativo
                    "embedding": embedding.tolist(),
                    "keypoints": [
                        [coord, 0, 0, 0, 0, 0, 0] for coord in kp_coords
                    ],  # Formato train_script
                    "desc_rows": desc_rows,
                    "desc_cols": desc_cols,
                    "descriptors_b64": descriptors_b64,
                }

                index.append(entry)
                processed_count += 1
                print(f"    ✅ Embedded: {len(embedding)}D, ORB: {len(kp_coords)} kpts")

            except Exception as e:
                print(f"    ❌ Error processing {img_path.name}: {e}")
                continue

    # Salva indice JSON
    output_json.parent.mkdir(parents=True, exist_ok=True)
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Training index created successfully!")
    print(f"   📊 Processed: {processed_count} images")
    print(f"   💾 Saved to: {output_json}")
    print(f"   🎯 Tour ID: {tour_id}")

    return index


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Crea indice di training usando TFLite e ORB features compatibili con Dart"
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=Path("resnet50.tflite"),
        help="Path al modello TFLite (stesso dell'app mobile)",
    )
    parser.add_argument(
        "--dataset",
        type=Path,
        default=Path("/mnt/c/Users/andal/Downloads/3/3/data/3/train"),
        help="Path alla cartella dataset con waypoints",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("training_data.json"),
        help="Path di output per l'indice JSON",
    )
    parser.add_argument("--tour-id", type=int, default=3, help="ID del tour")

    args = parser.parse_args()

    # Verifica che i path esistano
    if not args.model.exists():
        raise FileNotFoundError(f"Modello TFLite non trovato: {args.model}")

    if not args.dataset.exists():
        raise FileNotFoundError(f"Dataset non trovato: {args.dataset}")

    # Crea l'indice
    create_training_index(
        tflite_model_path=args.model,
        dataset_root=args.dataset,
        output_json=args.output,
        tour_id=args.tour_id,
    )