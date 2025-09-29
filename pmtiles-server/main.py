from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from minio import Minio
from minio.error import S3Error
import os
import subprocess

app = FastAPI()

MINIO_URL = os.getenv("MINIO_URL", "minio:9000")
MINIO_USER = os.getenv("MINIO_ROOT_USER")
MINIO_PASSWORD = os.getenv("MINIO_ROOT_PASSWORD")
MINIO_BUCKET = os.getenv("AWS_STORAGE_BUCKET_NAME", "pmtiles")

client = Minio(
    MINIO_URL,
    access_key=MINIO_USER,
    secret_key=MINIO_PASSWORD,
    secure=False
)

class ExtractRequest(BaseModel):
    tour_id: str
    bbox: str  # "min_lon,min_lat,max_lon,max_lat"

@app.post("/extract")
async def extract_pmtiles(data: ExtractRequest):
    input_path = "/maps/salerno_provincia.pmtiles"
    output_path = f"/data/tour_{data.tour_id}.pmtiles"

    if not os.path.exists(input_path):
        raise HTTPException(status_code=404, detail="Input PMTiles file not found")

    try:
        subprocess.run([
            "/usr/local/bin/go-pmtiles",
            "extract",
            input_path,
            output_path,
            "--bbox", data.bbox
        ], check=True)
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Failed to extract PMTiles: {e}")

    try:
        client.fput_object(
            f"{MINIO_BUCKET}",
            f"{data.tour_id}/tour_{data.tour_id}.pmtiles",
            output_path
        )
    except S3Error as err:
        raise HTTPException(status_code=500, detail=f"Failed to upload to MinIO: {err}")

    return {"file": f"tour_{data.tour_id}.pmtiles"}
