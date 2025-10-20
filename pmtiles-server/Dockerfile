FROM python:3.12

WORKDIR /app

# Install tools base
RUN apt-get update && apt-get install -y wget bash git golang && rm -rf /var/lib/apt/lists/*

# Copia requirements e installa Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia il codice FastAPI
COPY . .

# Crea cartelle dati e mappe
RUN mkdir -p /maps /data
COPY maps/salerno_provincia.pmtiles /maps/

# Builda il binario go-pmtiles
RUN git clone https://github.com/protomaps/go-pmtiles.git /go-pmtiles \
    && cd /go-pmtiles && go build -o /usr/local/bin/go-pmtiles

# Ritaglia il PMTiles durante la build
RUN /usr/local/bin/go-pmtiles extract /maps/salerno_provincia.pmtiles /maps/fisciano.pmtiles \
    --bbox=14.770088,40.759318,14.813561,40.781094

EXPOSE 8081

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8081"]
