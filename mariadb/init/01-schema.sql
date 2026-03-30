-- =============================================================
-- 01-schema.sql  –  Esquema Completo (FreeRADIUS + daloRADIUS)
-- =============================================================

USE radius;

-- TABELAS PADRÃO FREERADIUS
CREATE TABLE IF NOT EXISTS radcheck (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username    VARCHAR(64)  NOT NULL DEFAULT '',
  attribute   VARCHAR(64)  NOT NULL DEFAULT '',
  op          CHAR(2)      NOT NULL DEFAULT '==',
  value       VARCHAR(253) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  KEY username (username(32))
);

CREATE TABLE IF NOT EXISTS radreply (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username    VARCHAR(64)  NOT NULL DEFAULT '',
  attribute   VARCHAR(64)  NOT NULL DEFAULT '',
  op          CHAR(2)      NOT NULL DEFAULT '=',
  value       VARCHAR(253) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  KEY username (username(32))
);

CREATE TABLE IF NOT EXISTS radgroupcheck (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  groupname   VARCHAR(64)  NOT NULL DEFAULT '',
  attribute   VARCHAR(64)  NOT NULL DEFAULT '',
  op          CHAR(2)      NOT NULL DEFAULT '==',
  value       VARCHAR(253) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  KEY groupname (groupname(32))
);

CREATE TABLE IF NOT EXISTS radgroupreply (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  groupname   VARCHAR(64)  NOT NULL DEFAULT '',
  attribute   VARCHAR(64)  NOT NULL DEFAULT '',
  op          CHAR(2)      NOT NULL DEFAULT '=',
  value       VARCHAR(253) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  KEY groupname (groupname(32))
);

CREATE TABLE IF NOT EXISTS radusergroup (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username    VARCHAR(64)  NOT NULL DEFAULT '',
  groupname   VARCHAR(64)  NOT NULL DEFAULT '',
  priority    INT          NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY username (username(32))
);

CREATE TABLE IF NOT EXISTS radacct (
  radacctid         BIGINT(21)   NOT NULL AUTO_INCREMENT,
  acctsessionid     VARCHAR(64)  NOT NULL DEFAULT '',
  acctuniqueid      VARCHAR(32)  NOT NULL DEFAULT '',
  username          VARCHAR(64)  NOT NULL DEFAULT '',
  realm             VARCHAR(64)  DEFAULT '',
  nasipaddress      VARCHAR(15)  NOT NULL DEFAULT '',
  nasportid         VARCHAR(32)  DEFAULT NULL,
  nasporttype       VARCHAR(32)  DEFAULT NULL,
  acctstarttime     DATETIME     DEFAULT NULL,
  acctupdatetime    DATETIME     DEFAULT NULL,
  acctstoptime      DATETIME     DEFAULT NULL,
  acctinterval      INT(12)      DEFAULT NULL,
  acctsessiontime   INT UNSIGNED DEFAULT NULL,
  acctauthentic     VARCHAR(32)  DEFAULT NULL,
  connectinfo_start VARCHAR(50)  DEFAULT NULL,
  connectinfo_stop  VARCHAR(50)  DEFAULT NULL,
  acctinputoctets   BIGINT(20)   DEFAULT NULL,
  acctoutputoctets  BIGINT(20)   DEFAULT NULL,
  calledstationid   VARCHAR(50)  NOT NULL DEFAULT '',
  callingstationid  VARCHAR(50)  NOT NULL DEFAULT '',
  acctterminatecause VARCHAR(32) NOT NULL DEFAULT '',
  servicetype       VARCHAR(32)  DEFAULT NULL,
  framedprotocol    VARCHAR(32)  DEFAULT NULL,
  framedipaddress   VARCHAR(15)  NOT NULL DEFAULT '',
  PRIMARY KEY (radacctid),
  UNIQUE KEY acctuniqueid (acctuniqueid),
  KEY username       (username),
  KEY framedipaddress (framedipaddress),
  KEY acctsessionid  (acctsessionid),
  KEY acctsessiontime (acctsessiontime),
  KEY acctstarttime  (acctstarttime),
  KEY nasipaddress   (nasipaddress)
);

CREATE TABLE IF NOT EXISTS nas (
  id          INT(10)      NOT NULL AUTO_INCREMENT,
  nasname     VARCHAR(128) NOT NULL,
  shortname   VARCHAR(32),
  type        VARCHAR(30)  DEFAULT 'other',
  ports        INT(5),
  secret      VARCHAR(60)  NOT NULL DEFAULT 'secret',
  server      VARCHAR(64),
  community   VARCHAR(50),
  description VARCHAR(200) DEFAULT 'RADIUS Client',
  PRIMARY KEY (id),
  KEY nasname (nasname)
);

CREATE TABLE IF NOT EXISTS radpostauth (
  id          INT(11)      NOT NULL AUTO_INCREMENT,
  username    VARCHAR(64)  NOT NULL DEFAULT '',
  pass        VARCHAR(64)  NOT NULL DEFAULT '',
  reply       VARCHAR(32)  NOT NULL DEFAULT '',
  authdate    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

-- TABELAS EXTRAS DALORADIUS
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

CREATE TABLE IF NOT EXISTS userinfo (
  id            INT(10)      NOT NULL AUTO_INCREMENT,
  username      VARCHAR(64)  DEFAULT '',
  firstname     VARCHAR(200) DEFAULT '',
  lastname      VARCHAR(200) DEFAULT '',
  email         VARCHAR(200) DEFAULT '',
  creationdate  DATETIME     DEFAULT NULL,
  PRIMARY KEY (id),
  KEY username (username)
);

CREATE TABLE IF NOT EXISTS actions (
  id int(11) NOT NULL AUTO_INCREMENT,
  date datetime DEFAULT NULL,
  operator varchar(64) DEFAULT NULL,
  action varchar(128) DEFAULT NULL,
  type varchar(128) DEFAULT NULL,
  target varchar(128) DEFAULT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS accesslogs (
  id int(11) NOT NULL AUTO_INCREMENT,
  date datetime DEFAULT NULL,
  operator varchar(64) DEFAULT NULL,
  ipaddress varchar(32) DEFAULT NULL,
  PRIMARY KEY (id)
);
