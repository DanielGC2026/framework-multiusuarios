#!/bin/bash

###############################################################################
# Nombre: desplegar_usuarios.sh
#
# Descripción:
# Aprovisionamiento masivo e idempotente de usuarios con integración completa
# del framework (cgroups, cuotas, permisos, monitoring).
#
# Formato del archivo de entrada:
# usuario:uid:cuota_gb
#
# Ejemplo:
# juan:1000:5
# maria:1001:8
#
# Autor:
# Framework Multiusuario
#
# Ejecución:
# sudo ./desplegar_usuarios.sh usuarios.txt
###############################################################################

set -eu

LOGFILE="/var/log/framework_user_provision.log"
CONFIG_FILE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(dirname "$SCRIPT_DIR")"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Asegurar que el log exista
touch "$LOGFILE"

cleanup() {
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRITICAL] El proceso se interrumpió inesperadamente." >> "$LOGFILE"
    fi
}
trap cleanup EXIT

# Validar privilegios
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Se requieren privilegios de root (sudo)"
    exit 1
fi

# Validar argumento
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Debes especificar un archivo de configuración válido."
    echo "Uso: sudo $0 <ruta_archivo>"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Iniciando aprovisionamiento de usuarios..." | tee -a "$LOGFILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando aprovisionamiento" >> "$LOGFILE"

USUARIOS_CREADOS=0
USUARIOS_EXISTENTES=0
USUARIOS_FALLIDOS=0

# Leer el archivo línea por línea (ignorando líneas vacías y comentarios con #)
while IFS=':' read -r username uid quota_gb || [ -n "$username" ]; do
    
    # Limpiar espacios en blanco y saltar comentarios o líneas vacías
    username=$(echo "$username" | tr -d '[:space:]')
    uid=$(echo "$uid" | tr -d '[:space:]')
    quota_gb=$(echo "$quota_gb" | tr -d '[:space:]')
    
    [[ -z "$username" || "$username" == \#* ]] && continue

    echo -e "${YELLOW}[PROCESANDO]${NC} Usuario: $username (UID: $uid, Cuota: ${quota_gb}GB)" | tee -a "$LOGFILE"

    # Validación idempotente del Usuario
    if getent passwd "$username" >/dev/null 2>&1; then
        echo -e "${YELLOW}[INFO]${NC} El usuario '$username' ya existe en el sistema. Omitiendo." | tee -a "$LOGFILE"
        ((USUARIOS_EXISTENTES++))
        continue
    fi

    # Validación idempotente del UID
    if getent passwd "$uid" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} El UID '$uid' ya está ocupado por otra cuenta. Omitiendo '$username'." | tee -a "$LOGFILE"
        ((USUARIOS_FALLIDOS++))
        continue
    fi

    # Crear el usuario
    if useradd -u "$uid" -m -s /bin/bash "$username" >> "$LOGFILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} Usuario creado: $username" | tee -a "$LOGFILE"
        ((USUARIOS_CREADOS++))
        
        # ================================================================
        # DISPARADORES DEL FRAMEWORK - INTEGRACIÓN COMPLETA
        # ================================================================
        
        # 1. Aplicar permisos restrictivos (750 = umask 027)
        if chmod 750 "/home/$username" >> "$LOGFILE" 2>&1; then
            echo "[OK] Permisos aplicados a /home/$username" >> "$LOGFILE"
        fi
        
        # 2. Asignar cuota de disco individual
        if [ -n "$quota_gb" ] && [ "$quota_gb" -gt 0 ]; then
            if [ -f "$FRAMEWORK_ROOT/recursos/asignar_cuota_usuario.sh" ]; then
                bash "$FRAMEWORK_ROOT/recursos/asignar_cuota_usuario.sh" "$username" "$quota_gb" >> "$LOGFILE" 2>&1 || {
                    echo -e "${YELLOW}[WARN]${NC} No se pudo asignar cuota a $username"
                }
            fi
        fi
        
        # 3. Asignar a cgroup del framework (si existe)
        if [ -d "/sys/fs/cgroup/framework_users" ]; then
            # Obtener PIDs del usuario y agregarlos al cgroup
            for pid in $(pgrep -u "$uid" 2>/dev/null || true); do
                echo "$pid" > "/sys/fs/cgroup/framework_users/cgroup.procs" 2>/dev/null || true
            done
            echo "[OK] Usuario agregado a cgroup framework_users" >> "$LOGFILE"
        fi
        
        # 4. Ejecutar script de inicialización del usuario (si existe)
        if [ -f "$FRAMEWORK_ROOT/recursos/inicializador_usuario.sh" ]; then
            bash "$FRAMEWORK_ROOT/recursos/inicializador_usuario.sh" "$username" >> "$LOGFILE" 2>&1 || true
        fi
        
    else
        echo -e "${RED}[ERROR]${NC} Fallo al crear usuario '$username'" | tee -a "$LOGFILE"
        ((USUARIOS_FALLIDOS++))
    fi

done < "$CONFIG_FILE"

# Resumen final
echo "" | tee -a "$LOGFILE"
echo "========================================" | tee -a "$LOGFILE"
echo "RESUMEN DE APROVISIONAMIENTO" | tee -a "$LOGFILE"
echo "========================================" | tee -a "$LOGFILE"
echo -e "${GREEN}Usuarios creados: $USUARIOS_CREADOS${NC}" | tee -a "$LOGFILE"
echo -e "${YELLOW}Usuarios existentes: $USUARIOS_EXISTENTES${NC}" | tee -a "$LOGFILE"
echo -e "${RED}Usuarios fallidos: $USUARIOS_FALLIDOS${NC}" | tee -a "$LOGFILE"
echo "========================================" | tee -a "$LOGFILE"
echo "Logs completos en: $LOGFILE"
echo ""

# Generar inventario
if [ -f "$FRAMEWORK_ROOT/observabilidad/generador_inventario.py" ]; then
    echo "Generando inventario del sistema..."
    python3 "$FRAMEWORK_ROOT/observabilidad/generador_inventario.py" >> "$LOGFILE" 2>&1 || true
fi

trap - EXIT
exit 0
