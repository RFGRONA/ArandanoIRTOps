# Guía de Orquestación y Ejecución v1.0

  * **Proyecto:** Sistema de Monitoreo de Estrés Hídrico en Plantas de Arándano
  * **Fase:** 2 - Desarrollo y Contenerización
  * **Fecha:** 2025-06-23
  * **Versión:** 1.0

## 1. Propósito

Este documento detalla los pasos necesarios para construir y ejecutar la pila completa de la aplicación del "Sistema de Monitoreo de Estrés Hídrico" utilizando Docker y Docker Compose. El objetivo es proporcionar una guía clara para levantar un entorno de producción local, autocontenido y completamente orquestado, tal como se definió en la Fase 2 del plan de trabajo.

## 2. Prerrequisitos

Antes de iniciar, es fundamental asegurarse de que el entorno de ejecución (ya sea una máquina local, un servidor de pruebas o el VPS de producción) cumpla con los siguientes requisitos:

1.  **Git Instalado:** Necesario para clonar los repositorios.
2.  **Docker y Docker Compose Instalados:** El motor de Docker y el plugin de Compose deben estar instalados y operativos. Se recomienda seguir la guía de instalación oficial para Ubuntu 24.04 proporcionada anteriormente.
3.  **Estructura de Repositorios:** Los dos repositorios del proyecto deben estar clonados en la misma carpeta padre. La configuración de `docker-compose.yml` depende de esta estructura de rutas relativas:
    ```
    /ruta/a/tu/proyecto/
    |
    ├── ArandanoIRTSoftware/  <-- Repositorio con el código fuente de la app .NET
    |
    └── ArandanoIRTOps/       <-- Repositorio con la configuración de Docker Compose
    ```

## 3. Configuración del Entorno

La configuración de la aplicación se gestiona a través de archivos de configuración y variables de entorno, separando los secretos del código base.

### 3.1 Configuración del Repositorio de Software (`ArandanoIRTSoftware`)

El código de la aplicación utiliza un archivo `appsettings.json` para definir la estructura de su configuración.

  * **Archivo:** `appsettings.json`
  * **Propósito:** Este archivo, que **debe estar en el repositorio Git**, contiene la configuración no sensible y los valores por defecto de la aplicación. Los secretos deben estar vacíos o con placeholders.
    ```

### 3.2 Configuración del Repositorio de Operaciones (`ArandanoIRTOps`)

Este repositorio orquesta la ejecución de toda la pila de servicios. La configuración sensible se gestiona a través de un archivo `.env`.

  * **Acción:** En la raíz del repositorio `ArandanoIRTOps`, crea un archivo llamado `.env`.
  * **Importante:** Este archivo **NUNCA** debe ser subido al repositorio Git. Asegúrate de que `.env` esté incluido en tu archivo `.gitignore`.
  * **Plantilla:** En la raíz del repositorio `ArandanoIRTOps`, encontrarás un archivo de ejemplo llamado `.env.template`. Cópialo y renómbralo a `.env`, luego edítalo para completar los valores necesarios.

## 4. Ejecución de la Pila de Aplicación

Todos los comandos deben ejecutarse desde la raíz del repositorio `ArandanoIRTOps`, donde se encuentra el archivo `docker-compose.yml`.

### 4.1 Iniciar el Entorno

Este comando construirá la imagen de la aplicación .NET (si ha cambiado) y levantará todos los servicios en segundo plano.

```bash
# Navega al directorio de operaciones
cd /ruta/a/tu/proyecto/ArandanoIRTOps

# Levanta todos los servicios en modo detached (segundo plano) y reconstruye la imagen de la app
docker compose up -d --build
```


    * `up`: Inicia los servicios.
    * `-d`: Modo "detached", libera la terminal.
    * `--build`: Fuerza la reconstrucción de la imagen de `arandano-app` a partir de su `Dockerfile`. Esencial la primera vez o después de cambios en el código .NET.

### 4.2 Detener el Entorno

Este comando detiene y elimina los contenedores y la red creada.

```bash
# Desde la misma carpeta
docker compose down
```

  * **Nota:** Este comando no elimina los volúmenes nombrados (`postgres_data`, `minio_data`, etc.), por lo que tus datos persistirán. Para eliminar también los volúmenes, se usaría `docker compose down -v`.

### 4.3 Monitorear los Logs

Para ver los logs de todos los servicios en tiempo real:

```bash
docker compose logs -f
```

Para ver los logs de un servicio específico (ej. la aplicación .NET):

```bash
docker compose logs -f arandano-app
```

## 5. Puntos de Acceso a los Servicios

Una vez que el entorno está en ejecución, puedes acceder a las diferentes interfaces de usuario y servicios. Recuerda que, por seguridad, la mayoría están expuestos solo a `localhost` (127.0.0.1).

| Servicio | URL de Acceso | Credenciales por Defecto | Notas |
| :--- | :--- | :--- | :--- |
| **Aplicación Web** | `http://<IP_DEL_VPS>` | Usuario/Contraseña de Admin | Acceso a través del proxy inverso Caddy. |
| **Grafana** | `http://localhost:3000` | `admin` / `admin` | Para visualizar y consultar logs de Loki. |
| **MinIO Console** | `http://localhost:9001` | `minio_admin` / Contraseña del `.env` | Para gestionar los "buckets" y archivos. |
| **PostgreSQL** | `localhost:5432` | `arandano_user` / Contraseña del `.env` | Para conexión directa con un cliente de BD. |

## 6. Conclusión

Al seguir los pasos de esta guía, se puede desplegar de manera fiable y repetible toda la infraestructura y aplicación del proyecto. Esto completa la Fase 2, dejando un sistema completamente "contenedorizado" y listo para su despliegue final y exposición al público.