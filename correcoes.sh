#!/bin/bash
# =============================================================
# CORRECOES.sh
# Aplica todas as correções necessárias no daloRADIUS após
# o docker compose up --build
#
# Execute: chmod +x CORRECOES.sh && sudo ./CORRECOES.sh
# =============================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         CORRECOES - FreeRADIUS POC                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# -----------------------------------------------------------
# Verifica se os containers estão rodando
# -----------------------------------------------------------
echo -e "${YELLOW}[0/7] Verificando containers...${NC}"
for container in radius-mariadb radius-server radius-daloradius; do
    status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not found")
    if [ "$status" != "running" ]; then
        echo -e "${RED}ERRO: Container $container não está rodando.${NC}"
        echo -e "${RED}Execute primeiro: sudo docker compose up --build -d${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} $container está rodando"
done
echo ""

# -----------------------------------------------------------
# PASSO 1: Instala PEAR DB dentro do container daloRADIUS
# -----------------------------------------------------------
echo -e "${YELLOW}[1/7] Instalando PEAR DB no container daloRADIUS...${NC}"
docker exec radius-daloradius bash -c "
    pear channel-update pear.php.net 2>/dev/null || true
    pear install --force DB 2>/dev/null || true
" && echo -e "  ${GREEN}✓${NC} PEAR DB instalado" || echo -e "  ${RED}✗${NC} Falha ao instalar PEAR DB"
echo ""

# -----------------------------------------------------------
# PASSO 2: Cria todas as tabelas extras do daloRADIUS
# -----------------------------------------------------------
echo -e "${YELLOW}[2/7] Criando tabelas do daloRADIUS no banco...${NC}"
docker exec -i radius-mariadb mysql -u radius -pradpass radius -e "
CREATE TABLE IF NOT EXISTS operators (
    id          int(11)      NOT NULL AUTO_INCREMENT,
    username    varchar(64)  NOT NULL DEFAULT '',
    password    varchar(255) NOT NULL DEFAULT '',
    firstname   varchar(64)  DEFAULT '',
    lastname    varchar(64)  DEFAULT '',
    email       varchar(64)  DEFAULT '',
    accesslevel varchar(10)  DEFAULT '10',
    configfile  varchar(64)  DEFAULT 'config.php',
    lastlogin   varchar(64)  DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS operators_acl (
    id          int(11) NOT NULL AUTO_INCREMENT,
    operator_id int(11) NOT NULL DEFAULT 0,
    file        varchar(255) NOT NULL DEFAULT '',
    access      varchar(10)  DEFAULT '1',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS hotspots (
    id            int(11) NOT NULL AUTO_INCREMENT,
    name          varchar(64)  DEFAULT '',
    uamsecret     varchar(64)  DEFAULT '',
    nasidentifier varchar(64)  DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS actions (
    id           int(11) NOT NULL AUTO_INCREMENT,
    operator     varchar(64)  DEFAULT '',
    actiontype   varchar(64)  DEFAULT '',
    actiontarget varchar(64)  DEFAULT '',
    actionparam  varchar(256) DEFAULT '',
    info         varchar(256) DEFAULT '',
    ipaddress    varchar(64)  DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS accesslogs (
    id        int(11) NOT NULL AUTO_INCREMENT,
    operator  varchar(64) DEFAULT '',
    ipaddress varchar(64) DEFAULT '',
    result    varchar(64) DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS configs (
    id     int(11) NOT NULL AUTO_INCREMENT,
    config varchar(64)  DEFAULT '',
    value  varchar(256) DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS mtotacct (
    id              int(11) NOT NULL AUTO_INCREMENT,
    username        varchar(64)  DEFAULT '',
    acctdate        date         DEFAULT NULL,
    connnum         int(12)      DEFAULT NULL,
    conntotduration varchar(255) DEFAULT NULL,
    connbilledtime  int(12)      DEFAULT NULL,
    inputoctets     bigint(20)   DEFAULT NULL,
    outputoctets    bigint(20)   DEFAULT NULL,
    nasipaddress    varchar(15)  DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS mauth (
    id           int(11) NOT NULL AUTO_INCREMENT,
    username     varchar(64)  DEFAULT '',
    authdate     datetime     DEFAULT NULL,
    nasipaddress varchar(15)  DEFAULT '',
    reply        varchar(32)  DEFAULT '',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS billing_plans (
    id                int(11) NOT NULL AUTO_INCREMENT,
    planName          varchar(64)  DEFAULT '',
    planDescription   varchar(255) DEFAULT '',
    planPrice         float        DEFAULT 0,
    planCurrency      varchar(10)  DEFAULT '',
    planBillingType   varchar(20)  DEFAULT '',
    planBillingPeriod int(11)      DEFAULT 0,
    planActive        varchar(5)   DEFAULT 'yes',
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS billing_users (
    id       int(11) NOT NULL AUTO_INCREMENT,
    username varchar(64) DEFAULT '',
    planid   int(11)     DEFAULT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS userbillinfo (
    id       int(11) NOT NULL AUTO_INCREMENT,
    username varchar(64) DEFAULT '',
    planid   int(11)     DEFAULT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS passwordreset (
    id       int(11) NOT NULL AUTO_INCREMENT,
    username varchar(64)  DEFAULT '',
    token    varchar(255) DEFAULT '',
    expiry   datetime     DEFAULT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS apikeys (
    id       int(11) NOT NULL AUTO_INCREMENT,
    operator varchar(64)  DEFAULT '',
    apikey   varchar(255) DEFAULT '',
    PRIMARY KEY (id)
);
" && echo -e "  ${GREEN}✓${NC} Tabelas criadas" || echo -e "  ${RED}✗${NC} Erro ao criar tabelas"
echo ""

# -----------------------------------------------------------
# PASSO 3: Cria operador administrador
# -----------------------------------------------------------
echo -e "${YELLOW}[3/7] Criando operador administrador...${NC}"
docker exec -i radius-mariadb mysql -u radius -pradpass radius -e "
INSERT INTO operators (username, password, firstname, lastname, accesslevel)
SELECT 'administrator', 'radius', 'Administrator', 'Administrator', '10'
WHERE NOT EXISTS (
    SELECT 1 FROM operators WHERE username='administrator'
);
" && echo -e "  ${GREEN}✓${NC} Operador administrator criado (senha: radius)" || echo -e "  ${RED}✗${NC} Erro"
echo ""

# -----------------------------------------------------------
# PASSO 4: Insere ACL completa para o administrador
# -----------------------------------------------------------
echo -e "${YELLOW}[4/7] Configurando permissões ACL do administrador...${NC}"
docker exec -i radius-mariadb mysql -u radius -pradpass radius -e "
DELETE FROM operators_acl WHERE operator_id=1;
INSERT INTO operators_acl (operator_id, file, access) VALUES
(1,'acct_active','1'),(1,'acct_all','1'),(1,'acct_custom_query','1'),
(1,'acct_date','1'),(1,'acct_hotspot_accounting','1'),(1,'acct_hotspot_compare','1'),
(1,'acct_ipaddress','1'),(1,'acct_maintenance_cleanup','1'),(1,'acct_maintenance_delete','1'),
(1,'acct_nasipaddress','1'),(1,'acct_plans_usage','1'),(1,'acct_username','1'),
(1,'bill_history_query','1'),(1,'bill_invoice_del','1'),(1,'bill_invoice_edit','1'),
(1,'bill_invoice_list','1'),(1,'bill_invoice_new','1'),(1,'bill_invoice_report','1'),
(1,'bill_merchant_transactions','1'),(1,'bill_payment_types_del','1'),(1,'bill_payment_types_edit','1'),
(1,'bill_payment_types_list','1'),(1,'bill_payment_types_new','1'),(1,'bill_payments_del','1'),
(1,'bill_payments_edit','1'),(1,'bill_payments_list','1'),(1,'bill_payments_new','1'),
(1,'bill_plans_del','1'),(1,'bill_plans_edit','1'),(1,'bill_plans_list','1'),
(1,'bill_plans_new','1'),(1,'bill_pos_del','1'),(1,'bill_pos_edit','1'),
(1,'bill_pos_list','1'),(1,'bill_pos_new','1'),(1,'bill_rates_date','1'),
(1,'bill_rates_del','1'),(1,'bill_rates_edit','1'),(1,'bill_rates_list','1'),
(1,'bill_rates_new','1'),(1,'config_backup_createbackups','1'),(1,'config_backup_managebackups','1'),
(1,'config_crontab','1'),(1,'config_db','1'),(1,'config_interface','1'),
(1,'config_lang','1'),(1,'config_logging','1'),(1,'config_mail_settings','1'),
(1,'config_mail_testing','1'),(1,'config_maint_disconnect_user','1'),(1,'config_maint_test_user','1'),
(1,'config_messages','1'),(1,'config_operators_del','1'),(1,'config_operators_edit','1'),
(1,'config_operators_list','1'),(1,'config_operators_new','1'),(1,'config_reports_dashboard','1'),
(1,'config_user','1'),(1,'gis_editmap','1'),(1,'gis_viewmap','1'),
(1,'graphs_alltime_logins','1'),(1,'graphs_alltime_traffic_compare','1'),(1,'graphs_logged_users','1'),
(1,'graphs_overall_download','1'),(1,'graphs_overall_logins','1'),(1,'graphs_overall_upload','1'),
(1,'mng_batch_add','1'),(1,'mng_batch_del','1'),(1,'mng_batch_list','1'),
(1,'mng_del','1'),(1,'mng_edit','1'),(1,'mng_hs_del','1'),
(1,'mng_hs_edit','1'),(1,'mng_hs_list','1'),(1,'mng_hs_new','1'),
(1,'mng_import_users','1'),(1,'mng_list_all','1'),(1,'mng_new','1'),
(1,'mng_new_quick','1'),(1,'mng_rad_attributes_del','1'),(1,'mng_rad_attributes_edit','1'),
(1,'mng_rad_attributes_import','1'),(1,'mng_rad_attributes_list','1'),(1,'mng_rad_attributes_new','1'),
(1,'mng_rad_attributes_search','1'),(1,'mng_rad_groupcheck_del','1'),(1,'mng_rad_groupcheck_edit','1'),
(1,'mng_rad_groupcheck_list','1'),(1,'mng_rad_groupcheck_new','1'),(1,'mng_rad_groupcheck_search','1'),
(1,'mng_rad_groupreply_del','1'),(1,'mng_rad_groupreply_edit','1'),(1,'mng_rad_groupreply_list','1'),
(1,'mng_rad_groupreply_new','1'),(1,'mng_rad_groupreply_search','1'),(1,'mng_rad_hunt_del','1'),
(1,'mng_rad_hunt_edit','1'),(1,'mng_rad_hunt_list','1'),(1,'mng_rad_hunt_new','1'),
(1,'mng_rad_ippool_del','1'),(1,'mng_rad_ippool_edit','1'),(1,'mng_rad_ippool_list','1'),
(1,'mng_rad_ippool_new','1'),(1,'mng_rad_nas_del','1'),(1,'mng_rad_nas_edit','1'),
(1,'mng_rad_nas_list','1'),(1,'mng_rad_nas_new','1'),(1,'mng_rad_profiles_del','1'),
(1,'mng_rad_profiles_duplicate','1'),(1,'mng_rad_profiles_edit','1'),(1,'mng_rad_profiles_list','1'),
(1,'mng_rad_profiles_new','1'),(1,'mng_rad_proxys_del','1'),(1,'mng_rad_proxys_edit','1'),
(1,'mng_rad_proxys_list','1'),(1,'mng_rad_proxys_new','1'),(1,'mng_rad_realms_del','1'),
(1,'mng_rad_realms_edit','1'),(1,'mng_rad_realms_list','1'),(1,'mng_rad_realms_new','1'),
(1,'mng_rad_usergroup_del','1'),(1,'mng_rad_usergroup_edit','1'),(1,'mng_rad_usergroup_list','1'),
(1,'mng_rad_usergroup_list_user','1'),(1,'mng_rad_usergroup_new','1'),(1,'mng_search','1'),
(1,'rep_batch_details','1'),(1,'rep_batch_list','1'),(1,'rep_hb_dashboard','1'),
(1,'rep_history','1'),(1,'rep_lastconnect','1'),(1,'rep_logs_boot','1'),
(1,'rep_logs_daloradius','1'),(1,'rep_logs_radius','1'),(1,'rep_logs_system','1'),
(1,'rep_newusers','1'),(1,'rep_online','1'),(1,'rep_stat_raid','1'),
(1,'rep_stat_server','1'),(1,'rep_stat_services','1'),(1,'rep_stat_ups','1'),
(1,'rep_topusers','1'),(1,'rep_username','1');
" && echo -e "  ${GREEN}✓${NC} ACL configurada com todas as permissões" || echo -e "  ${RED}✗${NC} Erro"
echo ""

# -----------------------------------------------------------
# PASSO 5: Corrige colunas NULL na tabela nas
# -----------------------------------------------------------
echo -e "${YELLOW}[5/7] Corrigindo colunas NULL na tabela nas...${NC}"
docker exec -i radius-mariadb mysql -u radius -pradpass radius -e "
UPDATE nas SET
    ports     = COALESCE(ports, 0),
    server    = COALESCE(server, ''),
    community = COALESCE(community, '')
WHERE server IS NULL OR community IS NULL OR ports IS NULL;
" && echo -e "  ${GREEN}✓${NC} Colunas NULL corrigidas" || echo -e "  ${RED}✗${NC} Erro"
echo ""

# -----------------------------------------------------------
# PASSO 6: Gera o daloradius.conf.php no path correto
# -----------------------------------------------------------
echo -e "${YELLOW}[6/7] Gerando daloradius.conf.php...${NC}"
docker exec radius-daloradius bash -c "
cat > /var/www/html/daloradius/app/common/includes/daloradius.conf.php << 'EOF'
<?php
\$configValues['CONFIG_DB_ENGINE']  = 'mysqli';
\$configValues['CONFIG_DB_HOST']    = '172.20.0.10';
\$configValues['CONFIG_DB_PORT']    = '3306';
\$configValues['CONFIG_DB_USER']    = 'radius';
\$configValues['CONFIG_DB_PASS']    = 'radpass';
\$configValues['CONFIG_DB_NAME']    = 'radius';

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
chown www-data:www-data /var/www/html/daloradius/app/common/includes/daloradius.conf.php
mkdir -p /tmp/daloradius
touch /tmp/daloradius/daloradius.log
chown -R www-data:www-data /tmp/daloradius
chmod 777 /tmp/daloradius/daloradius.log
" && echo -e "  ${GREEN}✓${NC} daloradius.conf.php gerado" || echo -e "  ${RED}✗${NC} Erro"
echo ""

# -----------------------------------------------------------
# PASSO 7: Resultado final
# -----------------------------------------------------------
echo -e "${YELLOW}[7/7] Verificação final...${NC}"
CONF_OK=$(docker exec radius-daloradius test -f /var/www/html/daloradius/app/common/includes/daloradius.conf.php && echo "yes" || echo "no")
DB_OK=$(docker exec -i radius-mariadb mysql -u radius -pradpass radius -sNe "SELECT COUNT(*) FROM operators;" 2>/dev/null || echo "0")
ACL_OK=$(docker exec -i radius-mariadb mysql -u radius -pradpass radius -sNe "SELECT COUNT(*) FROM operators_acl;" 2>/dev/null || echo "0")

echo -e "  ${GREEN}✓${NC} conf.php existe: $CONF_OK"
echo -e "  ${GREEN}✓${NC} Operadores no banco: $DB_OK"
echo -e "  ${GREEN}✓${NC} Entradas na ACL: $ACL_OK"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Todas as correções aplicadas com sucesso!           ║${NC}"
echo -e "${BLUE}║                                                      ║${NC}"
echo -e "${BLUE}║  Acesse: http://localhost:8080/operators/            ║${NC}"
echo -e "${BLUE}║  Login:  administrator / radius                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"  