# =============================================================
# Dockerfile – FreeRADIUS com suporte a SQL (MariaDB)
# Base: freeradius/freeradius-server oficial
# =============================================================

FROM freeradius/freeradius-server:3.2.3

# Instala o cliente MariaDB para debug (opcional, mas útil)
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        mariadb-client \
        iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Copia as configurações customizadas para dentro da imagem.
# O volume no docker-compose.yml sobrescreve em runtime,
# mas este COPY garante que a imagem funcione standalone.
COPY config/ /etc/freeradius/3.0/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Porta de autenticação (UDP)
EXPOSE 1812/udp
# Porta de accounting (UDP)
EXPOSE 1813/udp

# O entrypoint roda como root para criar symlinks e checar o banco,
# depois troca para freerad automaticamente via exec freeradius -X
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
