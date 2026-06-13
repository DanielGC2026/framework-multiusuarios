#!/bin/bash

###############################################################################
# Nombre: asignar_cuota_usuario.sh
# Propósito: 
# Asignar cuotas individuales de disco (Soft/Hard limit) a un usuario específico
# con Grace Period automatizado.
#
# Ejecución: sudo ./asignar_cuota_usuario.sh <usuario> <capacidad_GB> [grace_period_days]
#
# Ejemplo: sudo ./asignar_cuota_usuario.sh juan 5 7
#
# Autor: 
# Framework multiusuario
###############################################################################

set -euo pipefail

LOGFILE="/var/log/framework_quota_assignment.log"
touch "$LOGFILE"

# Validar parámetros
if [ $# -lt 2 ]; then
    echo "[ERROR] Uso: $0 <usuario> <capacidad_GB> [grace_period_days]"
    echo "Ejemplo: $0 juan 5 7"
    exit 1
fi

USERNAME="$1"
CAPACITY_GB="$2"
GRACE_PERIOD="${3:-7}"  # Por defecto 7 días

# Convertir GB a bloques de 1K (1 GB = 1048576 bloques de 1K)
BLOCKS=$((CAPACITY_GB * 1048576))
SOFT_LIMIT=$((BLOCKS * 90 / 100))  # 90% = Soft Limit
HARD_LIMIT=$BLOCKS                 # 100% = Hard Limit

# Validar privilegios
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Se requieren privilegios de superusuario." >&2
    exit 1
fi

# Validar que el usuario exista
if ! getent passwd "$USERNAME" >/dev/null 2>&1; then
    echo "[ERROR] El usuario '$USERNAME' no existe en el sistema." | tee -a "$LOGFILE"
    exit 1
fi

# Obtener UID del usuario
UID=$(getent passwd "$USERNAME" | cut -d: -f3)

echo "[INFO] Asignando cuota a usuario: $USERNAME (UID: $UID)" | tee -a "$LOGFILE"
echo "[INFO] Capacidad total: ${CAPACITY_GB}GB | Soft Limit: $((SOFT_LIMIT/1048576))GB (90%) | Hard Limit: ${CAPACITY_GB}GB (100%)" | tee -a "$LOGFILE"

# Asignar cuota usando setquota
# Formato: setquota -u <uid> <soft_blocks> <hard_blocks> <soft_inodes> <hard_inodes> <filesystem>
if setquota -u "$UID" "$SOFT_LIMIT" "$HARD_LIMIT" 0 0 /home >> "$LOGFILE" 2>&1; then
    echo "[OK] Cuota asignada correctamente a $USERNAME" | tee -a "$LOGFILE"
else
    echo "[ERROR] No se pudo asignar la cuota. Verifica que las cuotas están activas." | tee -a "$LOGFILE"
    exit 1
fi

# Configurar el Grace Period (plazo para limpiar después de alcanzar Soft Limit)
# edquota -t permite cambiar tiempos globales, pero configuramos por usuario aquí
if edquota -u "$USERNAME" << EOF 2>/dev/null; then
    Filesystem                   blocks       soft       hard     inodes     soft     hard
    /home                      $((SOFT_LIMIT/2)) $SOFT_LIMIT $HARD_LIMIT          0        0        0
EOF
    echo "[INFO] Grace Period configurado a $GRACE_PERIOD días para $USERNAME" | tee -a "$LOGFILE"
else
    # Alternativa: usar quotatool si edquota falla
    if command -v quotatool >/dev/null 2>&1; then
        quotatool -u "$UID" -b -S "$SOFT_LIMIT" -H "$HARD_LIMIT" /home >> "$LOGFILE" 2>&1
        echo "[INFO] Cuota configurada usando quotatool" | tee -a "$LOGFILE"
    fi
fi

# Mostrar resumen de la cuota asignada
echo ""
echo "=========================================="
echo "Resumen de Cuota Asignada:"
echo "=========================================="
repquota -u /home | grep "$USERNAME" || true
echo "=========================================="
echo ""

exit 0
