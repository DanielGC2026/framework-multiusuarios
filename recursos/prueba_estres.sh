#!/bin/bash

###############################################################################
# Nombre: prueba_estres.sh
# Propósito: 
# Simular sobreconsumo de recursos bajo el cgroup del framework.
# 
# Ejecución: ./prueba_estres.sh
#
# Autor:
# Framework multiusuario
# ###############################################################################

set -eu

CGROUP_PROCS="/sys/fs/cgroup/framework_users/cgroup.procs"

# Validar existencia del grupo de control del framework
if [ ! -f "$CGROUP_PROCS" ]; then
    echo "[ERROR] El cgroup 'framework_users' no está configurado. Ejecute motor_cgroup.py primero."
    exit 1
fi

# Auto-asignación de la terminal actual al grupo de control para asegurar el aislamiento de la prueba
echo "[INFO] Moviendo PID actual ($$) al cgroup controlado..."
echo "$$" | sudo tee "$CGROUP_PROCS" > /dev/null

echo "[INFO] Iniciando prueba de estrés por 120 segundos..."
echo "[INFO] Ejecutando 4 trabajadores de CPU concurrentes..."

# Ejecución del binario de pruebas
stress-ng \
    --cpu 4 \
    --cpu-method all \
    --vm 1 \
    --vm-bytes 900M \
    --timeout 120