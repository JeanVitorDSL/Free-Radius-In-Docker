#!/bin/bash
set -e

DALO_DIR="/var/www/html/daloradius"
CONF_FILE="${DALO_DIR}/app/common/includes/daloradius.conf.php"

echo "=== daloRADIUS - Iniciando ==="

# Aguarda MariaDB
echo "[1/3] Aguardando MariaDB em ${DALO_DB_HOST}:${DALO_DB_PORT}..."
RETRIES=30
until php -r "
  \$c = @new mysqli('${DALO_DB_HOST}', '${DALO_DB_USER}', '${DALO_DB_PASS}', '${DALO_DB_NAME}', ${DALO_DB_PORT});
  if (\$c->connect_error) exit(1);
  exit(0);
" 2>/dev/null; do
  RETRIES=$((RETRIES - 1))
  if [ $RETRIES -le 0 ]; then
    echo "ERRO: MariaDB não respondeu."
    break
  fi
  echo "   Aguardando... ($RETRIES restantes)"
  sleep 3
done
echo "   MariaDB pronto!"

# Cria tabela operators e usuário administrador
echo "[2/3] Verificando tabela de operadores..."
php -r "
  \$c = new mysqli('${DALO_DB_HOST}', '${DALO_DB_USER}', '${DALO_DB_PASS}', '${DALO_DB_NAME}', ${DALO_DB_PORT});
  \$c->query('CREATE TABLE IF NOT EXISTS operators (
    id          int(11)      NOT NULL AUTO_INCREMENT,
    username    varchar(64)  NOT NULL DEFAULT \\'\\',
    password    varchar(255) NOT NULL DEFAULT \\'\\',
    firstname   varchar(64)  DEFAULT \\'Administrator\\',
    lastname    varchar(64)  DEFAULT \\'Administrator\\',
    email       varchar(64)  DEFAULT \\'\\',
    accesslevel varchar(10)  DEFAULT \\'10\\',
    configfile  varchar(64)  DEFAULT \\'config.php\\',
    PRIMARY KEY (id)
  )');
  \$r = \$c->query(\"SELECT COUNT(*) as n FROM operators WHERE username='administrator'\");
  \$row = \$r->fetch_assoc();
  if (\$row['n'] == 0) {
    \$c->query(\"INSERT INTO operators (username,password,firstname,lastname,accesslevel) VALUES ('administrator',MD5('radius'),'Administrator','Administrator','10')\");
    echo 'Operador administrator criado.' . PHP_EOL;
  } else {
    echo 'Operador administrator ja existe.' . PHP_EOL;
  }
"

# Gera o daloradius.conf.php
echo "[3/3] Gerando configuração..."
cat > "${CONF_FILE}" << EOF
<?php
\$configValues['CONFIG_DB_ENGINE']  = 'mysql';
\$configValues['CONFIG_DB_HOST']    = '${DALO_DB_HOST}';
\$configValues['CONFIG_DB_PORT']    = '${DALO_DB_PORT}';
\$configValues['CONFIG_DB_USER']    = '${DALO_DB_USER}';
\$configValues['CONFIG_DB_PASS']    = '${DALO_DB_PASS}';
\$configValues['CONFIG_DB_NAME']    = '${DALO_DB_NAME}';

\$configValues['CONFIG_DB_TBL_RADCHECK']              = 'radcheck';
\$configValues['CONFIG_DB_TBL_RADREPLY']              = 'radreply';
\$configValues['CONFIG_DB_TBL_RADUSERGROUP']          = 'radusergroup';
\$configValues['CONFIG_DB_TBL_RADGROUPCHECK']         = 'radgroupcheck';
\$configValues['CONFIG_DB_TBL_RADGROUPREPLY']         = 'radgroupreply';
\$configValues['CONFIG_DB_TBL_RADACCT']               = 'radacct';
\$configValues['CONFIG_DB_TBL_RADPOSTAUTH']           = 'radpostauth';
\$configValues['CONFIG_DB_TBL_NAS']                   = 'nas';
\$configValues['CONFIG_DB_TBL_USERINFO']              = 'userinfo';
\$configValues['CONFIG_DB_TBL_DALOOPERATORS']         = 'operators';
\$configValues['CONFIG_DB_TBL_DALOACTIONLOG']         = 'actions';
\$configValues['CONFIG_DB_TBL_DALOACCESSLOG']         = 'accesslogs';
\$configValues['CONFIG_DB_TBL_DALOCONFIGS']           = 'configs';
\$configValues['CONFIG_DB_TBL_DALOMTRRECORDS']        = 'mtotacct';
\$configValues['CONFIG_DB_TBL_DALOMTRSESSIONS']       = 'mauth';
\$configValues['CONFIG_DB_TBL_DALOBILLINGPLANS']      = 'billing_plans';
\$configValues['CONFIG_DB_TBL_DALOBILLINGUSERPLAN']   = 'billing_users';

\$configValues['FREERADIUS_VERSION']                  = '3';
\$configValues['CONFIG_LOG_PAGES']                    = 'yes';
\$configValues['CONFIG_LOG_DIR']                      = '/tmp/daloradius';
\$configValues['CONFIG_LOG_LEVEL']                    = 3;
\$configValues['CONFIG_TIMEZONE']                     = 'America/Sao_Paulo';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSSERVER'] = 'radius-server';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSSECRET'] = 'testing123';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSPORT']   = '1812';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSAUTH']   = 'PAP';
EOF

mkdir -p /tmp/daloradius
chown -R www-data:www-data "${DALO_DIR}"
chmod -R 755 "${DALO_DIR}"
chown www-data:www-data /tmp/daloradius

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  daloRADIUS: http://localhost:8080/operators/        ║"
echo "║  Login: administrator / radius                       ║"
echo "╚══════════════════════════════════════════════════════╝"

exec apache2-foreground