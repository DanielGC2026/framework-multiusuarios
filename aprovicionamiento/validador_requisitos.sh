#!/bin/bash

###############################################################################
# Nombre: preflight_checks.sh
# Propósito: 
# Validar que el sistema está listo para ejecutar el framework:
# - Kernel v2 cgroups habilitado
# - Cuotas de disco activas
# - Dependencias instaladas
# - Permisos correctos
# - Estructura de directorios
#
# Ejecución: sudo ./preflight_checks.sh
#
# Autor: 
# Framework multiusuarios
###############################################################################

set -euo pipefail

LOGFILE="/var/log/framework_preflight.log"
touch "$LOGFILE"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
WARNINGS=0

check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1" | tee -a "$LOGFILE"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1" | tee -a "$LOGFILE"
        ((FAILED++))
    fi
}

warn_result() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1" | tee -a "$LOGFILE"
    ((WARNINGS++))
}

echo "==========================================================================" | tee -a "$LOGFILE"
echo "Framework Multiusuarios - Pre-Flight Checks" | tee -a "$LOGFILE"
echo "Timestamp: $(date)" | tee -a "$LOGFILE"
echo "==========================================================================" | tee -a "$LOGFILE"

# 1. Validar que se ejecuta como root
echo "" | tee -a "$LOGFILE"
echo "=== Privilegios ===" | tee -a "$LOGFILE"
if [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: Ejecutando como root" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Se requiere ejecutar como root (sudo)" | tee -a "$LOGFILE"
    ((FAILED++))
fi

# 2. Validar SO (Ubuntu 26.04+ o similar Debian)
echo "" | tee -a "$LOGFILE"
echo "=== Sistema Operativo ===" | tee -a "$LOGFILE"
if grep -q "Ubuntu" /etc/os-release || grep -q "Debian" /etc/os-release; then
    OS_VERSION=$(grep "VERSION=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    echo -e "${GREEN}✓ PASS${NC}: SO compatible detectado: $OS_VERSION" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Se requiere Ubuntu/Debian" | tee -a "$LOGFILE"
    ((FAILED++))
fi

# 3. Validar kernel version
echo "" | tee -a "$LOGFILE"
echo "=== Kernel ===" | tee -a "$LOGFILE"
KERNEL_VERSION=$(uname -r)
echo "Kernel: $KERNEL_VERSION" | tee -a "$LOGFILE"
if uname -r | grep -E "^[0-9]+\.[0-9]+" > /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}: Kernel detectado" | tee -a "$LOGFILE"
    ((PASSED++))
fi

# 4. Validar cgroups v2
echo "" | tee -a "$LOGFILE"
echo "=== Cgroups v2 ===" | tee -a "$LOGFILE"
if [ -d "/sys/fs/cgroup" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Cgroup filesystem disponible" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Cgroup filesystem no disponible" | tee -a "$LOGFILE"
    ((FAILED++))
fi

if [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Cgroups v2 unified hierarchy detectado" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ WARN${NC}: Possible cgroups v1 en uso, v2 recomendado" | tee -a "$LOGFILE"
    ((WARNINGS++))
fi

# 5. Validar dependencias
echo "" | tee -a "$LOGFILE"
echo "=== Dependencias ===" | tee -a "$LOGFILE"

DEPENDENCIES=("quota" "quotacheck" "setquota" "repquota" "mail" "python3" "grep" "awk" "sed")

for dep in "${DEPENDENCIES[@]}"; do
    if command -v "$dep" >/dev/null 2>&1 || [ -f "/bin/$dep" ] || [ -f "/usr/bin/$dep" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Comando '$dep' disponible" | tee -a "$LOGFILE"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Comando '$dep' NO encontrado" | tee -a "$LOGFILE"
        ((FAILED++))
    fi
done

# 6. Validar Python 3.12+
echo "" | tee -a "$LOGFILE"
echo "=== Python ===" | tee -a "$LOGFILE"
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    echo "Python version: $PYTHON_VERSION" | tee -a "$LOGFILE"
    echo -e "${GREEN}✓ PASS${NC}: Python3 disponible" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Python3 no encontrado" | tee -a "$LOGFILE"
    ((FAILED++))
fi

# 7. Validar estructura de directorios
echo "" | tee -a "$LOGFILE"
echo "=== Estructura de Directorios ===" | tee -a "$LOGFILE"

REQUIRED_DIRS=("/home" "/etc/skel" "/var/log" "/sys/fs/cgroup")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Directorio '$dir' existe" | tee -a "$LOGFILE"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Directorio '$dir' NO existe" | tee -a "$LOGFILE"
        ((FAILED++))
    fi
done

# 8. Validar permisos en /etc/skel
echo "" | tee -a "$LOGFILE"
echo "=== Permisos ===" | tee -a "$LOGFILE"

SKEL_PERMS=$(stat -c "%a" /etc/skel)
if [ "$SKEL_PERMS" = "755" ]; then
    echo -e "${GREEN}✓ PASS${NC}: /etc/skel tiene permisos 755" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ WARN${NC}: /etc/skel tiene permisos $SKEL_PERMS (esperado 755)" | tee -a "$LOGFILE"
    ((WARNINGS++))
fi

# 9. Validar cuotas en /home
echo "" | tee -a "$LOGFILE"
echo "=== Cuotas de Disco ===" | tee -a "$LOGFILE"

if grep -q "usrquota" /etc/fstab || mount | grep -q "usrquota"; then
    echo -e "${GREEN}✓ PASS${NC}: Cuotas de usuario habilitadas en /home" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ WARN${NC}: Cuotas de usuario NO habilitadas. Ejecute: sudo tune2fs -o usrquota /dev/..." | tee -a "$LOGFILE"
    ((WARNINGS++))
fi

# 10. Validar arquivos de log
echo "" | tee -a "$LOGFILE"
echo "=== Directorios de Logs ===" | tee -a "$LOGFILE"

LOG_DIR="/var/log"
if [ -w "$LOG_DIR" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Directorio $LOG_DIR es escribible" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Directorio $LOG_DIR NO es escribible" | tee -a "$LOGFILE"
    ((FAILED++))
fi

# 11. Validar archivo de configuración del framework
echo "" | tee -a "$LOGFILE"
echo "=== Configuración del Framework ===" | tee -a "$LOGFILE"

FRAMEWORK_DIR=$(dirname "$0")/..
if [ -f "$FRAMEWORK_DIR/configuracion/framework.yaml" ]; then
    echo -e "${GREEN}✓ PASS${NC}: framework.yaml encontrado" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: framework.yaml NO encontrado en $FRAMEWORK_DIR/configuracion/" | tee -a "$LOGFILE"
    ((FAILED++))
fi

if [ -f "$FRAMEWORK_DIR/configuracion/limits.yaml" ]; then
    echo -e "${GREEN}✓ PASS${NC}: limits.yaml encontrado" | tee -a "$LOGFILE"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: limits.yaml NO encontrado" | tee -a "$LOGFILE"
    ((FAILED++))
fi

# Resumen final
echo "" | tee -a "$LOGFILE"
echo "==========================================================================" | tee -a "$LOGFILE"
echo "RESUMEN DE VALIDACIÓN" | tee -a "$LOGFILE"
echo "==========================================================================" | tee -a "$LOGFILE"
echo -e "${GREEN}Pasadas: $PASSED${NC}" | tee -a "$LOGFILE"
echo -e "${YELLOW}Advertencias: $WARNINGS${NC}" | tee -a "$LOGFILE"
echo -e "${RED}Fallidas: $FAILED${NC}" | tee -a "$LOGFILE"
echo "==========================================================================" | tee -a "$LOGFILE"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Sistema listo para usar el framework${NC}" | tee -a "$LOGFILE"
    exit 0
else
    echo -e "${RED}✗ Se encontraron problemas críticos. Revise los logs.${NC}" | tee -a "$LOGFILE"
    exit 1
fi
