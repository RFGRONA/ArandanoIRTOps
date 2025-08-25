# Usar la imagen oficial de MinIO como base
FROM minio/minio:RELEASE.2025-07-23T15-54-02Z-cpuv1

# Descargar e instalar el cliente de MinIO (mc) y darle permisos de ejecución
RUN curl -sSLo /usr/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    chmod +x /usr/bin/mc