# Guía de Observabilidad y Monitoreo v1.0

  * **Proyecto:** Sistema de Monitoreo de Estrés Hídrico en Plantas de Arándano
  * **Fase:** 4 - Observabilidad y Monitoreo
  * **Fecha:** 2025-06-29
  * **Versión:** 1.0

## 1. Propósito

Este documento detalla la estrategia y los pasos de implementación para dotar al sistema de una capacidad de observabilidad completa. El objetivo de esta fase es crear un sistema de monitoreo multi-capa que permita no solo visualizar el estado de salud de la aplicación y la infraestructura en tiempo real, sino también recibir alertas proactivas ante cualquier anomalía, garantizando una alta disponibilidad y una rápida resolución de problemas.

## 2. Estrategia de Observabilidad en Capas

Para obtener una visibilidad completa, la estrategia de monitoreo se divide en tres capas distintas y complementarias:

1.  **Capa 1: Monitoreo de Infraestructura:** Vigila la salud de los recursos base del servidor (CPU, memoria, disco). Es la primera línea de defensa y alerta sobre posibles problemas de rendimiento a nivel de máquina antes de que impacten a la aplicación.
2.  **Capa 2: Monitoreo de Aplicación y Servicios (Logs Internos):** Se enfoca en el comportamiento interno del software. A través de la recolección y visualización de logs estructurados, permite depurar errores de la aplicación, auditar eventos de la base de datos y entender el flujo de trabajo del sistema.
3.  **Capa 3: Monitoreo de Disponibilidad Externa:** Simula la experiencia del usuario final, verificando constantemente que los puntos de acceso públicos (sitio web, APIs, etc.) estén en línea y respondiendo correctamente desde internet.

## 3. Implementación del Monitoreo Interno

Para esta capa se utilizó una pila de software auto-hospedada, orquestada a través de Docker Compose, compuesta por Grafana para la visualización y Loki para la agregación de logs.

### 3.1. Dashboards de Visualización

Se crearon dashboards específicos en Grafana para interpretar los logs recolectados:

  * **Dashboard de Errores de Aplicación:** Centrado en la salud del servicio .NET.
      * **Panel de Logs de Error:** Muestra en tiempo real las líneas de log que contienen un error.
        ```logql
        {container="arandano-app"} | json | Level="Error" 
        ```
      * **Panel de Contador de Errores:** Una estadística que muestra el número total de errores en las últimas 24 horas.
        ```logql
        sum(count_over_time({container="arandano-app"} | json | Level="Error" [24h]))
        ```
  * **Dashboard de Logs de Dispositivos:** Enfocado en la actividad del hardware.
      * **Panel de Logs de Dispositivos:** Filtra los logs que provienen específicamente de los dispositivos de hardware.
        ```logql
        {container="arandano-app"} | json |= "Log desde DeviceId"
        ```
  * **Dashboard de Auditoria:** Enfocado en la auditoría de eventos de la base de datos.
        ```logql
        {container="arandano-postgres"} |~ "AUDIT""
        ```

### 3.2. Sistema de Alertas Internas

Se configuraron reglas de alerta en Grafana para notificar proactivamente sobre problemas detectados en los logs.

  * **Alerta de Errores de Aplicación:** Se dispara si se detecta más de un error en un periodo de 5 minutos.
      * **Consulta:** `count_over_time({container="arandano-app"} | json | Level=~"Error|Fatal" [1m])`
      * **Condición:** `is above 0`

* **Alerta de Errores de Dispositivos:** Se dispara si se detecta más de un error en un periodo de 5 minutos.
      * **Consulta:** `sum(count_over_time({container="arandano-app"} |= "Log desde DeviceId" |= "level=error" [5m]))`
      * **Condición:** `is above 0`

## 4. Implementación del Monitoreo Externo y Notificaciones

Para la capa externa y las notificaciones se utilizaron servicios de terceros especializados.

### 4.1. Monitoreo de Disponibilidad (OneUptime)

Se configuró un servicio de monitoreo externo para verificar la disponibilidad de los endpoints públicos del proyecto, los cuales son servidos a través del proxy inverso Caddy.

  * **Acción:** Se crearon tres monitores de tipo `Website` en OneUptime.
  * **Endpoints Monitoreados:**
    1.  `https://arandanoirt.co` (Aplicación Principal)
    2.  `https://grafana.arandanoirt.co` (Dashboard Grafana)
    3.  `https://minio.arandanoirt.co` (Almacenamiento de Objetos)

### 4.2. Página de Estado Pública

Para comunicar de forma transparente la disponibilidad del sistema, se configuró una página de estado pública vinculada a los monitores de OneUptime, accesible a través de un subdominio personalizado.

  * **URL:** `status.arandanoirt.co`

### 4.3. Canal de Notificación (Webhook a Brevo)

Debido a que algunos proveedores de nube (como DigitalOcean) bloquean los puertos SMTP por defecto, se optó por una solución basada en webhooks para el envío de correos electrónicos de alerta.

  * **Tipo:** `Webhook` en Grafana.
  * **Servicio:** API de Brevo (anteriormente Sendinblue).
  * **Configuración Clave:**
      * **URL:** `https://api.brevo.com/v3/smtp/email`
      * **Método:** `POST`
      * **Headers:** Se añadieron las cabeceras `api-key` y `content-type`.
      * **Payload:** Se configuró una plantilla JSON estática para el cuerpo del correo.

### 4.4. Políticas de Notificación

Para evitar la fatiga por alertas y recibir notificaciones útiles, se configuró una política de notificaciones personalizada en Grafana con la siguiente lógica:

  * **`Group wait`: `5m`** - Espera 5 minutos desde el primer error para agrupar una ráfaga inicial en una sola notificación.
  * **`Group interval`: `5m`** - Permite que notificaciones de problemas *diferentes* se envíen rápidamente una tras otra.
  * **`Repeat interval`: `1h`** - Una vez notificado un problema, silencia los recordatorios para ese mismo problema durante una hora.

## 5. Recomendaciones y Mejoras a Futuro

1.  **Centralización de Notificaciones en la Aplicación:** La estrategia más robusta a largo plazo es desarrollar un módulo o endpoint dedicado dentro de la aplicación .NET Core para gestionar las notificaciones. Grafana enviaría un webhook a este endpoint, y la aplicación se encargaría de la lógica de contactar a proveedores externos (Brevo, Twilio, etc.). Esto abstrae la configuración, facilita el cambio de proveedores y permite una lógica de notificación más compleja.
2.  **Uso de SMTP Directo:** Si el proveedor de infraestructura lo permite, integrar Grafana directamente con un servidor SMTP es una solución más estándar y sencilla que la configuración manual de webhooks por API.
3.  **Enriquecimiento de Logs:** Para facilitar aún más la depuración, se recomienda enriquecer los logs estructurados con más contexto, como un `TraceId` para seguir una solicitud a través de todo el sistema o un `UserId` para asociar acciones a usuarios específicos.

## 6. Conclusión

Al finalizar la Fase 4, el sistema cuenta con una estrategia de observabilidad completa Se ha establecido un monitoreo proactivo desde el nivel de infraestructura hasta la experiencia del usuario final. La capacidad de visualizar logs, recibir alertas inteligentes y comunicar el estado del servicio de forma transparente dota al proyecto de la robustez y confiabilidad necesarias para un entorno de producción.