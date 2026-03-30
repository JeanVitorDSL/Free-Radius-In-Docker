<div allign="center">

---
### Rep em construção Mudanças sendo feitas para melhor funcionamento.
---
  
</div>
# 🔐 FreeRADIUS in Docker

<div align="center">

![FreeRADIUS](https://img.shields.io/badge/FreeRADIUS-3.2.3-blue?style=for-the-badge&logo=linux)
![MariaDB](https://img.shields.io/badge/MariaDB-10.11-blue?style=for-the-badge&logo=mariadb)
![PHP](https://img.shields.io/badge/PHP-8.1-777BB4?style=for-the-badge&logo=php)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**POC completa de autenticação RADIUS com interface web de gerenciamento, tudo containerizado com Docker Compose.**

[Início Rápido](#-início-rápido) · [Estrutura](#-estrutura-do-projeto) · [Testes](#-testando-autenticação) · [daloRADIUS](#-interface-web-daloradius) · [Troubleshooting](#-troubleshooting)

</div>

---

## 📋 Sobre o Projeto

Este repositório contém uma POC (Proof of Concept) completa de um servidor RADIUS containerizado, composta por **3 serviços orquestrados via Docker Compose**:

| Serviço | Imagem | Função |
|---|---|---|
| `radius-mariadb` | `mariadb:10.11` | Banco de dados central — armazena usuários, grupos e logs de sessão |
| `radius-server` | `freeradius/freeradius-server:3.2.3` | Servidor RADIUS — autentica usuários via protocolo AAA |
| `radius-daloradius` | `php:8.1-apache` | Interface web — gerenciamento visual de usuários e relatórios |

### Arquitetura

```
  Cliente/NAS
      │
      │ UDP 1812 (Auth)
      │ UDP 1813 (Acct)
      ▼
┌─────────────────┐     SQL      ┌─────────────────┐
│  radius-server  │◄────────────►│ radius-mariadb  │
│  FreeRADIUS     │              │ MariaDB 10.11   │
│  172.20.0.20    │              │ 172.20.0.10     │
└─────────────────┘              └────────┬────────┘
                                          │ SQL
                                 ┌────────▼────────┐
                                 │radius-daloradius│
                                 │ daloRADIUS      │
                                 │ 172.20.0.30     │
                                 │ :8080 (HTTP)    │
                                 └─────────────────┘
```

---

## 📁 Estrutura do Projeto

```
Free-Radius-In-Docker/
├── docker-compose.yml              ← Orquestração dos 3 containers e rede
│
├── mariadb/
│   └── init/
│       ├── 01-schema.sql           ← Schema oficial do FreeRADIUS (tabelas)
│       └── 02-seed.sql             ← NAS clients e usuários de teste
│
├── freeradius/
│   ├── Dockerfile                  ← Imagem customizada com mariadb-client
│   ├── docker-entrypoint.sh        ← Gera módulo SQL, aguarda banco e inicia
│   └── config/
│       ├── radiusd.conf            ← Configuração principal do daemon
│       ├── clients.conf            ← NAS clients locais (fallback)
│       ├── mods-available/
│       │   └── sql                 ← Definição do módulo SQL
│       └── sites-available/
│           ├── default             ← Virtual server principal (PAP/CHAP/EAP)
│           └── inner-tunnel        ← Túnel EAP-TTLS/PEAP interno
│
├── daloradius/
│   ├── Dockerfile                  ← PHP 8.1 + Apache + daloRADIUS (GitHub)
│   └── docker-entrypoint.sh        ← Gera daloradius.conf.php e inicia Apache
│
├── test-radius.sh                  ← Suite de testes automatizados
└── README.md
```

---

## ⚡ Início Rápido

### Pré-requisitos

```bash
docker --version        # 20.10+
docker compose version  # 2.0+
```

### 1. Clone o repositório

```bash
git clone https://github.com/JeanVitorDSL/Free-Radius-In-Docker.git
cd Free-Radius-In-Docker
```

### 2. Suba os containers

```bash
docker compose up --build
```

> Na primeira execução o Docker vai baixar as imagens base (~500MB). Aguarde até ver `Ready to process requests` nos logs.

### 3. Confirme que está tudo rodando

```bash
docker compose ps
```

Saída esperada:
```
NAME                STATUS    PORTS
radius-mariadb      Up        0.0.0.0:3306->3306/tcp
radius-server       Up        0.0.0.0:1812->1812/udp, 0.0.0.0:1813->1813/udp
radius-daloradius   Up        0.0.0.0:8080->80/tcp
```

---

## 🧪 Testando Autenticação

### Script automatizado

```bash
# Adicione seu usuário ao grupo docker antes (evita sudo)
sudo usermod -aG docker $USER && newgrp docker

# Roda todos os testes
chmod +x test-radius.sh
./test-radius.sh
```

### Testes manuais com `radtest`

```bash
# Entra no container do FreeRADIUS
docker exec -it radius-server bash

# Usuários de teste (todos pré-cadastrados no banco)
radtest joao    senha123      127.0.0.1 0 testing123  # ✅ Access-Accept
radtest maria   minhasenha    127.0.0.1 0 testing123  # ✅ Access-Accept
radtest admin   admin@2024    127.0.0.1 0 testing123  # ✅ Access-Accept
radtest inativo qualquercoisa 127.0.0.1 0 testing123  # ❌ Access-Reject
radtest joao    senhaerrada   127.0.0.1 0 testing123  # ❌ Access-Reject
```

### Usuários pré-cadastrados

| Usuário | Senha | Grupo | Resultado |
|---|---|---|---|
| `joao` | `senha123` | usuarios | ✅ Accept |
| `maria` | `minhasenha` | usuarios | ✅ Accept |
| `admin` | `admin@2024` | admin | ✅ Accept |
| `inativo` | qualquer | — | ❌ Reject |

---

## 🌐 Interface Web daloRADIUS

Acesse **[http://localhost:8080/operators/](http://localhost:8080/operators/)**

```
Usuário: administrator
Senha:   radius
```

| Seção | O que fazer |
|---|---|
| Management → Users → List Users | Ver usuários cadastrados |
| Management → Users → New User | Criar novo usuário |
| Config → NAS | Gerenciar equipamentos NAS |
| Reports → Overall Stats | Estatísticas de autenticação |
| Logs → Authentication | Histórico de Accept/Reject |

---

## ➕ Adicionando Usuários

### Via SQL

```bash
docker exec -it radius-mariadb mysql -u radius -pradpass radius
```

```sql
-- Cria o usuário com senha
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('novousuario', 'Cleartext-Password', ':=', 'minhasenha');

-- Associa a um grupo
INSERT INTO radusergroup (username, groupname, priority)
VALUES ('novousuario', 'usuarios', 1);

-- Dados pessoais (visível no daloRADIUS)
INSERT INTO userinfo (username, firstname, lastname, email, creationdate)
VALUES ('novousuario', 'Novo', 'Usuario', 'novo@email.com', NOW());
```

### Via daloRADIUS

Acesse **Management → Users → New User** e preencha o formulário.

---

## 🔒 Referência: Operadores SQL do RADIUS

| Operador | Significado | Uso |
|---|---|---|
| `:=` | Força o valor | Definir senha, bloquear usuário |
| `==` | Compara (igual) | Verificar atributo |
| `=` | Atribui se vazio | Atributos de resposta ao NAS |
| `>=` | Maior ou igual | Limitar tempo de sessão |

---

## 🗄️ Consultas Úteis no Banco

```sql
-- Ver todos os usuários e senhas
SELECT username, attribute, value FROM radcheck;

-- Histórico de autenticações (Accept/Reject)
SELECT username, reply, authdate 
FROM radpostauth 
ORDER BY authdate DESC LIMIT 20;

-- Sessões ativas no momento
SELECT username, nasipaddress, acctstarttime, framedipaddress
FROM radacct 
WHERE acctstoptime IS NULL;

-- Usuários por grupo
SELECT username, groupname FROM radusergroup ORDER BY groupname;
```

---

## 📦 Comandos Docker

```bash
# Subir em background
docker compose up -d --build

# Ver logs em tempo real
docker compose logs -f

# Logs de um serviço específico
docker compose logs -f freeradius

# Parar (preserva dados)
docker compose stop

# Remover containers (preserva volume do banco)
docker compose down

# ⚠️ Reset total — apaga banco e tudo
docker compose down -v --rmi local

# Rebuildar só o FreeRADIUS
docker compose build freeradius && docker compose up -d freeradius

# Entrar nos containers
docker exec -it radius-server bash
docker exec -it radius-mariadb bash
docker exec -it radius-daloradius bash
```

---

## 🚨 Troubleshooting

**FreeRADIUS fica reiniciando**
```bash
docker compose logs freeradius
# Geralmente é o MariaDB que ainda não subiu. Aguarde 30s e tente:
docker compose restart freeradius
```

**daloRADIUS mostra erro de banco**
```bash
# Força recriar o container (regenera o conf.php)
docker compose up -d --force-recreate daloradius
```

**`radtest` não retorna resposta**
```bash
# Verifica se o FreeRADIUS está ouvindo na porta 1812
docker compose ps
docker compose logs freeradius | grep "Ready to process"
```

**Script `test-radius.sh` retorna "not found"**
```bash
# Rode com sudo ou adicione seu usuário ao grupo docker
sudo ./test-radius.sh
# ou
sudo usermod -aG docker $USER && newgrp docker && ./test-radius.sh
```

---

## 🛠️ Tecnologias

- **[FreeRADIUS 3.2.3](https://freeradius.org/)** — servidor AAA open source
- **[MariaDB 10.11](https://mariadb.org/)** — banco de dados relacional
- **[daloRADIUS](https://github.com/lirantal/daloradius)** — interface web para FreeRADIUS
- **[Docker Compose](https://docs.docker.com/compose/)** — orquestração de containers
- **[PHP 8.1](https://www.php.net/)** — runtime do daloRADIUS

---

## 📄 Licença

Distribuído sob a licença MIT. Veja `LICENSE` para mais informações.

---

<div align="center">
  Feito por <a href="https://github.com/JeanVitorDSL">JeanVitorDSL</a>
</div>
