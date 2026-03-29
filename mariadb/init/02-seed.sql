-- =============================================================
-- 02-seed.sql  –  Dados iniciais para o POC
-- NAS clients, grupos e usuários de teste
-- =============================================================

USE radius;

-- -----------------------------------------------------------
-- NAS Client: o "localhost" representa qualquer ferramenta
-- (radtest, NAS físico, etc.) que vai se conectar ao RADIUS.
-- secret = "testing123" é o shared-secret padrão do FreeRADIUS.
-- -----------------------------------------------------------
INSERT INTO nas (nasname, shortname, type, secret, description) VALUES
  ('127.0.0.1',   'localhost',  'other', 'testing123', 'Loopback - testes locais'),
  ('172.20.0.0',  'docker-net', 'other', 'testing123', 'Rede interna Docker'),
  ('0.0.0.0',     'all',        'other', 'testing123', 'Aceita qualquer origem (apenas POC!)');

-- -----------------------------------------------------------
-- Grupos
-- -----------------------------------------------------------
-- Grupo "usuarios": sem atributos extras (acesso simples)
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES
  ('usuarios', 'Auth-Type', ':=', 'Local');

-- Grupo "admin": recebe atributo de serviço diferenciado
INSERT INTO radgroupcheck (groupname, attribute, op, value) VALUES
  ('admin', 'Auth-Type', ':=', 'Local');

INSERT INTO radgroupreply (groupname, attribute, op, value) VALUES
  ('admin', 'Service-Type', '=', 'Administrative-User');

-- -----------------------------------------------------------
-- Usuários de teste
-- Operador ":=" força o valor; "==" compara (usado em check)
-- Cleartext-Password armazena a senha em texto puro
-- (em produção use MD5-Password ou Crypt-Password)
-- -----------------------------------------------------------

-- Usuário 1: joao (grupo usuarios)
INSERT INTO radcheck (username, attribute, op, value) VALUES
  ('joao', 'Cleartext-Password', ':=', 'senha123');

INSERT INTO radusergroup (username, groupname, priority) VALUES
  ('joao', 'usuarios', 1);

INSERT INTO userinfo (username, firstname, lastname, email, creationdate) VALUES
  ('joao', 'João', 'Silva', 'joao@example.com', NOW());

-- Usuário 2: maria (grupo usuarios)
INSERT INTO radcheck (username, attribute, op, value) VALUES
  ('maria', 'Cleartext-Password', ':=', 'minhasenha');

INSERT INTO radusergroup (username, groupname, priority) VALUES
  ('maria', 'usuarios', 1);

INSERT INTO userinfo (username, firstname, lastname, email, creationdate) VALUES
  ('maria', 'Maria', 'Souza', 'maria@example.com', NOW());

-- Usuário 3: admin (grupo admin)
INSERT INTO radcheck (username, attribute, op, value) VALUES
  ('admin', 'Cleartext-Password', ':=', 'admin@2024');

INSERT INTO radusergroup (username, groupname, priority) VALUES
  ('admin', 'admin', 1);

INSERT INTO userinfo (username, firstname, lastname, email, creationdate) VALUES
  ('admin', 'Admin', 'RADIUS', 'admin@example.com', NOW());

-- Usuário 4: inativo (simulando usuário bloqueado)
-- Atributo Auth-Type := Reject rejeita o usuário sempre
INSERT INTO radcheck (username, attribute, op, value) VALUES
  ('inativo', 'Cleartext-Password', ':=', 'qualquercoisa'),
  ('inativo', 'Auth-Type',          ':=', 'Reject');

INSERT INTO userinfo (username, firstname, lastname, creationdate) VALUES
  ('inativo', 'Usuario', 'Inativo', NOW());

-- -----------------------------------------------------------
-- Confirma os dados inseridos
-- -----------------------------------------------------------
SELECT 'NAS cadastrados:' AS info;
SELECT nasname, shortname, secret FROM nas;

SELECT 'Usuários cadastrados:' AS info;
SELECT r.username, r.attribute, r.value, u.firstname, u.lastname
FROM radcheck r
LEFT JOIN userinfo u ON r.username = u.username
WHERE r.attribute = 'Cleartext-Password';
