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

# -e: muere si hay error (controlado), -u: muere si hay variables no definidas
set -eu

LOGFILE="/var/log/framework_user_provision.log"
CONFIG_FILE="${1:-}"

# Asegurar que el log exista
touch "$LOGFILE"

cleanup() {
    # El trap EXIT se activa siempre, validamos si terminó con éxito o error
    if [ $? -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRITICAL] El proceso se interrumpió inesperadamente." >> "$LOGFILE"
    fi
}
trap cleanup EXIT

# Validar argumento
if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] Debes especificar un archivo de configuración válido."
    echo "Uso: sudo $0 <ruta_archivo>"
    exit 1
fi

echo "[INFO] Iniciando aprovisionamiento..." | tee -a "$LOGFILE"

# Leer el archivo línea por línea (ignorando líneas vacías y comentarios con #)
while IFS=':' read -r username uid || [ -n "$username" ]; do
    
    # Limpiar espacios en blanco y saltar comentarios o líneas vacías
    username=$(echo "$username" | tr -d '[:space:]')
    uid=$(echo "$uid" | tr -d '[:space:]')
    
    [[ -z "$username" || "$username" == \#* ]] && continue

    echo "[PROCESANDO] Usuario: $username (UID: $uid)"

    # Validación idempotente del Usuario (Usamos getent en vez de id para evitar falsos positivos con set -e)
    if getent passwd "$username" >/dev/null 2>&1; then
        echo "[INFO] El usuario '$username' ya existe en el sistema. Omitiendo." | tee -a "$LOGFILE"
        continue
    fi

    # Validación idempotente del UID
    if getent passwd "$uid" >/dev/null 2>&1; then
        echo "[ERROR] El UID '$uid' ya está ocupado por otra cuenta. Omitiendo '$username'." | tee -a "$LOGFILE"
        continue
    fi

    # Crear el usuario utilizando la plantilla de /etc/skel de tu proyecto
    # -m fuerza la copia de /etc/skel de manera automática
    if useradd -u "$uid" -m -s /bin/bash "$username" >> "$LOGFILE" 2>&1; then
        echo "[OK] Usuario creado exitosamente: $username" | tee -a "$LOGFILE"
        
        # =====================================================================
        # DISPARADORES DEL FRAMEWORK (Aquí conectas tus otros scripts)
        # =====================================================================
        
        # 1. Ejecutar cuotas de disco para este usuario
        if [ -f "../recursos/setup_cuotas.sh" ]; then
            ../recursos/setup_cuotas.sh "$username" >> "$LOGFILE" 2>&1 || \
            echo "[WARN] No se pudieron aplicar las cuotas a $username"
        fi

        # 2. Forzar los permisos restrictivos en su HOME (Tu matriz de permisos: 750)
        chmod 750 "/home/$username"
        
    else
        echo "[ERROR] Fallo crítico al ejecutar useradd para '$username'" | tee -a "$LOGFILE"
    fi

done < "$CONFIG_FILE"

echo "[INFO] Proceso de aprovisionamiento finalizado. Revisa $LOGFILE para más detalles."
trap - EXIT