#!/bin/bash

###############################################################################
# Nombre: setup_cuotas.sh
# Propósito: 
# Inicialización y activación automática de cuotas de disco en /home.
# 
# Ejecución: sudo ./setup_cuotas.sh
#
# Autor: 
# Framework multiusuario
###############################################################################

set -euo pipefail

LOGFILE="/var/log/framework_quota_setup.log"
touch "$LOGFILE"

echo "[INFO] Iniciando configuración del subsistema de cuotas..." | tee -a "$LOGFILE"

# Validar privilegios
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Se requieren privilegios de superusuario." >&2
    exit 1
fi

# 1. Crear/Reconstruir tablas de cuotas de forma no destructiva (-m evita remontar en solo lectura)
echo "[INFO] Generando base de datos de cuotas (aquota.user)..." | tee -a "$LOGFILE"
quotacheck -cum /home >> "$LOGFILE" 2>&1

# 2. Activar el control de cuotas en el espacio de usuario
echo "[INFO] Activando cuotas en /home..." | tee -a "$LOGFILE"
quotaon -v /home >> "$LOGFILE" 2>&1

# 3. Mostrar reporte resumido inicial
echo "[INFO] Estado actual de las cuotas activas:"
repquota -s /home