#!/bin/bash

# ##############################################################################
# Nombre: aplicar_skel.sh
#
# Descripción: 
# Configura la plantilla base de perfiles para nuevos usuarios.
# 
# Objetivo: Estandarizar el entorno de trabajo inicial en /etc/skel.
# 
# Autor: 
# Framework Multiusuario
#
# ##############################################################################

# Definir el directorio objetivo
SKEL_DIR="/etc/skel"

echo "[INFO] Iniciando configuración de /etc/skel..."

# 1. Asegurar que el directorio skel exista
if [ ! -d "$SKEL_DIR" ]; then
    echo "[ERROR] El directorio $SKEL_DIR no existe."
    exit 1
fi

# 2. Configurar .bashrc
# Usamos un heredoc para escribir el contenido. 
# Se agregan alias de seguridad recomendados.
cat << 'EOF' > "$SKEL_DIR/.bashrc"
# .bashrc: Configuración del shell para usuarios
[ -z "$PS1" ] && return
export HISTCONTROL=ignoreboth
alias ls='ls --color=auto'
alias grep='grep --color=auto'
# Asegurar que el usuario no sobrescriba archivos existentes
umask 027
EOF

# 3. Configurar .profile
# Variables de entorno estándar
cat << 'EOF' > "$SKEL_DIR/.profile"
# .profile: Variables de entorno
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
mesg n 2> /dev/null || true
EOF

# 4. Configurar .vimrc (Siguiendo tu ejemplo)
cat << 'EOF' > "$SKEL_DIR/.vimrc"
" Configuración básica de Vim
set number
set tabstop=4
set expandtab
syntax on
EOF

# 5. Ajustar permisos
# Es vital que root sea el dueño de /etc/skel para que al copiar los archivos
# a los nuevos usuarios, estos hereden los permisos correctos del sistema.
chown -R root:root "$SKEL_DIR"
chmod 755 "$SKEL_DIR"
chmod 644 "$SKEL_DIR/.bashrc" "$SKEL_DIR/.profile" "$SKEL_DIR/.vimrc"

echo "[INFO] Configuración de /etc/skel finalizada correctamente."