# ArandanoIRTOps — Infraestructura y Operaciones del Sistema AIRT

<div align="center">

[![CD - Sync Server Configuration](https://github.com/RFGRONA/ArandanoIRTOps/actions/workflows/cd.yml/badge.svg)](https://github.com/RFGRONA/ArandanoIRTOps/actions/workflows/cd.yml)
[![Validate Infrastructure Config](https://github.com/RFGRONA/ArandanoIRTOps/actions/workflows/validate-ops.yml/badge.svg)](https://github.com/RFGRONA/ArandanoIRTOps/actions/workflows/validate-ops.yml)
[![Docker Compose](https://img.shields.io/badge/Docker_Compose-v2-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![Caddy](https://img.shields.io/badge/Caddy-Reverse_Proxy-00ADD8?logo=caddy)](https://caddyserver.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://www.postgresql.org/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Repositorio de infraestructura como código (IaC) del sistema AIRT — gestiona el despliegue, la observabilidad y las operaciones del ecosistema de monitoreo de estrés hídrico en arándano.**

[Arquitectura](#-arquitectura-de-infraestructura) · [Stack](#-stack-de-infraestructura) · [Inicio Rápido](#-despliegue-rápido-en-producción) · [Configuración](#%EF%B8%8F-referencia-de-configuración) · [Operaciones](#-operaciones-y-mantenimiento)

</div>

---

## 📋 Descripción del Repositorio

**ArandanoIRTOps** es el repositorio de infraestructura y operaciones del proyecto de grado **AIRT** (*Arándano IRT*). Contiene toda la definición declarativa del entorno de producción: composición de servicios Docker, configuración del proxy inverso, pila de observabilidad, scripts de mantenimiento y pipelines de integración/despliegue continuo (CI/CD).

Este repositorio aplica el principio de **Infraestructura como Código (IaC)**, garantizando que el entorno de producción sea reproducible, versionado y auditado a través del historial de Git. Junto con el repositorio de la aplicación, constituye el sistema AIRT completo.

### Ecosistema del Proyecto AIRT

El proyecto se divide en repositorios especializados con responsabilidades bien delimitadas:

| Repositorio | Rol | Descripción |
|---|---|---|
| [`ArandanoIRTSoftware`](https://github.com/RFGRONA/ArandanoIRTSoftware) | Aplicación | Plataforma web ASP.NET Core 8 (monolito con microservicio RAG) |
| **`ArandanoIRTOps`** (este) | **Infraestructura** | **Definición de entorno, despliegue y operaciones en VPS** |
| Firmware ESP32 | Firmware | Dispositivos de captura térmica e IoT de campo |

---

## 🏛️ Arquitectura de Infraestructura

El entorno de producción se despliega en un único servidor VPS Linux mediante **Docker Compose**, con todos los servicios interconectados en una red privada (`arandano-net`) y expuestos al exterior exclusivamente a través de un proxy inverso con TLS automático.

```
                           Internet
                              │
                    ┌─────────▼──────────┐
                    │    Caddy (HTTPS)    │  :80 / :443
                    │  TLS automático     │  Let's Encrypt
                    └──┬──────┬──────┬───┘
                       │      │      │
              ┌────────▼─┐ ┌──▼──┐ ┌─▼────────────┐
              │  AIRT App │ │Gfna.│ │  MinIO Console│
              │ :8080     │ │:3000│ │  :9001        │
              └────┬──────┘ └──┬──┘ └──────┬────────┘
                   │           │            │
              ╔════▼═══════════▼════════════▼════════╗
              ║          arandano-net (bridge)        ║
              ╠═══════════════╦═══════════════════════╣
              ║  PostgreSQL   ║  MinIO (S3)           ║
              ║  :5432        ║  :9000 / :9001        ║
              ╠═══════════════╬═══════════════════════╣
              ║  Loki         ║  Promtail             ║
              ║  :3100        ║  (agente Docker)      ║
              ╚═══════════════╩═══════════════════════╝
```

### Flujo de Despliegue Continuo

```
  Push a 'main'  ──►  GitHub Actions (cd.yml)
                            │
                            ▼
                  SSH al servidor VPS
                            │
                     git pull origin main
                            │
                  docker compose up -d --remove-orphans
                            │
                            ▼
                  ✅  Entorno sincronizado
```

> [!NOTE]
> El pipeline de CD sincroniza **únicamente la configuración de infraestructura** (este repositorio). La imagen de la aplicación se publica de forma independiente desde `ArandanoIRTSoftware` vía GHCR y es tomada por Docker Compose en el siguiente arranque.

---

## 🧱 Stack de Infraestructura

| Componente | Tecnología | Versión / Imagen | Propósito |
|---|---|---|---|
| **Proxy Inverso** | Caddy | `caddy:latest` | TLS automático (Let's Encrypt), enrutamiento de dominios |
| **Aplicación** | ASP.NET Core | `ghcr.io/rfgrona/arandanoirtsoftware:latest` | Plataforma web AIRT |
| **Base de Datos** | PostgreSQL | `16` (imagen custom) | Persistencia relacional de todos los datos del sistema |
| **Almacenamiento de Objetos** | MinIO | `RELEASE.2025-07-23T15-54-02Z-cpuv1` | Almacenamiento de imágenes térmicas (compatible S3) |
| **Agregador de Logs** | Loki | `grafana/loki:2.9.2` | Base de datos de logs indexados |
| **Agente de Logs** | Promtail | `grafana/promtail:2.9.2` | Colección de logs desde el socket Docker |
| **Visualización** | Grafana | `grafana/grafana:latest` | Dashboards de observabilidad y consulta de logs |
| **Orquestación** | Docker Compose v2 | — | Definición y ciclo de vida de todos los servicios |

---

## 🗂️ Estructura del Repositorio

```
ArandanoIRTOps/
│
├── .github/
│   └── workflows/
│       ├── cd.yml                # Pipeline CD: Sincroniza la config en el VPS vía SSH
│       └── validate-ops.yml      # Pipeline CI: Valida Compose, Dockerfiles y Shell scripts
│
├── caddy/
│   └── Caddyfile                 # Configuración del proxy inverso y dominios virtuales
│
├── loki/
│   └── loki-config.yml           # Configuración del servidor de logs Loki
│
├── minio/
│   └── setup-minio.sh            # Script de inicialización de buckets y políticas en MinIO
│
├── postgres/
│   ├── CrateDb-Script.sql        # Script DDL de inicialización del esquema de la base de datos
│   ├── Dockerfile                # Imagen personalizada de PostgreSQL con configuración tuneada
│   └── postgresql.conf           # Parámetros de rendimiento y conexiones de PostgreSQL
│
├── promtail/
│   └── promtail-config.yml       # Configuración del agente de recolección de logs Docker
│
├── backup_postgres.sh            # Script de backup automatizado: pg_dump + gzip + MinIO
├── docker-compose.yml            # Definición maestra de todos los servicios en producción
├── .env.template                 # Plantilla de variables de entorno (NO contiene secretos reales)
├── .gitignore                    # Excluye .env y otros archivos sensibles del control de versiones
└── LICENSE                       # Licencia GNU GPLv3
```

---

## 🚀 Despliegue Rápido en Producción

Esta guía describe la configuración inicial de un servidor VPS limpio (Ubuntu 22.04 LTS o similar).

### Prerrequisitos del Servidor

- Sistema operativo Linux (Ubuntu 22.04+ recomendado)
- [Docker Engine](https://docs.docker.com/engine/install/ubuntu/) con Docker Compose v2
- Acceso SSH con usuario no-root con privilegios `sudo`
- DNS configurado apuntando al VPS:
  - `arandanoirt.co` → IP del servidor
  - `grafana.arandanoirt.co` → IP del servidor
  - `minio.arandanoirt.co` → IP del servidor

### Paso 1: Clonar los Repositorios en el Servidor

La convención de directorios en el servidor debe respetar la siguiente estructura:

```bash
mkdir ~/ArandanoProject && cd ~/ArandanoProject
git clone https://github.com/RFGRONA/ArandanoIRTSoftware.git
git clone https://github.com/RFGRONA/ArandanoIRTOps.git
```

### Paso 2: Configurar las Variables de Entorno

Desde el directorio `ArandanoIRTOps`, copia la plantilla y completa **todos** los valores:

```bash
cd ~/ArandanoProject/ArandanoIRTOps
cp .env.template .env
nano .env
```

> [!CAUTION]
> El archivo `.env` contiene credenciales de producción y **nunca debe subirse a Git**. Está incluido en `.gitignore`. Verifícalo antes de hacer cualquier commit.

> [!IMPORTANT]
> La variable `ADMIN_PASSWORD_HASH` debe contener un hash **Bcrypt** de la contraseña, no el texto plano. Usa doble `$$` para los hashes Bcrypt en archivos `.env` (ej: `$$2a$$12$$...`).

### Paso 3: Levantar la Infraestructura

```bash
docker compose up -d
```

Docker Compose levantará todos los servicios respetando las dependencias de salud (`healthcheck`) definidas. El orden de arranque efectivo es:

1. **PostgreSQL** y **MinIO** (servicios base con healthcheck)
2. **minio-setup** (inicializa buckets una sola vez, luego se detiene)
3. **Loki** (base de datos de logs)
4. **Promtail** y **Grafana** (observabilidad)
5. **arandano-app** (espera a que PostgreSQL esté sano)
6. **Caddy** (espera a que la app, Grafana y MinIO estén listos)

### Paso 4: Verificar el Despliegue

```bash
# Verificar que todos los contenedores están corriendo
docker compose ps

# Verificar los logs de la aplicación en tiempo real
docker compose logs -f arandano-app

# Verificar los logs de Caddy (para diagnósticos de TLS)
docker compose logs -f caddy
```

Los servicios estarán disponibles en:

| Servicio | URL |
|---|---|
| Plataforma AIRT | `https://arandanoirt.co` |
| Grafana (Observabilidad) | `https://grafana.arandanoirt.co` |
| MinIO Console (Almacenamiento) | `https://minio.arandanoirt.co` |

> [!TIP]
> Caddy gestiona automáticamente la obtención y renovación de certificados TLS mediante Let's Encrypt. No se requiere configuración manual de HTTPS.

---

## ⚙️ Referencia de Configuración

Todas las variables de entorno se definen en el archivo `.env` (generado a partir de `.env.template`). A continuación se describe cada sección:

### Caddy & Dominio

| Variable | Descripción | Ejemplo |
|---|---|---|
| `CADDY_EMAIL` | Email para notificaciones de Let's Encrypt | `ops@arandanoirt.co` |
| `BASE_URL` | URL pública raíz de la aplicación | `https://arandanoirt.co` |

### PostgreSQL

| Variable | Descripción |
|---|---|
| `POSTGRES_DB` | Nombre de la base de datos a crear |
| `POSTGRES_USER` | Usuario de base de datos para la aplicación |
| `POSTGRES_PASSWORD` | Contraseña del usuario de base de datos |
| `CONNECTION_STRING` | Cadena de conexión completa para la aplicación .NET |

### MinIO (Almacenamiento S3)

| Variable | Descripción |
|---|---|
| `MINIO_ROOT_USER` | Usuario administrador de la consola MinIO |
| `MINIO_ROOT_PASSWORD` | Contraseña del administrador de MinIO |
| `MINIO_APP_ACCESS_KEY` | Access Key con permisos restringidos para la aplicación |
| `MINIO_APP_SECRET_KEY` | Secret Key correspondiente a `MINIO_APP_ACCESS_KEY` |
| `MINIO_APP_ENDPOINT` | Endpoint interno de MinIO (`minio:9000`) |
| `MINIO_PUBLIC_URL_BASE` | URL pública para generar URLs de objetos accesibles |

### Observabilidad (Grafana)

| Variable | Descripción |
|---|---|
| `GRAFANA_USER` | Usuario administrador de Grafana |
| `GRAFANA_PASSWORD` | Contraseña del administrador de Grafana |
| `GRAFANA_API_KEY` | API Key de Grafana para integraciones (alertas de la aplicación) |

### Servicios Externos

| Variable | Descripción |
|---|---|
| `WEATHER_API_KEY` | Clave de la API climática externa (WeatherAPI.com) |
| `WEATHER_API_URL` | URL base del servicio meteorológico |
| `BREVO_API_KEY` | Clave de la API de Brevo para el envío de alertas por correo |
| `TURNSTILE_SITE_KEY` | Clave de sitio de Cloudflare Turnstile (anti-bot en login) |
| `TURNSTILE_SECRET_KEY` | Clave secreta de Cloudflare Turnstile |

### Credenciales de la Aplicación

| Variable | Descripción |
|---|---|
| `ADMIN_USERNAME` | Nombre de usuario del administrador raíz del sistema |
| `ADMIN_PASSWORD_HASH` | Hash Bcrypt de la contraseña del administrador (usar `$$` en vez de `$`) |

---

## 📊 Observabilidad

La pila de observabilidad está compuesta por **Loki + Promtail + Grafana**, un estándar de la industria para agregación y visualización de logs de contenedores.

```
  Contenedores Docker
        │
        ▼ (socket Docker)
   ┌──────────┐       push logs       ┌─────────┐
   │ Promtail │ ────────────────────► │  Loki   │
   └──────────┘                       └────┬────┘
                                           │ query
                                      ┌────▼────┐
                                      │ Grafana │  ◄── Operador
                                      └─────────┘
```

- **Promtail** lee los logs de todos los contenedores Docker a través del socket `/var/run/docker.sock` y los envía a Loki.
- **Loki** indexa los logs por etiquetas (container name, stream) y los persiste en el volumen `loki_data`.
- **Grafana** provee la interfaz de consulta (LogQL) y dashboards sobre los logs del sistema.

> [!TIP]
> Accede a Grafana en `https://grafana.arandanoirt.co`. En la sección **Explore**, selecciona el datasource **Loki** y filtra por `{container_name="arandano-app"}` para ver los logs estructurados de la aplicación en tiempo real.

---

## 🔄 Pipelines de CI/CD

### `validate-ops.yml` — Validación de Infraestructura (CI)

Se ejecuta en **Pull Requests** que modifiquen `docker-compose.yml`, Dockerfiles o scripts Shell.

| Job | Herramienta | Qué valida |
|---|---|---|
| `validate-compose` | `docker compose config -q` | Sintaxis y coherencia del `docker-compose.yml` |
| `lint-shell-scripts` | **ShellCheck** | Calidad y posibles bugs en scripts `.sh` |
| `lint-dockerfiles` | **Hadolint** | Mejores prácticas y seguridad en Dockerfiles |

### `cd.yml` — Despliegue Continuo (CD)

Se ejecuta al hacer `push` a la rama `main` (o manualmente vía `workflow_dispatch`).

1. Se conecta al VPS de producción vía **SSH** (usando los secretos `SSH_HOST`, `SSH_USERNAME`, `SSH_PRIVATE_KEY`, `SSH_FINGERPRINT`).
2. En el servidor, ejecuta `git fetch --all && git reset --hard origin/main` para sincronizar el repositorio de forma limpia.
3. Aplica los cambios con `docker compose up -d --remove-orphans`.

> [!NOTE]
> El pipeline usa **concurrencia con cancelación** (`cancel-in-progress: true`), evitando que dos despliegues simultáneos pisen el mismo entorno.

### Secretos de GitHub Requeridos

Configura los siguientes secretos en `Settings > Secrets and variables > Actions` del repositorio:

| Secreto | Descripción |
|---|---|
| `SSH_HOST` | Dirección IP o hostname del servidor VPS de producción |
| `SSH_USERNAME` | Usuario SSH del servidor (debe tener acceso a Docker) |
| `SSH_PRIVATE_KEY` | Clave privada SSH en formato PEM para autenticación sin contraseña |
| `SSH_FINGERPRINT` | Fingerprint del host SSH para verificación de identidad del servidor |

---

## 🛡️ Operaciones y Mantenimiento

### Backup de Base de Datos

El script `backup_postgres.sh` automatiza el proceso de respaldo de la base de datos PostgreSQL. Ejecuta un `pg_dump` dentro del contenedor, lo comprime con `gzip` y sube el resultado al bucket `backups` de MinIO.

```bash
# Ejecutar un backup manual
./backup_postgres.sh

# Personalizar parámetros vía variables de entorno
DB_NAME="otra_db" DB_CONTAINER="otro-contenedor" ./backup_postgres.sh
```

**Variables de configuración del script:**

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `DB_USER` | `arandano_user` | Usuario de PostgreSQL para el volcado |
| `DB_NAME` | `arandano_db` | Base de datos a respaldar |
| `DB_CONTAINER` | `arandano-postgres` | Nombre del contenedor Docker de PostgreSQL |
| `MINIO_ALIAS` | `localminio` | Alias del cliente `mc` configurado para MinIO |
| `MINIO_BUCKET` | `backups` | Bucket de destino en MinIO |
| `BACKUP_DIR` | `/tmp` | Directorio temporal para el archivo de backup |

> [!TIP]
> Para automatizar el backup, agrega una entrada en el `crontab` del servidor:
> ```bash
> # Backup diario a las 2:00 AM
> 0 2 * * * /home/user/ArandanoProject/ArandanoIRTOps/backup_postgres.sh >> /var/log/airt-backup.log 2>&1
> ```

### Comandos Operacionales Comunes

```bash
# Ver el estado de todos los servicios
docker compose ps

# Reiniciar un servicio específico sin afectar al resto
docker compose restart arandano-app

# Ver los logs de un servicio con seguimiento en tiempo real
docker compose logs -f arandano-app

# Forzar la descarga de la imagen más reciente de la aplicación y reiniciar
docker compose pull arandano-app && docker compose up -d arandano-app

# Detener todos los servicios (sin eliminar datos)
docker compose stop

# Eliminar contenedores y redes (los volúmenes de datos se conservan)
docker compose down

# ⚠️ DESTRUCTIVO: Eliminar todo incluyendo volúmenes de datos
docker compose down -v
```

### Actualización de la Aplicación

La imagen de la aplicación se actualiza desde el pipeline de CD de `ArandanoIRTSoftware`. Para forzar una actualización manual:

```bash
# Descargar la nueva imagen desde GHCR
docker compose pull arandano-app

# Reiniciar únicamente el contenedor de la aplicación
docker compose up -d arandano-app
```

### Rotación de Secretos

Al rotar cualquier credencial (contraseña de base de datos, claves de MinIO, etc.):

1. Actualizar el valor en el archivo `.env` del servidor.
2. Reiniciar el servicio o servicios afectados:
   ```bash
   docker compose up -d --force-recreate arandano-app
   ```
3. Si se rota la contraseña de PostgreSQL, actualizar también dentro del contenedor de base de datos.

---

## 🌐 Dominios y Enrutamiento

El proxy inverso Caddy gestiona los siguientes dominios virtuales, cada uno con certificado TLS independiente:

| Dominio | Servicio de Destino | Puerto Interno |
|---|---|---|
| `arandanoirt.co` | `arandano-app` | `8080` |
| `grafana.arandanoirt.co` | `grafana` | `3000` |
| `minio.arandanoirt.co` | `minio` (consola) | `9001` |

> [!IMPORTANT]
> La API S3 de MinIO (puerto `9000`) **no está expuesta públicamente** a través de Caddy por diseño. El acceso se realiza únicamente desde la red interna `arandano-net`, evitando exposición innecesaria.

---

## 🤝 Contribuciones

Este repositorio corresponde a un proyecto académico de grado en Ingeniería. No está abierto a contribuciones externas en este momento, pero el código se publica con fines educativos bajo la licencia **GPLv3**.

### Convención de Ramas

| Rama | Propósito |
|---|---|
| `main` | Rama de producción. Los pushes aquí sincronizan automáticamente el VPS. |
| `feature/*` | Desarrollo de cambios en infraestructura. Activa el pipeline de validación (CI). |

---

## 📄 Licencia

Este proyecto está distribuido bajo la licencia **GNU General Public License v3.0**. Consulta el archivo [LICENSE](./LICENSE) para más detalles.

---

<div align="center">
  <sub>Desarrollado como proyecto de grado en Ingeniería — 2026</sub>
</div>
