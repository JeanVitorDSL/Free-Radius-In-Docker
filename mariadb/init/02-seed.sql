-- =============================================================
-- 02-seed.sql  –  Dados iniciais + tabelas do daloRADIUS
-- =============================================================

USE radius;

-- -----------------------------------------------------------
-- NAS Clients
-- -----------------------------------------------------------
INSERT INTO nas (nasname, shortname, type, ports, secret, server, community, description) VALUES
  ('127.0.0.1',  'localhost',  'other', 0, 'testing123', '', '', 'Loopback - testes locais'),
  ('172.20.0.0', 'docker-net', 'other', 0, 'testing123', '', '', 'Rede interna Docker'),
  ('0.0.0.0',    'all',        'other', 0, 'testing123', '', '', 'Aceita qualquer origem (apenas POC!)');

-- -----------------------------------------------------------
-- Grupos
-- -----------------------------------------------------------
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES
  ('usuarios', 'Auth-Type', ':=', 'Local'),
  ('admin',    'Auth-Type', ':=', 'Local');

INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES
  ('admin', 'Service-Type', '=', 'Administrative-User');

-- -----------------------------------------------------------
-- Usuários de teste RADIUS
-- -----------------------------------------------------------
INSERT INTO radcheck (username, attribute, op, value) VALUES
  ('joao',    'Cleartext-Password', ':=', 'senha123'),
  ('maria',   'Cleartext-Password', ':=', 'minhasenha'),
  ('admin',   'Cleartext-Password', ':=', 'admin@2024'),
  ('inativo', 'Cleartext-Password', ':=', 'qualquercoisa'),
  ('inativo', 'Auth-Type',          ':=', 'Reject');

INSERT INTO radusergroup (username, groupname, priority) VALUES
  ('joao',  'usuarios', 1),
  ('maria', 'usuarios', 1),
  ('admin', 'admin',    1);

INSERT INTO userinfo (username, firstname, lastname, email, creationdate) VALUES
  ('joao',    'João',    'Silva',    'joao@example.com',  NOW()),
  ('maria',   'Maria',   'Souza',    'maria@example.com', NOW()),
  ('admin',   'Admin',   'RADIUS',   'admin@example.com', NOW()),
  ('inativo', 'Usuario', 'Inativo',  '',                  NOW());

-- -----------------------------------------------------------
-- Tabelas extras do daloRADIUS
-- -----------------------------------------------------------
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
  PRIMARY KEY (id),
  KEY username (username)
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

-- -----------------------------------------------------------
-- Operador administrador do daloRADIUS
-- senha em texto puro (daloRADIUS compara sem hash)
-- -----------------------------------------------------------
INSERT INTO operators (username, password, firstname, lastname, accesslevel)
VALUES ('administrator', 'radius', 'Administrator', 'Administrator', '10');

-- -----------------------------------------------------------
-- ACL completa para o administrador
-- access='1' = permitido (intval('1') === 1)
-- -----------------------------------------------------------
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

-- Confirma dados inseridos
SELECT 'Usuarios RADIUS:' AS info;
SELECT username, attribute, value FROM radcheck WHERE attribute = 'Cleartext-Password';
SELECT 'Operador daloRADIUS:' AS info;
SELECT username, password, accesslevel FROM operators;
SELECT 'ACL entries:' AS info;
SELECT COUNT(*) as total_acl FROM operators_acl;
