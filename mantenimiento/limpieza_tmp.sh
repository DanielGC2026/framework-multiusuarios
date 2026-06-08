#!/bin/bash

###############################################################################
# Nombre: limpieza_tmp.sh
#
# Propósito:
# Eliminar archivos temporales con más de 24 horas de inactividad.
#
# Dependencias:
# find, rm
#
# Ejecución:
# sudo ./limpieza_tmp.sh
###############################################################################

set -euo pipefail

LOGFILE="/var/log/framework_cleanup.log"

echo "[$(date)] Inicio limpieza" >> "$LOGFILE"

# -atime +1 busca archivos sin acceso en las últimas 24 horas
find /tmp \
  -type f \
  -atime +1 \
  -print \
  -delete \
  >> "$LOGFILE" 2>&1

echo "[$(date)] Fin limpieza" >> "$LOGFILE"