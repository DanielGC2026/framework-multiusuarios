#!/bin/bash

###############################################################################
# Nombre: init_user.sh
# Propósito: 
# Script de inicialización ejecutado cuando se crea un nuevo usuario.
# - Crear directorios iniciales
# - Configurar variables de entorno
# - Establecer límites de recursos
# - Registrar en log de auditoría
#
# Uso: init_user.sh <usuario>
#
# Autor: 
# Framework multiusuarios
###############################################################################

set -euo pipefail

USERNAME="$1"
LOGFILE="/var/log/framework_user_init.log"

if [ -z "$USERNAME" ]; then
    echo "[ERROR] Debes especificar el nombre de usuario"
    exit 1
fi

touch "$LOGFILE"

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

log_event "Inicializando usuario: $USERNAME"

# Obtener home del usuario
USERHOME=$(getent passwd "$USERNAME" | cut -d: -f6)

if [ ! -d "$USERHOME" ]; then
    log_event "Error: Home de $USERNAME no existe"
    exit 1
fi

# Crear directorios estándar
mkdir -p "$USERHOME/.config"
mkdir -p "$USERHOME/.local/share"
mkdir -p "$USERHOME/.cache"
mkdir -p "$USERHOME/Desktop"
mkdir -p "$USERHOME/Documents"
mkdir -p "$USERHOME/Downloads"

# Aplicar permisos
chown -R "$USERNAME:$USERNAME" "$USERHOME/.config"
chown -R "$USERNAME:$USERNAME" "$USERHOME/.local"
chown -R "$USERNAME:$USERNAME" "$USERHOME/.cache"
chown -R "$USERNAME:$USERNAME" "$USERHOME/Desktop"
chown -R "$USERNAME:$USERNAME" "$USERHOME/Documents"
chown -R "$USERNAME:$USERNAME" "$USERHOME/Downloads"

# Crear .bash_profile si no existe
if [ ! -f "$USERHOME/.bash_profile" ]; then
    cat > "$USERHOME/.bash_profile" << 'EOF'
# .bash_profile - Configuración de login shell
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
EOF
    chown "$USERNAME:$USERNAME" "$USERHOME/.bash_profile"
    chmod 644 "$USERHOME/.bash_profile"
fi

# Crear .gitconfig para no-ops si no existe
if [ ! -f "$USERHOME/.gitconfig" ]; then
    cat > "$USERHOME/.gitconfig" << EOF
[user]
    name = $USERNAME
    email = $USERNAME@localhost
[core]
    editor = vi
EOF
    chown "$USERNAME:$USERNAME" "$USERHOME/.gitconfig"
    chmod 644 "$USERHOME/.gitconfig"
fi

log_event "Usuario $USERNAME inicializado correctamente"

exit 0
