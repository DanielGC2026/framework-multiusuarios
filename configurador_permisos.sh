#!/bin/bash

###############################################################################
# Nombre: configurador_permisos.sh
# Propósito: 
# Establecer permisos correctos en todos los scripts del framework.
#
# Uso: sudo ./configurador_permisos.sh
#
# Autor: 
# Framework multiusuarios
###############################################################################

set -eu

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Configurando permisos en scripts del framework..."

# Hacer todos los scripts ejecutables
chmod +x "$FRAMEWORK_ROOT/orquestador_framework.sh" 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/configurador_permisos.sh" 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/despliegue_rapido.sh" 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/verificador_integridad.sh" 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/aprovicionamiento"/*.sh 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/recursos"/*.sh 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/recursos"/*.py 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/mantenimiento"/*.sh 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/mantenimiento"/*.py 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/observabilidad"/*.sh 2>/dev/null || true
chmod +x "$FRAMEWORK_ROOT/observabilidad"/*.py 2>/dev/null || true

# Hacer sensibles los archivos de datos
chmod 600 "$FRAMEWORK_ROOT/aprovicionamiento/usuarios.txt" 2>/dev/null || true

echo "Permisos configurados correctamente"
ls -la "$FRAMEWORK_ROOT"/*.sh
