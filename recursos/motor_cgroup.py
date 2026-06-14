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
import subprocess
from pathlib import Path

# Directorio base de la jerarquía unificada de control del Kernel
CGROUP_ROOT = Path("/sys/fs/cgroup")
USER_GROUP = CGROUP_ROOT / "framework_users"

# Parámetros de asignación obligatorios:
# CPU: 40000 microsegundos de cuota por cada 100000 de período (Equivale a un 40% de un Core)
CPU_MAX = "40000 100000"
# Memoria RAM: Límite elástico de 1 GB expresado en Bytes
MEMORY_HIGH = str(1 * 1024 * 1024 * 1024)

def verificar_cgroups_v2():
    """Verifica que cgroups v2 está habilitado en el kernel."""
    print("[INFO] Verificando disponibilidad de cgroups v2...")
    
    # Verificar que /sys/fs/cgroup existe
    if not CGROUP_ROOT.exists():
        print(f"[ERROR] {CGROUP_ROOT} no existe. El sistema no tiene cgroups habilitado.", file=sys.stderr)
        return False
    
    # Verificar que cgroups v2 está montado
    try:
        result = subprocess.run(["mount"], capture_output=True, text=True)
        if "cgroup2" not in result.stdout and "/sys/fs/cgroup type cgroup2" not in result.stdout:
            print("[ERROR] cgroups v2 no está montado.", file=sys.stderr)
            print("[INFO] Intenta habilitar cgroups v2 en el kernel con: systemd.unified_cgroup_hierarchy=1", file=sys.stderr)
            return False
    except Exception as e:
        print(f"[ERROR] No se pudo verificar mount: {e}", file=sys.stderr)
        return False
    
    print("[✓] cgroups v2 está disponible")
    return True

def escribir_controlador(ruta_archivo: Path, valor: str):
    """Escribe un valor de control dentro de la interfaz del sistema de archivos de cgroups."""
    try:
        with open(ruta_archivo, "w") as f:
            f.write(valor + "\n")
        print(f"[✓] Configurado: {ruta_archivo} = {valor}")
    except PermissionError:
        print(f"[ERROR] Permisos insuficientes para escribir en {ruta_archivo}. ¿Ejecutó como sudo?", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"[ERROR] El archivo {ruta_archivo} no existe. Verifica que el cgroup se creó correctamente.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] No se pudo escribir en {ruta_archivo}: {e}", file=sys.stderr)
        sys.exit(1)

def inicializar_grupo_autonomo():
    """Crea el cgroup del framework y aplica las políticas de contención de recursos."""
    print("[INFO] Iniciando configuración de cgroups v2...")
    print()
    
    # Validar privilegios de root
    if os.getuid() != 0:
        print("[ERROR] Este script requiere privilegios de root (sudo).", file=sys.stderr)
        sys.exit(1)
    
    # Verificar cgroups v2
    if not verificar_cgroups_v2():
        sys.exit(1)
    
    print()
    print("[INFO] Creando cgroup framework_users...")
    
    # Crear el subgrupo si no existe
    try:
        USER_GROUP.mkdir(exist_ok=True)
        print(f"[✓] Directorio creado: {USER_GROUP}")
    except Exception as e:
        print(f"[ERROR] No se pudo crear {USER_GROUP}: {e}", file=sys.stderr)
        sys.exit(1)
    
    print()
    print("[INFO] Aplicando límites de recursos...")
    
    # Inyectar límites de hardware al controlador del kernel
    escribir_controlador(USER_GROUP / "cpu.max", CPU_MAX)
    escribir_controlador(USER_GROUP / "memory.high", MEMORY_HIGH)
    
    print()
    print("[✓] Cgroup configurado exitosamente")
    print()
    print("Detalles de la configuración:")
    print(f"  Ruta: {USER_GROUP}")
    print(f"  CPU límite: {CPU_MAX} (40% de un core)")
    print(f"  Memoria límite: {MEMORY_HIGH} bytes (1 GB)")
    print()
    print("Para verificar la configuración:")
    print(f"  cat {USER_GROUP}/cpu.max")
    print(f"  cat {USER_GROUP}/memory.high")

if __name__ == "__main__":
    inicializar_grupo_autonomo()