#!/bin/sh

# Esperar a que el servidor MinIO esté listo
# El script se ejecutará tan pronto como el contenedor inicie, pero el servicio puede tardar unos segundos en estar disponible
until /usr/bin/mc config host add localminio http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do
    echo "Esperando que el servidor MinIO esté disponible..."
    sleep 1
done

echo "Servidor MinIO listo. Iniciando configuración..."

# Crear el bucket para las capturas si no existe
/usr/bin/mc mb localminio/rgb-captures --ignore-existing

# Crear el usuario para la aplicación .NET (si no existe)
/usr/bin/mc admin user add localminio "$MINIO_APP_ACCESS_KEY" "$MINIO_APP_SECRET_KEY" || echo "El usuario de la aplicación ya existe."

# Añadir la política de permisos desde el archivo JSON
/usr/bin/mc admin policy create localminio app-policy /tmp/minio/app-policy.json || echo "La política ya existe."

# Asignar la política al usuario de la aplicación
/usr/bin/mc admin policy attach localminio app-policy --user "$MINIO_APP_ACCESS_KEY"

echo "¡Configuración de MinIO completada!"

exit 0