# Guía de Despliegue, DNS y Puesta en Marcha v1.0

* **Proyecto:** Sistema de Monitoreo de Estrés Hídrico en Plantas de Arándano
* **Fase:** 3 - Despliegue y Puesta en Marcha
* **Fecha:** 2025-06-26
* **Versión:** 1.0

## 1. Propósito

Este documento describe el proceso completo para desplegar la aplicación en el servidor de producción, configurar el DNS para el acceso público a través de un dominio, y establecer una estrategia de copias de seguridad automatizadas. Esta guía consolida todas las acciones, depuración y configuraciones finales realizadas durante la Fase 3.

## 2. Configuración de Dominio y DNS (Cloudflare)

Para maximizar la seguridad y el rendimiento, se decidió gestionar el DNS del dominio `arandanoirt.co` a través de Cloudflare. Esto proporciona una capa de protección (WAF, Anti-DDoS) y oculta la IP real del servidor.

### 2.1 Configuración de Registros DNS

Se limpiaron los registros DNS heredados del proveedor de hosting anterior y se configuró la siguiente tabla de registros en el panel de Cloudflare para enrutar el tráfico correctamente.

| Tipo  | Nombre           | Contenido                 | Estado de Proxy             |
| :---- | :--------------- | :------------------------ | :-------------------------- |
| **A** | `arandanoirt.co` | `<IP_PÚBLICA_DEL_VPS>`    | Redirigido mediante proxy   |
| **A** | `grafana`        | `<IP_PÚBLICA_DEL_VPS>`    | Redirigido mediante proxy   |
| **A** | `minio`          | `<IP_PÚBLICA_DEL_VPS>`    | Redirigido mediante proxy   |
| **A** | `mail`           | `<IP_DEL_HOSTING_CORREO>` | Solo DNS                    |
| **A** | `webmail`        | `<IP_DEL_HOSTING_CORREO>` | Solo DNS                    |
| **CNAME**| `www`          | `arandanoirt.co`            | Redirigido mediante proxy   |
| **MX** | `arandanoirt.co` | `arandanoirt.co`            | Solo DNS                    |

*Se mantuvieron todos los demás registros `SRV` y `TXT` existentes para asegurar la operatividad del servicio de correo electrónico.*

### 2.2 Verificación de la Propagación

Se confirmó que los registros se propagaron correctamente usando el comando `dig`:
```bash
# Verificar dominio principal (debe resolver a IPs de Cloudflare)
dig arandanoirt.co

# Verificar subdominios (deben resolver a IPs de Cloudflare)
dig grafana.arandanoirt.co
dig minio.arandanoirt.co

# Verificar registro de correo (debe resolver a la IP del hosting)
dig mail.arandanoirt.co
```

## 3. Despliegue y Configuración de Servicios

El despliegue se realizó utilizando el archivo `docker-compose.yml` del repositorio `ArandanoIRTOps`. Durante el proceso, se realizaron varias depuraciones y ajustes críticos.

### 3.1 Configuración del Proxy Inverso (Caddy)

Se creó el archivo `caddy/Caddyfile` para gestionar el tráfico entrante y la terminación SSL.

### 3.2 Ajustes Críticos en `docker-compose.yml`

Para asegurar un arranque estable, se realizaron las siguientes modificaciones finales:

1.  **Imagen de PostgreSQL Personalizada:** Se creó un `postgres/Dockerfile` para instalar la extensión `pgaudit` y se modificó el servicio `postgres` para construir esta imagen localmente.
2.  **Healthcheck Robusto para PostgreSQL:** Se añadió un `healthcheck` con un `start_period` para dar tiempo a la base de datos a inicializarse antes de que la aplicación dependa de ella.
3.  **Configuración de `listen_addresses` en PostgreSQL:** Se modificó `postgres/postgresql.conf` para establecer `listen_addresses = '*'`, permitiendo conexiones desde otros contenedores.
4.  **Configuración Robusta para Loki:** Se simplificó la configuración de Loki (`loki/loki-config.yml`) para un despliegue de nodo único, resolviendo los problemas de permisos de escritura de forma definitiva.

### 3.3 Puesta en Marcha

Con todas las configuraciones en su lugar, el sistema se inició con:
```bash
# Iniciar la pila completa
docker-compose up -d --force-recreate --build
```
Tras el arranque, se verificó el estado de todos los contenedores con `docker-compose ps` y se confirmó el acceso web a los tres puntos de entrada: `https://arandanoirt.co`, `https://grafana.arandanoirt.co` y `https://minio.arandanoirt.co`.

## 4. Configuración de Backups Automatizados

Para garantizar la integridad de los datos, se implementó un sistema de backups diarios.

### 4.1 Configuración del Cliente MinIO (`mc`)

Se instaló y configuró el cliente `mc` en el servidor anfitrión para permitir la subida de archivos al servicio MinIO.
```bash
# Descargar e instalar
wget [https://dl.min.io/client/mc/release/linux-amd64/mc](https://dl.min.io/client/mc/release/linux-amd64/mc)
chmod +x mc
sudo mv mc /usr/local/bin/

# Configurar alias con las credenciales ROOT de MinIO
mc alias set localminio [http://127.0.0.1:9000](http://127.0.0.1:9000) <MINIO_ROOT_USER> <MINIO_ROOT_PASSWORD>

# Crear el bucket para los backups
mc mb localminio/backups
```

### 4.2 Creación del Script de Backup

Se creó el script `backup_postgres.sh` en la raíz de `ArandanoIRTOps` y se le dieron permisos de ejecución (`chmod +x backup_postgres.sh`).

### 4.3 Automatización con Cronjob

Finalmente, se programó la ejecución automática del script todos los días a las 3:00 AM.
```bash
# Abrir el editor de crontab
crontab -e
```
Se añadió la siguiente línea al archivo:
```crontab
0 3 * * * /home/<usuario>/ArandanoProject/ArandanoIRTOps/backup_postgres.sh >> /home/<usuario>/ArandanoProject/ArandanoIRTOps/backup.log 2>&1
```

## 5. Conclusión

Al finalizar la Fase 3, el "Sistema de Monitoreo de Estrés Hídrico" está completamente desplegado y operativo en un entorno de producción. El sistema es accesible públicamente de forma segura, toda la pila de servicios funciona correctamente, y se ha implementado una estrategia de copias de seguridad diarias y automáticas para garantizar la recuperación ante desastres.