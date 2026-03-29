#!/bin/bash
set -e

echo "=== FreeRADIUS POC - Iniciando ==="
# O log mostrou que o servidor busca em /etc/freeradius/
RADIUS_CONF="/etc/freeradius"

# 1. Aguarda o MariaDB
echo "[1/4] Aguardando MariaDB em ${DB_HOST}:${DB_PORT}..."
RETRIES=30
until bash -c "echo > /dev/tcp/${DB_HOST}/${DB_PORT}" 2>/dev/null; do
  RETRIES=$((RETRIES - 1))
  if [ $RETRIES -le 0 ]; then
    echo "ERRO: MariaDB não respondeu."
    exit 1
  fi
  sleep 2
done
echo "   MariaDB está pronto!"

# 2. Configura módulo SQL diretamente no local correto
echo "[2/4] Configurando módulo SQL..."
cat > "${RADIUS_CONF}/mods-available/sql" << SQLEOF
sql {
    driver = "rlm_sql_mysql"
    dialect = "mysql"
    server = "${DB_HOST}"
    port = ${DB_PORT}
    login = "${DB_USER}"
    password = "${DB_PASS}"
    radius_db = "${DB_NAME}"

    pool {
        start = 3
        min = 1
        max = 10
        spare = 3
        retry_delay = 30
    }

    read_groups = yes
    read_clients = yes
    
    authcheck_table  = "radcheck"
    authreply_table  = "radreply"
    groupcheck_table = "radgroupcheck"
    groupreply_table = "radgroupreply"
    usergroup_table  = "radusergroup"
    acct_table1      = "radacct"
    acct_table2      = "radacct"
    postauth_table   = "radpostauth"
    client_table     = "nas"

    authorize_check_query = "SELECT id, username, attribute, value, op FROM radcheck WHERE username = '%{SQL-User-Name}' ORDER BY id"
    authorize_reply_query = "SELECT id, username, attribute, value, op FROM radreply WHERE username = '%{SQL-User-Name}' ORDER BY id"
    authorize_group_check_query = "SELECT radgroupcheck.id, radgroupcheck.groupname, radgroupcheck.attribute, radgroupcheck.value, radgroupcheck.op FROM radgroupcheck, radusergroup WHERE radusergroup.username = '%{SQL-User-Name}' AND radusergroup.groupname = radgroupcheck.groupname ORDER BY radgroupcheck.id"
    authorize_group_reply_query = "SELECT radgroupreply.id, radgroupreply.groupname, radgroupreply.attribute, radgroupreply.value, radgroupreply.op FROM radgroupreply, radusergroup WHERE radusergroup.username = '%{SQL-User-Name}' AND radusergroup.groupname = radgroupreply.groupname ORDER BY radgroupreply.id"
    group_membership_query = "SELECT groupname FROM radusergroup WHERE username = '%{SQL-User-Name}' ORDER BY priority"
    simul_count_query = "SELECT COUNT(*) FROM radacct WHERE username = '%{SQL-User-Name}' AND acctstoptime IS NULL"
    accounting_onoff_query = "UPDATE radacct SET acctstoptime = FROM_UNIXTIME(%{integer:Event-Timestamp}), acctsessiontime = '%{integer:Event-Timestamp}' - UNIX_TIMESTAMP(acctstarttime), acctterminatecause = '%{Acct-Terminate-Cause}' WHERE acctsessiontime IS NULL AND nasipaddress = '%{NAS-IP-Address}' AND acctstoptime IS NULL"
    accounting_start_query = "INSERT INTO radacct (acctsessionid, acctuniqueid, username, realm, nasipaddress, nasportid, nasporttype, acctstarttime, acctupdatetime, acctstoptime, acctsessiontime, acctauthentic, connectinfo_start, acctinputoctets, acctoutputoctets, calledstationid, callingstationid, servicetype, framedprotocol, framedipaddress) VALUES ('%{Acct-Session-Id}', '%{Acct-Unique-Session-Id}', '%{SQL-User-Name}', '%{Realm}', '%{NAS-IP-Address}', '%{NAS-Port-Id}', '%{NAS-Port-Type}', FROM_UNIXTIME(%{integer:Event-Timestamp}), FROM_UNIXTIME(%{integer:Event-Timestamp}), NULL, '0', '%{Acct-Authentic}', '%{Connect-Info}', '0', '0', '%{Called-Station-Id}', '%{Calling-Station-Id}', '%{Service-Type}', '%{Framed-Protocol}', '%{Framed-IP-Address}')"
    accounting_update_query = "UPDATE radacct SET acctupdatetime = FROM_UNIXTIME(%{integer:Event-Timestamp}), acctinterval = '%{Acct-Interval}', acctinputoctets = '%{Acct-Input-Gigawords}' * 4294967296 + '%{Acct-Input-Octets}', acctoutputoctets = '%{Acct-Output-Gigawords}' * 4294967296 + '%{Acct-Output-Octets}' WHERE acctuniqueid = '%{Acct-Unique-Session-Id}'"
    accounting_stop_query = "UPDATE radacct SET acctstoptime = FROM_UNIXTIME(%{integer:Event-Timestamp}), acctsessiontime = '%{Acct-Session-Time}', acctinputoctets = '%{Acct-Input-Gigawords}' * 4294967296 + '%{Acct-Input-Octets}', acctoutputoctets = '%{Acct-Output-Gigawords}' * 4294967296 + '%{Acct-Output-Octets}', acctterminatecause = '%{Acct-Terminate-Cause}', connectinfo_stop = '%{Connect-Info}' WHERE acctuniqueid = '%{Acct-Unique-Session-Id}'"
    post_auth_query = "INSERT INTO radpostauth (username, pass, reply, authdate) VALUES ('%{User-Name}', '%{User-Password:-Chap-Password}', '%{reply:Packet-Type}', '%S')"
    client_query = "SELECT id, nasname, shortname, type, secret FROM nas"
}
SQLEOF

# 3. Ativa o módulo no caminho correto
echo "[3/4] Ativando módulo SQL..."
ln -sf "${RADIUS_CONF}/mods-available/sql" "${RADIUS_CONF}/mods-enabled/sql"

# 4. Ajusta permissões
echo "[4/4] Ajustando permissões..."
chown -R freerad:freerad "${RADIUS_CONF}"
mkdir -p /var/log/freeradius
chown -R freerad:freerad /var/log/freeradius

echo "=== Iniciando FreeRADIUS em modo debug ==="
exec freeradius -X
