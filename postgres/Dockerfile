# Usar la imagen oficial de PostgreSQL 16 como base
FROM postgres:16

# Actualizar la lista de paquetes e instalar la extensión pgaudit
# El paquete se llama postgresql-16-pgaudit para Ubuntu/Debian
RUN apt-get update && apt-get install -y postgresql-16-pgaudit && rm -rf /var/lib/apt/lists/*