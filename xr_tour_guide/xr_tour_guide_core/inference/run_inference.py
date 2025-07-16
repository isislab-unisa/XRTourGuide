import subprocess
import traceback


def run_inference_subproc(
    input_dir: str,
    model_path: str,
):
    try:
        cmd = [
            "python",
            "/workspace/xr_tour_guide_core/inference/inference_script.py",
            "--image-path",
            input_dir,
            "--checkpoint",
            model_path,
        ]
        print("Running command:", " ".join(cmd))

        result = subprocess.run(cmd, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        result_str = result.stdout.strip()
        if "Recognized waypoint:" in result_str:
            print("Inference successful:", result_str)
            return result_str.split("Recognized waypoint: ")[1].strip()
        elif "No matching waypoint found." in result_str:
            print("Inference completed but no matching waypoint found.")
            return None
        # return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Command failed with return code {e.returncode}", flush=True)
        print(f"Output: {e.stdout}", flush=True)
        return None
    except Exception as e:
        print(f"Inference failed: {e}", flush=True)
        stacktrace = traceback.format_exc()
        print(f"Full stacktrace:\n{stacktrace}")