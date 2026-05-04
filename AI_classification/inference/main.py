import sys
import os
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = CURRENT_DIR.parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import boto3
from urllib.parse import urlparse
import shutil
import requests
import threading
import subprocess
import base64
from fastapi.responses import JSONResponse
import dotenv

dotenv.load_dotenv()

MINIO_ENDPOINT = os.getenv("AWS_S3_ENDPOINT_URL")
CALLBACK_ENDPOINT = os.getenv("CALLBACK_ENDPOINT")

class CustomHTTPException(HTTPException):
    def __init__(self, status_code: int, detail: str, error_code: int):
        super().__init__(status_code=status_code, detail=detail)
        self.error_code = error_code


class Response(BaseModel):
    model_url: str | None = None
    report_url: str | None = None
    view_name: str | None = None
    poi_id: str | None = None
    message: str | None = None


class Request(BaseModel):
    data_url: str | None = None
    inference_image: str | None = None
    model_url: str | None = None
    index_url: str | None = None
    poi_name: str | None = None
    poi_id: str | None = None
    skip_geometry: bool | None = False
    gps_lat: float | None = None
    gps_lon: float | None = None
    gps_accuracy_m: float | None = None


app = FastAPI()

# origins = ["http://localhost", "http://localhost:8000", "*"]

# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )


s3 = boto3.client(
    "s3",
    endpoint_url=MINIO_ENDPOINT,
    aws_access_key_id=os.getenv("MINIO_ROOT_USER"),
    aws_secret_access_key=os.getenv("MINIO_ROOT_PASSWORD"),
)

def download_minio_folder(prefix: str, local_dir: str, s3_client):
    """
    Downloads all objects from `bucket_name` under `prefix` to `local_dir`,
    preserving the folder hierarchy.
    """
    print(f"Downloading {prefix} to {local_dir}")
    paginator = s3_client.get_paginator(
        "list_objects_v2"
    )  # Handles pagination :contentReference[oaicite:3]{index=3}
    for page in paginator.paginate(
        Bucket=os.getenv("AWS_STORAGE_BUCKET_NAME"), Prefix=prefix
    ):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.endswith("/"):
                # Skip zero-byte “folder” markers
                continue

            # Derive the local path by stripping the prefix
            rel_path = os.path.relpath(key, prefix)
            local_path = os.path.join(local_dir, rel_path)

            # Ensure the target directory exists
            os.makedirs(os.path.dirname(local_path), exist_ok=True)

            # Download the object to the local path
            s3_client.download_file(
                os.getenv("AWS_STORAGE_BUCKET_NAME"), key, local_path
            )
            print(f"Downloaded {key} → {local_path}")
    return local_dir

def read_s3_file(file_name):
    try:
        video_key = file_name
        response = s3.get_object(
            Bucket=os.getenv("AWS_STORAGE_BUCKET_NAME"), Key=video_key
        )
        # print("RESPONSE:" + str(response))
        data = response["Body"].read()
        return data, video_key
    except Exception as e:
        print(f"Error reading file from S3: {e}")
        return None


def write_s3_file(file_path, remote_path):
    try:
        s3.upload_file(
            file_path,
            os.getenv("AWS_STORAGE_BUCKET_NAME"),
            remote_path,
        )
        print(f"File {remote_path} written to S3")
    except Exception as e:
        print(f"Error writing file {file_path} to S3: {e}")


@app.get("/")
async def read_root():
    return {"Hello": "World"}    

def _stream_output(stream, prefix=""):
    for line in iter(stream.readline, ""):
        if line:
            print(f"{prefix}{line.rstrip()}", flush=True)
    stream.close()    

@app.post("/inference")
async def inference(request: Request):
    try:
        # body = await request.json()
        model_url = request.index_url or request.model_url
        poi_name = request.poi_name
        poi_id = request.poi_id
        input_image_b64 = request.inference_image
        
        skip_geometry = bool(request.skip_geometry) if request.skip_geometry is not None else False

        print(f"Requested model: {model_url}", flush=True)

        model, key = read_s3_file(model_url)
        if model is None:
            raise CustomHTTPException(
                status_code=404, detail="Model not found", error_code=1003
            )

        model_dir = os.path.join("/models", poi_name)
        os.makedirs(model_dir, exist_ok=True)
        
        model_path = os.path.join(model_dir, "training_data.json")
        with open(model_path, "wb") as f:
            f.write(model)
            
        print("MODEL DOWNLOADED", flush=True)

        if not input_image_b64:
            raise CustomHTTPException(
                status_code=404, detail="Image not found", error_code=1004
            )

        def decode_base64_image(data: str) -> bytes:
            if data.startswith("data:"):
                data = data.split(",")[1]
            missing_padding = len(data) % 4
            if missing_padding:
                data += "=" * (4 - missing_padding)
            return base64.b64decode(data)

        try:
            input_image_bytes = decode_base64_image(input_image_b64)
        except Exception as e:
            print("Error decoding base64 image:", e, flush=True)
            raise CustomHTTPException(
                status_code=400, detail="Invalid base64 image", error_code=1005
            )

        data_dir = os.path.join("/data", poi_name)
        os.makedirs(data_dir, exist_ok=True)
        image_path = os.path.join(data_dir, "input_image.jpg")
        with open(image_path, "wb") as f:
            f.write(input_image_bytes)
        print("DATA DOWNLOADED", flush=True)
        
        tflite_model_path = str(CURRENT_DIR / "./EfficientNetLite0.tflite")
        
        inference_script = CURRENT_DIR / "inference_script.py"

        cmd = [
            "python",
            "-u",
            str(inference_script),
            "--image-path", image_path,
            "--index-json", model_path,
            "--tflite-model", tflite_model_path,
        ]
        
        if request.gps_lat is not None and request.gps_lon is not None:
            cmd.extend([
                "--gps-lat", str(request.gps_lat),
                "--gps-lon", str(request.gps_lon),
            ])
            
            if request.gps_accuracy_m is not None:
                cmd.extend(["--gps-accuracy-m", str(request.gps_accuracy_m)])
        
        if skip_geometry:
            cmd.append("--skip-geometry")
        
        print(f"Running command: {' '.join(cmd)}", flush=True)
        
        # result_proc = subprocess.run(cmd, capture_output=True, text=True, cwd=str(CURRENT_DIR))
        # print(result_proc.stdout, flush=True)
        
        proc = subprocess.Popen(
            cmd,
            cwd=str(CURRENT_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        stdout_lines = []
        stderr_lines = []
        
        stdout_thread = threading.Thread(
            target=_stream_output,
            args=(proc.stdout, "Inference output: ", stdout_lines),
            daemon=True
        )
        stderr_thread = threading.Thread(
            target=_stream_output,
            args=(proc.stderr, "Inference error output: ", stderr_lines),
            daemon=True
        )
        
        stdout_thread.start()
        stderr_thread.start()
        
        returncode = proc.wait()
        
        stdout_thread.join()
        stderr_thread.join()
        
        result_str = "\n".join(stdout_lines).strip()
        result_err = "\n".join(stderr_lines).strip()

        if returncode != 0:
            print("Inference failed:", result_err, flush=True)
            raise CustomHTTPException(
                status_code=500,
                detail=f"Inference failed: {result_err}",
                error_code=1006
            )

        print("INFERENCE DONE", flush=True)

        if "Recognized waypoint:" in result_str:
            print("Inference successful:", result_str)
            result = result_str.split("Recognized waypoint: ")[1].strip()
        elif "No matching waypoint found." in result_str:
            result = "No matching waypoint found."
        else:
            result = result_str or "Inference completed with unrecognized output format."

        shutil.rmtree(data_dir, ignore_errors=True)

        return JSONResponse(
            status_code=200,
            content={
                "model_url": model_url,
                "report_url": f"/reports/{poi_name}",
                "view_name": poi_name,
                "poi_id": poi_id,
                "message": result,
            },
        )

    except CustomHTTPException as e:
        raise e
    except Exception as e:
        print(f"Unexpected error: {e}", flush=True)
        raise CustomHTTPException(status_code=500, detail=str(e), error_code=1001)