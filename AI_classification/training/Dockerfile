FROM pytorch/pytorch:2.7.0-cuda11.8-cudnn9-runtime

WORKDIR /workspace

RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8090

CMD ["fastapi", "run", "main.py", "--port", "8090", "--host", "0.0.0.0"]

