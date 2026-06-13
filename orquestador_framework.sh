#!/bin/bash

###############################################################################
# Nombre: orquestador_framework.sh
# Propósito: 
# Orquestador central del Framework Multiusuarios.
# Coordina el despliegue, configuración e inicialización de todos los módulos.
#
# Funciones:
# - Validar pre-requisitos del sistema
# - Preparar estructura base del framework
# - Inicializar cgroups v2
# - Configurar cuotas de disco
# - Desplegar usuarios
# - Inicializar systemd timers
# - Validar integridad del sistema
#
# Uso: sudo ./orquestador_framework.sh [setup|teardown|status]
#
# Autor: 
# Framework multiusuarios
###############################################################################

set -eu

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOGFILE="/var/log/framework_orchestrator.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(dirname "$SCRIPT_DIR")"

# Subcomandos
COMMAND="${1:-status}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGFILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOGFILE"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOGFILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOGFILE"
}

validate_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script requiere privilegios de root (sudo)"
        exit 1
    fi
}

setup() {
    log_info "======================================"
    log_info "Inicializando Framework Multiusuarios"
    log_info "======================================"
    
    # 1. Validar pre-requisitos
    log_info "Ejecutando pre-flight checks..."
    if [ -f "$FRAMEWORK_ROOT/aprovicionamiento/validador_requisitos.sh" ]; then
        bash "$FRAMEWORK_ROOT/aprovicionamiento/validador_requisitos.sh" || {
            log_error "Pre-flight checks fallaron. Abortando."
            return 1
        }
    else
        log_warn "validador_requisitos.sh no encontrado"
    fi
    
    # 2. Crear estructura de directorios
    log_info "Creando estructura de directorios..."
    mkdir -p /var/log/framework
    mkdir -p /etc/framework
    mkdir -p /opt/framework
    chmod 755 /var/log/framework
    chmod 755 /etc/framework
    chmod 755 /opt/framework
    log_success "Directorios creados"
    
    # 3. Copiar archivos de configuración
    log_info "Copiando archivos de configuración..."
    cp -v "$FRAMEWORK_ROOT/configuracion/framework.yaml" /etc/framework/ || log_warn "No se pudo copiar framework.yaml"
    cp -v "$FRAMEWORK_ROOT/configuracion/limits.yaml" /etc/framework/ || log_warn "No se pudo copiar limits.yaml"
    log_success "Configuraciones instaladas"
    
    # 4. Inicializar cgroups v2
    log_info "Configurando Cgroups v2..."
    if [ -f "$FRAMEWORK_ROOT/recursos/motor_cgroup.py" ]; then
        python3 "$FRAMEWORK_ROOT/recursos/motor_cgroup.py" || {
            log_warn "Error configurando cgroups (esto puede ser esperado en algunos kernels)"
        }
        log_success "Cgroups configurados"
    fi
    
    # 5. Configurar cuotas de disco base
    log_info "Inicializando sistema de cuotas..."
    if [ -f "$FRAMEWORK_ROOT/recursos/setup_cuotas.sh" ]; then
        bash "$FRAMEWORK_ROOT/recursos/setup_cuotas.sh" || {
            log_warn "Error en setup_cuotas.sh"
        }
        log_success "Cuotas inicializadas"
    fi
    
    # 6. Configurar /etc/skel
    log_info "Configurando /etc/skel..."
    if [ -f "$FRAMEWORK_ROOT/aprovicionamiento/aplicar_skel.sh" ]; then
        bash "$FRAMEWORK_ROOT/aprovicionamiento/aplicar_skel.sh" || {
            log_warn "Error configurando /etc/skel"
        }
        log_success "/etc/skel configurado"
    fi
    
    # 7. Crear directorio de scripts de sistema
    log_info "Instalando scripts auxiliares..."
    cp -v "$FRAMEWORK_ROOT/recursos"/*.py /opt/framework/ 2>/dev/null || log_warn "Error copiando scripts Python"
    cp -v "$FRAMEWORK_ROOT/recursos"/*.sh /opt/framework/ 2>/dev/null || log_warn "Error copiando scripts Bash"
    chmod +x /opt/framework/*.sh 2>/dev/null || true
    chmod +x /opt/framework/*.py 2>/dev/null || true
    log_success "Scripts instalados en /opt/framework"
    
    # 8. Mostrar resumen
    log_success "======================================"
    log_success "Framework inicializado correctamente"
    log_success "======================================"
    echo ""
    echo "Próximos pasos:"
    echo "1. Llenar usuarios.txt con datos de prueba"
    echo "2. Ejecutar: sudo ./desplegar_usuarios.sh usuarios.txt"
    echo "3. Monitorear: sudo python3 $FRAMEWORK_ROOT/observabilidad/generador_inventario.py"
    echo ""
}

teardown() {
    log_warn "======================================"
    log_warn "Desinstalando Framework Multiusuarios"
    log_warn "======================================"
    
    read -p "¿Está seguro de que desea desinstalar? (s/n): " -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        log_info "Deteniendo systemd timers..."
        systemctl stop mantenimiento-framework.timer 2>/dev/null || true
        systemctl stop monitoreo-framework.timer 2>/dev/null || true
        systemctl disable mantenimiento-framework.timer 2>/dev/null || true
        systemctl disable monitoreo-framework.timer 2>/dev/null || true
        
        log_info "Removiendo directorios..."
        rm -rf /opt/framework
        rm -rf /etc/framework
        
        log_success "Framework desinstalado"
    else
        log_info "Desinstalación cancelada"
    fi
}

status() {
    log_info "Estado del Framework Multiusuarios"
    echo ""
    
    # Verificar instalación
    if [ -d "/opt/framework" ]; then
        log_success "Directorio /opt/framework: PRESENTE"
    else
        log_warn "Directorio /opt/framework: AUSENTE"
    fi
    
    # Verificar configuración
    if [ -f "/etc/framework/framework.yaml" ]; then
        log_success "Configuración: PRESENTE"
    else
        log_warn "Configuración: AUSENTE"
    fi
    
    # Verificar cgroups
    if [ -d "/sys/fs/cgroup/framework_users" ]; then
        log_success "Cgroup framework_users: PRESENTE"
    else
        log_warn "Cgroup framework_users: AUSENTE"
    fi
    
    # Verificar cuotas
    if mount | grep -q "usrquota"; then
        log_success "Cuotas de disco: ACTIVAS"
    else
        log_warn "Cuotas de disco: INACTIVAS"
    fi
    
    # Verificar usuarios
    ACTIVE_USERS=$(who | wc -l)
    log_info "Usuarios activos: $ACTIVE_USERS"
    
    # Verificar systemd timers
    log_info "Estado de systemd timers:"
    systemctl list-timers 2>/dev/null | grep framework || log_warn "No hay timers de framework registrados"
    
    # Mostrar resumen de inventario
    if [ -f "/var/log/inventory.json" ]; then
        log_success "Inventario disponible en /var/log/inventory.json"
    else
        log_warn "Inventario no disponible"
    fi
    
    echo ""
}

usage() {
    cat << EOF
Uso: $0 [setup|teardown|status]

Subcomandos:
  setup       - Inicializar y configurar el framework (primera ejecución)
  teardown    - Desinstalar el framework (CUIDADO: Destructivo)
  status      - Mostrar estado actual del framework

Ejemplos:
  sudo $0 setup
  sudo $0 status
  sudo $0 teardown

EOF
}

# Main
validate_root

case "$COMMAND" in
    setup)
        setup
        ;;
    teardown)
        teardown
        ;;
    status)
        status
        ;;
    *)
        log_error "Comando desconocido: $COMMAND"
        usage
        exit 1
        ;;
esac

exit 0
