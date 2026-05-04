#!/bin/sh

# Conectarse al servidor MinIO usando el comando moderno 'mc alias set'
until /usr/bin/mc alias set localminio http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do
    echo "Esperando que el servidor MinIO esté disponible..."
    sleep 1
done

echo "Servidor MinIO listo. Iniciando configuración..."

# Crear el bucket para copias de seguridad de Postgres
/usr/bin/mc mb localminio/backups --ignore-existing

# Crear el bucket para capturas RGB
/usr/bin/mc mb localminio/rgb-captures --ignore-existing

# Establecer la política del bucket a 'download' (lectura pública)
 /usr/bin/mc anonymous set download localminio/rgb-captures

# Crear el usuario para la aplicación .NET.
/usr/bin/mc admin user add localminio "$MINIO_APP_ACCESS_KEY" "$MINIO_APP_SECRET_KEY" || echo "El usuario de la aplicación ya existe."

# Crear la política de permisos.
/usr/bin/mc admin policy create localminio app-policy /tmp/minio/app-policy.json || echo "La política ya existe."

# Asignar la política al usuario.
/usr/bin/mc admin policy attach localminio app-policy --user "$MINIO_APP_ACCESS_KEY"

echo "¡Configuración de MinIO completada!"

exit 0