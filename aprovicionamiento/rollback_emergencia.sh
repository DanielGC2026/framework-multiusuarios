#!/bin/bash

###############################################################################
# Nombre: emergency_rollback.sh
# Propósito: 
# Script de emergencia para revertir cambios o limpiar usuarios en caso de
# problemas, anomalías no detectadas, o necesidad de reset del sistema.
#
# Funciones:
# - Eliminar usuario específico
# - Liberar cuota de disco
# - Matar procesos de usuario
# - Reset completo del framework
#
# Uso:
# sudo ./emergency_rollback.sh [delete_user|kill_processes|reset_all]
#
# Autor: 
# Framework multiusuarios
###############################################################################

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOGFILE="/var/log/framework_emergency.log"

log_emergency() {
    echo -e "${RED}[EMERGENCIA]${NC} $1" | tee -a "$LOGFILE"
}

log_warn() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1" | tee -a "$LOGFILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOGFILE"
}

delete_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        echo "Uso: $0 delete_user <usuario>"
        exit 1
    fi
    
    log_warn "======================================"
    log_warn "ELIMINANDO USUARIO: $username"
    log_warn "======================================"
    
    read -p "¿Está seguro? (s/n): " -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_warn "Operación cancelada"
        exit 0
    fi
    
    # Matar todos los procesos del usuario
    log_emergency "Terminando procesos de $username..."
    pkill -9 -u "$username" 2>/dev/null || true
    
    # Resetear cuota
    log_emergency "Removiendo cuota de disco..."
    if getent passwd "$username" >/dev/null 2>&1; then
        UID=$(getent passwd "$username" | cut -d: -f3)
        setquota -u "$UID" 0 0 0 0 /home 2>/dev/null || true
    fi
    
    # Borrar usuario
    log_emergency "Borrando usuario del sistema..."
    userdel -rf "$username" >> "$LOGFILE" 2>&1 || {
        log_emergency "Error eliminando usuario (probablemente ya no existe)"
    }
    
    log_success "Usuario $username eliminado"
}

kill_processes() {
    local username="$1"
    
    if [ -z "$username" ]; then
        echo "Uso: $0 kill_processes <usuario>"
        exit 1
    fi
    
    log_warn "======================================"
    log_warn "MATANDO PROCESOS DE: $username"
    log_warn "======================================"
    
    # Listar procesos primero
    echo "Procesos activos:"
    ps -u "$username" 2>/dev/null || echo "No hay procesos"
    
    read -p "¿Desea terminar todos estos procesos? (s/n): " -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        log_emergency "Terminando procesos..."
        pkill -9 -u "$username" 2>/dev/null || true
        log_success "Procesos terminados"
    else
        log_warn "Operación cancelada"
    fi
}

reset_all() {
    log_emergency "======================================"
    log_emergency "RESET COMPLETO DEL FRAMEWORK"
    log_emergency "======================================"
    log_emergency "¡ADVERTENCIA! Esta operación elimina TODOS los usuarios creados."
    log_emergency "Los datos de los usuarios NO SERÁN RECUPERABLES."
    echo ""
    
    read -p "Escriba 'CONFIRMAR' para continuar: " -r
    echo
    
    if [ "$REPLY" != "CONFIRMAR" ]; then
        log_warn "Operación cancelada"
        exit 0
    fi
    
    # Obtener lista de usuarios del framework (UIDs 1000-3999)
    USERS=$(awk -F: '$3 >= 1000 && $3 < 4000 {print $1}' /etc/passwd)
    
    if [ -z "$USERS" ]; then
        log_warn "No hay usuarios del framework para eliminar"
        exit 0
    fi
    
    log_emergency "Usuarios a eliminar:"
    echo "$USERS"
    echo ""
    
    read -p "Escriba 'RESET' para confirmar la eliminación: " -r
    echo
    
    if [ "$REPLY" != "RESET" ]; then
        log_emergency "Operación cancelada"
        exit 0
    fi
    
    # Eliminar usuarios
    for user in $USERS; do
        log_emergency "Eliminando usuario: $user"
        pkill -9 -u "$user" 2>/dev/null || true
        userdel -rf "$user" >> "$LOGFILE" 2>&1 || true
    done
    
    # Desactivar cuotas
    log_emergency "Desactivando cuotas..."
    quotaoff /home 2>/dev/null || true
    
    # Limpiar directorios del framework
    log_emergency "Limpiando directorios..."
    rm -rf /opt/framework 2>/dev/null || true
    rm -rf /etc/framework 2>/dev/null || true
    
    # Deshabilitar timers
    log_emergency "Deshabilitando systemd timers..."
    systemctl stop framework-maintenance.timer 2>/dev/null || true
    systemctl stop framework-monitoring.timer 2>/dev/null || true
    systemctl stop framework-inventory.timer 2>/dev/null || true
    systemctl disable framework-maintenance.timer 2>/dev/null || true
    systemctl disable framework-monitoring.timer 2>/dev/null || true
    systemctl disable framework-inventory.timer 2>/dev/null || true
    
    log_success "Reset completado"
    log_warn "Sistema retornado a estado limpio"
}

usage() {
    cat << EOF
Uso: sudo $0 [comando] [argumentos]

Comandos de emergencia:

  delete_user <usuario>     - Eliminar un usuario específico
  kill_processes <usuario>  - Matar procesos de un usuario
  reset_all                 - Reset completo del framework (¡DESTRUCTIVO!)

Ejemplos:
  sudo $0 delete_user juan
  sudo $0 kill_processes maria
  sudo $0 reset_all

ADVERTENCIA: Estos comandos son destructivos. Use solo en emergencias.

EOF
}

# Main
if [ "$EUID" -ne 0 ]; then
    log_emergency "Se requieren privilegios de root"
    exit 1
fi

touch "$LOGFILE"

COMMAND="${1:-}"

case "$COMMAND" in
    delete_user)
        delete_user "$2"
        ;;
    kill_processes)
        kill_processes "$2"
        ;;
    reset_all)
        reset_all
        ;;
    *)
        if [ -n "$COMMAND" ]; then
            log_emergency "Comando desconocido: $COMMAND"
        fi
        usage
        exit 1
        ;;
esac

exit 0
