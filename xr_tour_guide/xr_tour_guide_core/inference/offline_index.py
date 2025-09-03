import base64
import cv2
import numpy as np
from typing import Dict, List, Tuple, Optional
from PIL import Image
import io
import torch
import torchvision.models as models
import torchvision.transforms as transforms

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")


def _get_extractor_and_transform():
    """Carica il modello di estrazione delle feature e la pipeline di trasformazione."""
    model = models.resnet50(weights=models.ResNet50_Weights.DEFAULT)
    feature_extractor = torch.nn.Sequential(*list(model.children())[:-1])
    feature_extractor.eval()
    feature_extractor.to(device)

    transform = transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ]
    )
    return feature_extractor, transform

def _compute_embedding(img_bytes: bytes, extractor, transform) -> Optional[List[float]]:
    try:
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        t = transform(img).unsqueeze(0).to(device)
        with torch.no_grad():
            emb = extractor(t).flatten()
        return emb.tolist()
    except Exception as e:
        return None
    
def _compute_orb(img_bytes: bytes) -> Tuple[List[List[float]], Optional[str], int, int]:
    img = np.frombuffer(img_bytes, np.uint8)
    gray = cv2.imdecode(img , cv2.IMREAD_GRAYSCALE)
    if gray is None:
        return [], None, 0, 0
    orb = cv2.ORB_create(nfeatures=5000)
    kps, des = orb.detectAndCompute(gray, None)
    if des is None or len(kps) == 0:
        return [], None, 0, 0
    kp_xy = [[float(k.pt[0]), float(k.pt[1])] for k in kps]
    desc_b64 = base64.b64encode(des.tobytes()).decode('ascii')
    return kp_xy, desc_b64, des.shape[0], des.shape[1]

def build_offline_index(tour_id: int, fetch_images_fn) -> Dict:
    data = {
        "tour_id": tour_id,
        "version": 1,
        "waypoints": []
    }
    
    extractor, transform = _get_extractor_and_transform()
    
    return data

def build_waypoint_entry(waypoint_id: int, images_payload: List[Dict], extractor, transform) -> Dict:
    waypoint_entry = {
        "waypoint_id": waypoint_id,
        "images": []
    }
    
    for img in images_payload:
        img_bytes = img["bytes"]
        kp_xy, desc_b64, rows, cols = _compute_orb(img_bytes)
        if not kp_xy or not desc_b64:
            continue
        emb = _compute_embedding(img_bytes, extractor, transform)
        
        waypoint_entry["images"].append(
            {
                "file": img["file"],
                "kp": kp_xy,
                "desc": desc_b64,
                "rows": rows,
                "cols": cols,
                "emb": emb
            }
        )
    return waypoint_entry
