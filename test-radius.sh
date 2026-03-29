#!/bin/bash
# =============================================================
# test-radius.sh  –  Script de testes automatizados do POC
# Execute: chmod +x test-radius.sh && ./test-radius.sh
# =============================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # sem cor

PASS=0
FAIL=0

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        RADIUS POC - Suite de Testes                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# -----------------------------------------------------------
# Função helper para testar autenticação
# test_auth <usuario> <senha> <esperado: accept|reject> <descricao>
# -----------------------------------------------------------
test_auth() {
  local user="$1"
  local pass="$2"
  local expected="$3"
  local desc="$4"

  # Executa radtest dentro do container
  result=$(docker exec radius-server \
    radtest "$user" "$pass" 127.0.0.1 0 testing123 2>&1)

  if echo "$result" | grep -q "Access-Accept"; then
    actual="accept"
  elif echo "$result" | grep -q "Access-Reject"; then
    actual="reject"
  else
    actual="timeout"
  fi

  if [ "$actual" = "$expected" ]; then
    echo -e "  ${GREEN}✓ PASS${NC} - $desc"
    echo -e "         (esperado: $expected, obtido: $actual)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗ FAIL${NC} - $desc"
    echo -e "         (esperado: $expected, obtido: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# -----------------------------------------------------------
# 1. Verifica se os containers estão rodando
# -----------------------------------------------------------
echo -e "${YELLOW}[1/4] Verificando containers...${NC}"

for container in radius-mariadb radius-server radius-daloradius; do
  status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not found")
  if [ "$status" = "running" ]; then
    echo -e "  ${GREEN}✓${NC} $container está rodando"
  else
    echo -e "  ${RED}✗${NC} $container: $status"
    echo -e "${RED}  ERRO: Suba os containers com 'docker compose up -d' antes de testar.${NC}"
    exit 1
  fi
done

echo ""

# -----------------------------------------------------------
# 2. Testa conectividade com o banco
# -----------------------------------------------------------
echo -e "${YELLOW}[2/4] Testando conexão com o banco...${NC}"
if docker exec radius-mariadb \
    mysql -u radius -pradpass radius \
    -e "SELECT COUNT(*) as usuarios FROM radcheck;" 2>/dev/null | grep -q "[0-9]"; then
  COUNT=$(docker exec radius-mariadb \
    mysql -u radius -pradpass radius \
    -sNe "SELECT COUNT(*) FROM radcheck;" 2>/dev/null)
  echo -e "  ${GREEN}✓${NC} MariaDB acessível - $COUNT usuários no radcheck"
else
  echo -e "  ${RED}✗${NC} Não foi possível conectar ao MariaDB"
fi

echo ""

# -----------------------------------------------------------
# 3. Testes de autenticação
# -----------------------------------------------------------
echo -e "${YELLOW}[3/4] Testando autenticação RADIUS...${NC}"

test_auth "joao"    "senha123"      "accept" "joao com senha correta"
test_auth "maria"   "minhasenha"    "accept" "maria com senha correta"
test_auth "admin"   "admin@2024"    "accept" "admin com senha correta"
test_auth "inativo" "qualquercoisa" "reject" "usuário inativo (deve rejeitar)"
test_auth "joao"    "senhaerrada"   "reject" "joao com senha errada"
test_auth "naoexiste" "senha"       "reject" "usuário inexistente"

echo ""

# -----------------------------------------------------------
# 4. Verifica log de pós-autenticação
# -----------------------------------------------------------
echo -e "${YELLOW}[4/4] Últimas autenticações no banco (radpostauth)...${NC}"
docker exec radius-mariadb \
  mysql -u radius -pradpass radius \
  -e "SELECT username, reply, authdate FROM radpostauth ORDER BY authdate DESC LIMIT 6;" \
  2>/dev/null || echo "  (tabela radpostauth vazia - normal se ainda não houve autenticações)"

echo ""

# -----------------------------------------------------------
# Resultado final
# -----------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Resultado: ${GREEN}${PASS} passaram${BLUE} / ${RED}${FAIL} falharam${BLUE} de ${TOTAL} testes       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
