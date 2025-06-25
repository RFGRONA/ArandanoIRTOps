# Guía de Configuración Inicial del Servidor v1.0

* **Proyecto:** Sistema de Monitoreo de Estrés Hídrico en Plantas de Arándano
* **Fase:** 1 - Preparación de Entornos
* **Fecha:** 2025-06-23
* **Versión:** 1.1

## 1. Propósito

Este documento detalla los pasos realizados para aprovisionar, asegurar y preparar el servidor principal (VPS) para el despliegue del proyecto, de acuerdo con las tareas definidas en el plan de trabajo.

## 2. Aprovisionamiento del Servidor (Cloud Provider)

* **Acción:** Se creó una Máquina Virtual (Droplet) en DigitalOcean.
* **Especificaciones:**
    * **Plan:** Premium AMD
    * **Recursos:** 1 vCPU, 1 GB RAM, 25 GB NVMe SSD
    * **Sistema Operativo:** Ubuntu 24.04 LTS
    * **Método de Autenticación:** Clave SSH. La clave privada se guardó localmente para el acceso.

## 3. Configuración del Firewall de Red

* **Acción:** Se creó y aplicó un "Cloud Firewall" en el panel de control de DigitalOcean para actuar como primera capa de defensa.
* **Reglas de Entrada Configuradas:**
    * **SSH (Puerto 22/TCP):** Permitido únicamente desde una dirección IP específica y conocida (la IP del desarrollador). En su defecto y si no tiene implicaciones graves de seguridad, se puede permitir desde cualquier dirección (`All IPv4`, `All IPv6`).
    * **HTTP (Puerto 80/TCP):** Permitido desde cualquier dirección (`All IPv4`, `All IPv6`).
    * **HTTPS (Puerto 443/TCP):** Permitido desde cualquier dirección (`All IPv4`, `All IPv6`).
* **Reglas de Salida:** Se mantuvo la configuración por defecto, permitiendo todo el tráfico saliente.

## 4. Configuración y Aseguramiento del Servidor (Vía SSH)

Los siguientes comandos se ejecutaron en secuencia tras la primera conexión al servidor.

### 4.1 Conexión Inicial y Actualización del Sistema

Se realizó la primera conexión como usuario `root` y se actualizó el sistema operativo para aplicar los últimos parches de seguridad.

```bash
# Conexión inicial
ssh root@IP_DEL_SERVIDOR 

# Actualización de todos los paquetes del sistema
apt update && apt upgrade -y

# (Opcional) Reiniciar el sistema
reboot now
```

### 4.2 Creación de un Usuario No-Root

Para mejorar la seguridad, se creó un usuario con privilegios de administrador para las operaciones diarias, evitando el uso directo de `root`.

```bash
# Crear nuevo usuario
adduser NAMEUSER

# Conceder privilegios de administrador (sudo)
usermod -aG sudo NAMEUSER

# Copiar la autorización de clave SSH de root al nuevo usuario
rsync --archive --chown=NAMEUSER:NAMEUSER /root/.ssh /home/NAMEUSER
```

*Después de este paso, se cerró la sesión de `root` y se continuó trabajando con el nuevo usuario.*

### 4.3 Instalación de Software Base

Se instaló el software de contenedorización siguiendo el método oficial de Docker para garantizar la última versión estable y las mejores prácticas de seguridad. Estos comandos son para **Ubuntu 24.04 LTS**.

1. **Desinstalar cualquier versión antigua o no oficial de Docker**
```bash
sudo apt-get remove docker.io docker-doc docker-compose podman-docker containerd runc
```
2. **Configurar el repositorio oficial de Docker**
```bash
# 2.1 Actualizar el índice de paquetes e instalar prerrequisitos
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# 2.2 Añadir la clave GPG oficial de Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 2.3 Añadir el repositorio de Docker a las fuentes de APT
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```
3. **Instalar Docker Engine, CLI y el plugin de Compose**
```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
4. **Instalar Git**
```bash
sudo apt-get install -y git
```

#### Pasos Post-Instalación

Para poder ejecutar comandos de Docker sin `sudo`, es necesario añadir tu usuario al grupo `docker`.

```bash
# Reemplaza 'user' con tu nombre de usuario si es diferente
sudo usermod -aG docker user 
```

**Importante:** Después de ejecutar el comando anterior, se debe **cerrar la sesión SSH y volver a iniciarla** para que los permisos de grupo se apliquen correctamente. Para verificar que todo funciona, después de volver a iniciar sesión, ejecuta `docker ps`. No debería mostrar un error de permisos.

### 4.4 Configuración del Firewall Local (UFW)

Se configuró el firewall del host (`ufw`) como segunda capa de defensa.

```bash
# Permitir acceso SSH
sudo ufw allow OpenSSH

# Permitir tráfico web HTTP y HTTPS
sudo ufw allow http
sudo ufw allow https

# Activar el firewall
sudo ufw enable

# Verificar el estado final
sudo ufw status
```

### 4.5 Instalación del Sistema de Prevención de Intrusiones

Se instaló `Fail2Ban` para proteger el servidor contra ataques de fuerza bruta, un requisito del diseño de seguridad.

```bash
# Instalar Fail2Ban
sudo apt install fail2ban -y

# Activar e iniciar el servicio
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Verificar que está protegiendo el servicio SSH
sudo fail2ban-client status sshd
```

## 5. Conclusión

Al finalizar estos pasos, el servidor está completamente aprovisionado, asegurado con múltiples capas de seguridad y preparado con el software base necesario.
