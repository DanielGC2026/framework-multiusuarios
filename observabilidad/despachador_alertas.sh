#!/bin/bash
###############################################################################
# Nombre: despachador_alertas.sh
#
# Propósito:
# Enviar alertas administrativas ante anomalías operacionales encontradas.
###############################################################################

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Uso: $0 \"Descripción del evento/alerta\""
    exit 1
fi

EVENT="$1"
ADMIN="root@localhost"
LOGFILE="/var/log/framework_alerts.log"

# Registrar el evento en la bitácora local
echo "$(date '+%Y-%m-%d %H:%M:%S') - $EVENT" >> "$LOGFILE" 2>/dev/null || echo "Aviso: No se pudo escribir en $LOGFILE"

# Enviar notificación por correo local al administrador
if command -v mail &> /dev/null; then
    echo "$EVENT" | mail -s "Framework Alert" "$ADMIN"
    echo "Notificación enviada a $ADMIN por correo electrónico."
else
    echo "Error: El comando 'mail' no está disponible. Instale 'mailutils'." >&2
    exit 1
fi