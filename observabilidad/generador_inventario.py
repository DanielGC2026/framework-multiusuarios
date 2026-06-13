#!/usr/bin/env python3

###############################################################################
# Nombre: generador_inventario.py
# Propósito: 
# Generar inventario dinámico del estado del sistema en formatos JSON y CSV.
# Incluye:
# - Usuarios activos
# - Procesos en ejecución por usuario
# - Consumo de recursos (CPU, memoria, disco)
# - Estado de cuotas
#
# Ejecución: sudo python3 generador_inventario.py
#
# Salida:
# - /var/log/inventory.json
# - /var/log/inventory.csv
#
# Autor: 
# Framework multiusuarios
###############################################################################

import subprocess
import json
import csv
import os
from pathlib import Path
from datetime import datetime
from collections import defaultdict

INVENTORY_JSON = "/var/log/inventory.json"
INVENTORY_CSV = "/var/log/inventory.csv"
LOGFILE = "/var/log/framework_inventory.log"

def log_event(message: str):
    """Registra eventos."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")
    try:
        with open(LOGFILE, "a") as f:
            f.write(f"[{timestamp}] {message}\n")
    except:
        pass

def get_active_users():
    """Obtiene lista de usuarios activos en el sistema."""
    try:
        result = subprocess.run(
            ["who"],
            capture_output=True,
            text=True,
            timeout=5
        )
        users = set()
        for line in result.stdout.split("\n"):
            if line.strip():
                user = line.split()[0]
                users.add(user)
        return list(users)
    except Exception as e:
        log_event(f"Error obteniendo usuarios activos: {e}")
        return []

def get_user_processes(username: str):
    """Obtiene procesos de un usuario específico."""
    try:
        result = subprocess.run(
            ["ps", "-u", username, "-o", "pid,cmd,%cpu,%mem,vsz"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        processes = []
        for line in result.stdout.split("\n")[1:]:  # Skip header
            if not line.strip():
                continue
            parts = line.split(None, 4)
            if len(parts) >= 5:
                processes.append({
                    "pid": parts[0],
                    "command": parts[4],
                    "cpu_percent": float(parts[2]) if parts[2] != "-" else 0,
                    "mem_percent": float(parts[3]) if parts[3] != "-" else 0,
                    "vsz": int(parts[4].split()[0]) if parts[4].isdigit() else 0
                })
        
        return processes
    except Exception as e:
        log_event(f"Error obteniendo procesos de {username}: {e}")
        return []

def get_disk_usage():
    """Obtiene uso de disco total del sistema."""
    try:
        result = subprocess.run(
            ["df", "-B", "1", "/home"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        for line in result.stdout.split("\n")[1:]:
            if "/home" in line:
                parts = line.split()
                return {
                    "total": int(parts[1]),
                    "used": int(parts[2]),
                    "available": int(parts[3]),
                    "percent": parts[4]
                }
        return None
    except Exception as e:
        log_event(f"Error obteniendo uso de disco: {e}")
        return None

def get_user_quota(username: str):
    """Obtiene la cuota de disco de un usuario."""
    try:
        result = subprocess.run(
            ["quota", "-w", username],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        for line in result.stdout.split("\n"):
            if "/home" in line:
                parts = line.split()
                if len(parts) >= 5:
                    return {
                        "used": int(parts[1]) * 1024,  # Convertir a bytes
                        "soft_limit": int(parts[2]) * 1024,
                        "hard_limit": int(parts[3]) * 1024,
                        "time_limit": parts[4] if len(parts) > 4 else "none"
                    }
        return None
    except Exception as e:
        log_event(f"Error obteniendo cuota de {username}: {e}")
        return None

def get_memory_info():
    """Obtiene información de memoria del sistema."""
    try:
        result = subprocess.run(
            ["free", "-b"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        for line in result.stdout.split("\n"):
            if line.startswith("Mem:"):
                parts = line.split()
                return {
                    "total": int(parts[1]),
                    "used": int(parts[2]),
                    "free": int(parts[3]),
                    "available": int(parts[6]) if len(parts) > 6 else 0
                }
        return None
    except Exception as e:
        log_event(f"Error obteniendo info de memoria: {e}")
        return None

def generate_inventory():
    """Genera inventario completo del sistema."""
    log_event("Generando inventario del sistema...")
    
    timestamp = datetime.now().isoformat()
    active_users = get_active_users()
    disk_usage = get_disk_usage()
    memory_info = get_memory_info()
    
    # Construir estructura JSON
    inventory = {
        "timestamp": timestamp,
        "system_summary": {
            "total_active_users": len(active_users),
            "disk": disk_usage,
            "memory": memory_info
        },
        "users": []
    }
    
    # Agregar info de cada usuario
    for username in sorted(active_users):
        try:
            user_info = {
                "username": username,
                "processes": get_user_processes(username),
                "quota": get_user_quota(username)
            }
            
            # Calcular totales de recursos del usuario
            total_cpu = sum(p["cpu_percent"] for p in user_info["processes"])
            total_mem = sum(p["mem_percent"] for p in user_info["processes"])
            total_vsz = sum(p["vsz"] for p in user_info["processes"])
            
            user_info["resource_summary"] = {
                "total_processes": len(user_info["processes"]),
                "cpu_percent": round(total_cpu, 2),
                "mem_percent": round(total_mem, 2),
                "total_vsz": total_vsz
            }
            
            inventory["users"].append(user_info)
        except Exception as e:
            log_event(f"Error procesando usuario {username}: {e}")
            continue
    
    return inventory

def save_json_inventory(inventory):
    """Guarda inventario en formato JSON."""
    try:
        with open(INVENTORY_JSON, "w") as f:
            json.dump(inventory, f, indent=2)
        log_event(f"Inventario JSON guardado en {INVENTORY_JSON}")
        return True
    except Exception as e:
        log_event(f"Error guardando JSON: {e}")
        return False

def save_csv_inventory(inventory):
    """Guarda inventario en formato CSV."""
    try:
        with open(INVENTORY_CSV, "w", newline="") as f:
            writer = csv.writer(f)
            
            # Header
            writer.writerow([
                "Timestamp",
                "Usuario",
                "Procesos",
                "CPU %",
                "Memoria %",
                "VSZ MB",
                "Cuota Usada MB",
                "Cuota Soft MB",
                "Cuota Hard MB"
            ])
            
            # Datos
            for user in inventory["users"]:
                quota = user.get("quota") or {}
                writer.writerow([
                    inventory["timestamp"],
                    user["username"],
                    user["resource_summary"]["total_processes"],
                    user["resource_summary"]["cpu_percent"],
                    user["resource_summary"]["mem_percent"],
                    round(user["resource_summary"]["total_vsz"] / (1024*1024), 2),
                    round(quota.get("used", 0) / (1024*1024), 2),
                    round(quota.get("soft_limit", 0) / (1024*1024), 2),
                    round(quota.get("hard_limit", 0) / (1024*1024), 2)
                ])
        
        log_event(f"Inventario CSV guardado en {INVENTORY_CSV}")
        return True
    except Exception as e:
        log_event(f"Error guardando CSV: {e}")
        return False

def main():
    if os.getuid() != 0:
        print("[ERROR] Este script requiere privilegios de root (sudo).")
        return False
    
    log_event("=== Iniciando generación de inventario ===")
    
    inventory = generate_inventory()
    
    save_json_inventory(inventory)
    save_csv_inventory(inventory)
    
    log_event("=== Generación de inventario completada ===")
    print(json.dumps(inventory, indent=2))
    
    return True

if __name__ == "__main__":
    main()
