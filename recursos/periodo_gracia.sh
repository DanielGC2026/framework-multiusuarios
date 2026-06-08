#!/bin/bash

###############################################################################
# Nombre: periodo_gracia.sh
# 
# Propósito: 
# Definición automatizada del tiempo de tolerancia (Grace Period).
# 
# Ejecución: sudo ./periodo_gracia.sh
# 
# Autor:
# Framework multiusuarios
###############################################################################

set -euo pipefail

LOGFILE="/var/log/framework_quota_setup.log"

echo "[INFO] Configurando periodo de gracia global..." | tee -a "$LOGFILE"

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Se requieren privilegios de superusuario." >&2
    exit 1
fi

# Definir 7 días de gracia para bloques de almacenamiento de manera no interactiva
# Parámetros de setquota -t: b_grace i_grace punto_montaje (0 = mantener actual)
setquota -t 7days 0 /home >> "$LOGFILE" 2>&1

echo "[OK] Periodo de gracia establecido a 7 días en /home." | tee -a "$LOGFILE"