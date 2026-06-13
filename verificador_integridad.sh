#!/bin/bash

###############################################################################
# VERIFICADOR DE INTEGRIDAD DEL FRAMEWORK
# 
# Ejecutar para verificar que todo esté correctamente instalado y funcionando.
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VERIFICACIÓN FRAMEWORK MULTIUSUARIOS                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Colores para verificaciones
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $1"
        ((FAILED++))
    fi
}

check_executable() {
    if [ -x "$1" ]; then
        echo -e "${GREEN}✓ EXECUTABLE${NC} $1"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} NOT EXECUTABLE $1"
        ((WARNINGS++))
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $1"
        ((FAILED++))
    fi
}

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Comando: $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Comando: $1"
        ((FAILED++))
    fi
}

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cambiar a directorio del framework
cd "$FRAMEWORK_ROOT" 2>/dev/null || {
    echo -e "${RED}Error: No se puede acceder a $FRAMEWORK_ROOT${NC}"
    exit 1
}

echo -e "${BLUE}1. SCRIPTS PRINCIPALES${NC}"
check_executable "./orquestador_framework.sh"
check_executable "./configurador_permisos.sh"
check_executable "./despliegue_rapido.sh"
check_executable "./verificador_integridad.sh"

echo ""
echo -e "${BLUE}2. SCRIPTS DE APROVISIONAMIENTO${NC}"
check_executable "./aprovicionamiento/validador_requisitos.sh"
check_executable "./aprovicionamiento/aplicar_skel.sh"
check_executable "./aprovicionamiento/desplegar_usuarios.sh"
check_executable "./aprovicionamiento/rollback_emergencia.sh"
check_file "./aprovicionamiento/usuarios.txt"

echo ""
echo -e "${BLUE}3. SCRIPTS DE RECURSOS${NC}"
check_executable "./recursos/motor_cgroup.py"
check_executable "./recursos/setup_cuotas.sh"
check_executable "./recursos/asignar_cuota_usuario.sh"
check_executable "./recursos/mitigador_anomalias.py"
check_executable "./recursos/inicializador_usuario.sh"

echo ""
echo -e "${BLUE}4. SCRIPTS DE MANTENIMIENTO${NC}"
check_executable "./mantenimiento/limpieza_tmp.sh"
check_executable "./mantenimiento/detector_deriva.py"
check_file "./mantenimiento/mantenimiento-framework.service"
check_file "./mantenimiento/mantenimiento-framework.timer"
check_file "./mantenimiento/monitoreo-framework.service"
check_file "./mantenimiento/monitoreo-framework.timer"

echo ""
echo -e "${BLUE}5. SCRIPTS DE OBSERVABILIDAD${NC}"
check_executable "./observabilidad/analizador_auth.py"
check_executable "./observabilidad/despachador_alertas.sh"
check_executable "./observabilidad/generador_inventario.py"
check_file "./observabilidad/inventario-framework.service"
check_file "./observabilidad/inventario-framework.timer"

echo ""
echo -e "${BLUE}6. CONFIGURACIÓN${NC}"
check_file "./configuracion/framework.yaml"
check_file "./configuracion/limits.yaml"

echo ""
echo -e "${BLUE}7. DOCUMENTACIÓN${NC}"
check_file "./INICIO_RAPIDO.md"
check_file "./ARQUITECTURA.md"
check_file "./README.md"

echo ""
echo -e "${BLUE}8. COMANDOS DISPONIBLES${NC}"
check_cmd "sudo"
check_cmd "python3"
check_cmd "bash"
check_cmd "grep"
check_cmd "awk"
check_cmd "quota"
check_cmd "mail"

echo ""
echo -e "${BLUE}9. DIRECTORIOS DEL SISTEMA${NC}"
check_dir "/home"
check_dir "/etc/skel"
check_dir "/var/log"
check_dir "/sys/fs/cgroup"

echo ""
echo -e "${BLUE}10. PRUEBAS FUNCIONALES${NC}"

# Verificar que los scripts son válidos
echo "  Validando Bash scripts..."
for script in ./aprovicionamiento/*.sh ./recursos/*.sh ./mantenimiento/*.sh ./observabilidad/*.sh ./*.sh; do
    if [ -f "$script" ] && [ "$script" != "./verificador_integridad.sh" ]; then
        if bash -n "$script" 2>/dev/null; then
            echo -e "    ${GREEN}✓${NC} $(basename "$script")"
            ((PASSED++))
        else
            echo -e "    ${RED}✗${NC} $(basename "$script") - ERROR DE SINTAXIS"
            ((FAILED++))
        fi
    fi
done

# Verificar que los scripts Python son válidos
echo "  Validando Python scripts..."
for script in ./recursos/*.py ./mantenimiento/*.py ./observabilidad/*.py; do
    if [ -f "$script" ]; then
        if python3 -m py_compile "$script" 2>/dev/null; then
            echo -e "    ${GREEN}✓${NC} $(basename "$script")"
            ((PASSED++))
        else
            echo -e "    ${RED}✗${NC} $(basename "$script") - ERROR DE SINTAXIS"
            ((FAILED++))
        fi
    fi
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}RESUMEN${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Pasadas:${NC}        $PASSED"
echo -e "${YELLOW}Advertencias:${NC}   $WARNINGS"
echo -e "${RED}Fallidas:${NC}       $FAILED"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ FRAMEWORK LISTO PARA USAR${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "  1. sudo bash orquestador_framework.sh setup"
    echo "  2. sudo bash configurador_permisos.sh"
    echo "  3. Editar: nano aprovicionamiento/usuarios.txt"
    echo "  4. sudo bash aprovicionamiento/desplegar_usuarios.sh aprovicionamiento/usuarios.txt"
    echo ""
    exit 0
else
    echo -e "${RED}✗ SE ENCONTRARON PROBLEMAS${NC}"
    exit 1
fi
