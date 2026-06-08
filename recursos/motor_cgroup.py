#!/usr/bin/env python3

###############################################################################
# Nombre: motor_cgroup.py
# Propósito: 
# Daemon/Módulo de gestión y aprovisionamiento de límites en Cgroups v2.
# 
# Ejecución: sudo python3 motor_cgroup.py
# 
# Autor:
# Framework multiusuarios
###############################################################################

import sys
import os
from pathlib import Path

# Directorio base de la jerarquía unificada de control del Kernel
CGROUP_ROOT = Path("/sys/fs/cgroup")
USER_GROUP = CGROUP_ROOT / "framework_users"

# Parámetros de asignación obligatorios:
# CPU: 40000 microsegundos de cuota por cada 100000 de período (Equivale a un 40% de un Core)
CPU_MAX = "40000 100000"
# Memoria RAM: Límite elástico de 1 GB expresado en Bytes
MEMORY_HIGH = str(1 * 1024 * 1024 * 1024)

def escribir_controlador(ruta_archivo: Path, valor: str):
    """Escribe un valor de control dentro de la interfaz del sistema de archivos de cgroups."""
    try:
        with open(ruta_archivo, "w") as f:
            f.write(value + "\n")
    except PermissionError:
        print(f"[ERROR] Permisos insuficientes para escribir en {ruta_archivo}. ¿Ejecutó como sudo?", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] No se pudo escribir en {ruta_archivo}: {e}", file=sys.stderr)
        sys.exit(1)

def inicializar_grupo_autonomo():
    """Crea el cgroup del framework y aplica las políticas de contención de recursos."""
    if os.getuid() != 0:
        print("[ERROR] Este script requiere privilegios de root (sudo).", file=sys.stderr)
        sys.exit(1)

    # Crear el subgrupo si no existe
    USER_GROUP.mkdir(exist_ok=True)

    # Inyectar límites de hardware al controlador del kernel
    escribir_controlador(USER_GROUP / "cpu.max", CPU_MAX)
    escribir_controlador(USER_GROUP / "memory.high", MEMORY_HIGH)

    print("Cgroup configurado.")

if __name__ == "__main__":
    inicializar_grupo_autonomo()