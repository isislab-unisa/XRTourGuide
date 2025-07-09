import subprocess

def run_inference_subproc(
    input_dir: str,
    model_path: str,
):
    try:
        cmd = [
            "python",
            "inference_script.py",
            "--image-path",
            input_dir,
            "--checkpoint",
            model_path,
        ]
        print("Running command:", " ".join(cmd))

        result = subprocess.run(cmd, check=True, capture_output=True)
        return result.stdout.decode("utf-8").strip()
    except Exception as e:
        print(f"Inference failed: {e}")
