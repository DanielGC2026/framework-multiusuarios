#!/bin/bash

###############################################################################
# Nombre: desplegar_usuarios.sh
#
# Descripción:
# Aprovisionamiento masivo e idempotente de usuarios.
#
# Autor:
# Framework Multiusuario
#
# Ejecución:
# sudo ./desplehar_usuarios.sh usuarios.yaml
###############################################################################

set -euo pipefail

LOGFILE="/var/log/framework_user_provision.log"

cleanup() {
    echo "Proceso interrumpido" >> "$LOGFILE"
}

trap cleanup EXIT

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Archivo inexistente"
    exit 1
fi

while IFS=':' read -r username uid
do

    [ -z "$username" ] && continue

    echo "Procesando $username"

    if id "$username" &>/dev/null
    then
        echo "[INFO] Usuario existente: $username"
        continue
    fi

    if getent passwd "$uid" &>/dev/null
    then
        echo "[ERROR] UID ocupado: $uid" | tee -a "$LOGFILE"
        continue
    fi

    if useradd \
        -u "$uid" \
        -m \
        -s /bin/bash \
        "$username"
    then

        echo "[OK] Usuario creado: $username"

    else

        echo "[ERROR] Fallo creando $username" \
        | tee -a "$LOGFILE"

        continue
    fi

done < "$CONFIG_FILE"

trap - EXIT