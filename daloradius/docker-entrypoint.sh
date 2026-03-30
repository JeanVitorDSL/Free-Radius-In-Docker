#!/bin/bash
set -e

DALO_DIR="/var/www/html/daloradius"
CONF_FILE="${DALO_DIR}/app/common/includes/daloradius.conf.php"

echo "=== daloRADIUS - Iniciando ==="

# Aguarda MariaDB via PHP
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

# Gera daloradius.conf.php completo
echo "[2/3] Gerando configuração..."
mkdir -p "$(dirname ${CONF_FILE})"

cat > "${CONF_FILE}" << EOF
<?php
\$configValues['CONFIG_DB_ENGINE']  = 'mysqli';
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
\$configValues['CONFIG_DB_TBL_RADNAS']                = 'nas';
\$configValues['CONFIG_DB_TBL_USERINFO']              = 'userinfo';
\$configValues['CONFIG_DB_TBL_DALOUSERINFO']          = 'userinfo';
\$configValues['CONFIG_DB_TBL_DALOOPERATORS']         = 'operators';
\$configValues['CONFIG_DB_TBL_DALOOPERATORS_ACL']     = 'operators_acl';
\$configValues['CONFIG_DB_TBL_DALOACTIONLOG']         = 'actions';
\$configValues['CONFIG_DB_TBL_DALOACCESSLOG']         = 'accesslogs';
\$configValues['CONFIG_DB_TBL_DALOCONFIGS']           = 'configs';
\$configValues['CONFIG_DB_TBL_DALOMTRRECORDS']        = 'mtotacct';
\$configValues['CONFIG_DB_TBL_DALOMTRSESSIONS']       = 'mauth';
\$configValues['CONFIG_DB_TBL_DALOBILLINGPLANS']      = 'billing_plans';
\$configValues['CONFIG_DB_TBL_DALOBILLINGUSERPLAN']   = 'billing_users';
\$configValues['CONFIG_DB_TBL_DALOUSERBILLINFO']      = 'billing_users';
\$configValues['CONFIG_DB_TBL_DALOHOTSPOTS']          = 'hotspots';
\$configValues['CONFIG_DB_TBL_DALOPASSWORDRESET']     = 'passwordreset';
\$configValues['CONFIG_DB_TBL_DALOAPIKEYS']           = 'apikeys';

\$configValues['FREERADIUS_VERSION']                        = '3';
\$configValues['CONFIG_LANG']                               = 'en';
\$configValues['CONFIG_LOG_PAGES']                          = 'yes';
\$configValues['CONFIG_LOG_DIR']                            = '/tmp/daloradius';
\$configValues['CONFIG_LOG_LEVEL']                          = 3;
\$configValues['CONFIG_LOG_QUERIES']                        = 'no';
\$configValues['CONFIG_LOG_ACTIONS']                        = 'yes';
\$configValues['CONFIG_DEBUG_SQL']                          = 'no';
\$configValues['CONFIG_DEBUG_SQL_ONPAGE']                   = 'no';
\$configValues['CONFIG_LOG_FILE']                           = '/tmp/daloradius/daloradius.log';
\$configValues['CONFIG_TIMEZONE']                           = 'America/Sao_Paulo';
\$configValues['CONFIG_IFACE_PASSWORD_HIDDEN']              = 'yes';
\$configValues['CONFIG_IFACE_TABLES_LISTING']               = '20';
\$configValues['CONFIG_IFACE_TABLES_LISTING_NUM']           = '10';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSSERVER']       = 'radius-server';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSSECRET']       = 'testing123';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSPORT']         = '1812';
\$configValues['CONFIG_MAINT_TEST_USER_RADIUSAUTH']         = 'PAP';
EOF

# Permissões e log
echo "[3/3] Ajustando permissões..."
mkdir -p /tmp/daloradius
touch /tmp/daloradius/daloradius.log
chown -R www-data:www-data "${DALO_DIR}"
chown -R www-data:www-data /tmp/daloradius
chmod 777 /tmp/daloradius/daloradius.log

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  daloRADIUS: http://localhost:8080/operators/        ║"
echo "║  Login: administrator / radius                       ║"
echo "╚══════════════════════════════════════════════════════╝"

exec apache2-foreground
