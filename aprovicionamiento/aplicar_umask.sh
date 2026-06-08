#!/bin/bash

# ##############################################################################
# Nombre: aplicar_umask.sh
# 
# Descripción: 
# Configura la máscara de creación de archivos (umask 027) a nivel
# global y del sistema para asegurar la privacidad entre usuarios.
# 
# Objetivo: 
# Cumplir con la Matriz de Permisos (Directorios: 750, Archivos: 640).
# 
# Autor: 
# Framework multiusuario
# ##############################################################################

set -eu

LOGFILE="/var/log/framework_umask_setup.log"
touch "$LOGFILE"

echo "[INFO] Iniciando endurecimiento de políticas de umask..." | tee -a "$LOGFILE"

# Validar que el script se ejecute como root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Este script debe ejecutarse con privilegios de superusuario (sudo)." >&2
    exit 1
fi

# 1. Configuración Global en /etc/login.defs
# Este archivo define la umask que utilizará el comando useradd al crear las home
# y la umask inicial de las sesiones de login.

LOGIN_DEFS="/etc/login.defs"

if [ -f "$LOGIN_DEFS" ]; then
    # Verificar si ya existe una directiva UMASK
    if grep -q "^UMASK" "$LOGIN_DEFS"; then
        # Reemplazar de forma segura la umask existente por 027
        sed -i 's/^UMASK.*/UMASK           027/' "$LOGIN_DEFS"
        echo "[OK] UMASK actualizada a 027 en $LOGIN_DEFS" | tee -a "$LOGFILE"
    else
        # Si no existe, se añade al final
        echo -e "\nUMASK           027" >> "$LOGIN_DEFS"
        echo "[OK] Directiva UMASK añadida a $LOGIN_DEFS" | tee -a "$LOGFILE"
    fi
else
    echo "[WARN] No se encontró el archivo $LOGIN_DEFS" | tee -a "$LOGFILE"
fi

# 2. Configuración para Sesiones Interactivas en /etc/profile
# Asegura que la umask se aplique a todos los usuarios al iniciar sesión en Bash.

ETC_PROFILE="/etc/profile"

if [ -f "$ETC_PROFILE" ]; then
    # Buscamos si el archivo ya tiene una configuración de umask estándar para modificarla
    if grep -q "umask 022" "$ETC_PROFILE"; then
        sed -i 's/umask 022/umask 027/g' "$ETC_PROFILE"
        echo "[OK] Cambiada umask por defecto en $ETC_PROFILE de 022 a 027" | tee -a "$LOGFILE"
    fi
fi

# 3. Configuración del Módulo PAM (Pluggable Authentication Modules)
# En las versiones modernas de Ubuntu, pam_umask se encarga de fijar la máscara
# al momento de la autenticación. Modificamos el perfil común.

PAM_SESSION="/etc/pam.d/common-session"

if [ -f "$PAM_SESSION" ]; then
    # Si la regla de pam_umask no está explícita, la agregamos de forma idempotente
    if ! grep -q "pam_umask.so" "$PAM_SESSION"; then
        echo "session optional pam_umask.so umask=027" >> "$PAM_SESSION"
        echo "[OK] Módulo pam_umask configurado con umask=027 en $PAM_SESSION" | tee -a "$LOGFILE"
    else
        echo "[INFO] El módulo pam_umask ya se encuentra registrado. Omitiendo." | tee -a "$LOGFILE"
    fi
fi

# 
# 4. Verificación Preventiva del Directorio Maestro /home
# Evita que los usuarios puedan listar el directorio /home global.
chmod 755 /home

echo "[INFO] Endurecimiento de umask completado con éxito." | tee -a "$LOGFILE"