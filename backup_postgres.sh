#!/bin/bash

# ==============================================================================
# SCRIPT DE BACKUP PARA POSTGRESQL Y MINIO
# Descripción: Este script realiza un volcado de una base de datos PostgreSQL
#              que corre en un contenedor Docker, lo comprime y lo sube a un
#              bucket de MinIO.
# Versión de Repositorio: 1.1
# ==============================================================================

# --- CONFIGURACIÓN ---
# El script usa variables de entorno para ser flexible. Si no se definen,
# usará los valores por defecto que se muestran a continuación.
# Ejemplo de uso: export DB_NAME="otra_db" && ./backup_postgres.sh

DB_USER="${DB_USER:-arandano_user}"
DB_NAME="${DB_NAME:-arandano_db}"
DB_CONTAINER="${DB_CONTAINER:-arandano-postgres}"

# Configuración de MinIO
MINIO_ALIAS="${MINIO_ALIAS:-localminio}"
MINIO_BUCKET="${MINIO_BUCKET:-backups}"

# Directorio temporal para guardar el backup antes de subirlo
BACKUP_DIR="${BACKUP_DIR:-/tmp}"

# --- LÓGICA DEL SCRIPT (No modificar debajo de esta línea) ---

# 1. Crear un nombre de archivo con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="backup-${TIMESTAMP}.sql.gz"
FULL_PATH="${BACKUP_DIR}/${FILENAME}"

echo "----------------------------------------"
echo "Iniciando backup de la base de datos: ${DB_NAME}"
echo "----------------------------------------"
echo "INFO: El archivo de backup se llamará: ${FILENAME}"

# 2. Ejecutar pg_dump dentro del contenedor, comprimir y guardar
# El comando se ejecuta como el usuario 'postgres' del contenedor para evitar problemas de permisos.
# La salida de pg_dump se redirige (|) a gzip para comprimirla al vuelo.
docker exec -u postgres ${DB_CONTAINER} pg_dump -U ${DB_USER} -d ${DB_NAME} | gzip > ${FULL_PATH}

# 3. Comprobar si el archivo de backup se creó correctamente
if [ $? -eq 0 ]; then
  echo "OK: Backup de la base de datos y compresión completados con éxito."
else
  echo "ERROR: Falló el comando pg_dump o la compresión. Abortando."
  exit 1
fi

# 4. Subir el archivo de backup a MinIO
echo "INFO: Subiendo ${FILENAME} a MinIO bucket '${MINIO_BUCKET}'..."
mc cp ${FULL_PATH} ${MINIO_ALIAS}/${MINIO_BUCKET}/

# 5. Comprobar si la subida a MinIO fue exitosa
if [ $? -eq 0 ]; then
  echo "OK: El archivo se ha subido a MinIO correctamente."
else
  echo "ERROR: Falló la subida a MinIO. El archivo de backup local se conservará en ${FULL_PATH} para revisión."
  exit 1
fi

# 6. Limpiar el archivo de backup local
echo "INFO: Limpiando archivo local..."
rm ${FULL_PATH}

echo "----------------------------------------"
echo "¡Proceso de backup finalizado con éxito!"
echo "----------------------------------------"

exit 0
