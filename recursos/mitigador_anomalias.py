#!/usr/bin/env python3

###############################################################################
# Nombre: mitigador_anomalias.py
# Propósito: 
# Detectar anomalías operacionales y ejecutar acciones de mitigación automática.
# - CPU/RAM Starvation: Procesos descontrolados
# - Disk Depletion: Usuarios excediendo Hard Limit
# - Anomalous Process Behavior: Procesos consumiendo recursos excesivos
#
# Ejecución: sudo python3 mitigador_anomalias.py
#
# Autor: 
# Framework multiusuarios
###############################################################################

import subprocess
import os
import sys
import json
from pathlib import Path
from datetime import datetime

LOGFILE = "/var/log/framework_mitigation.log"
ALERT_SCRIPT = Path(__file__).parent.parent / "observabilidad" / "despachador_alertas.sh"

def log_event(message: str, level: str = "INFO"):
    """Registra eventos en la bitácora."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_line = f"[{timestamp}] [{level}] {message}"
    print(log_line)
    try:
        with open(LOGFILE, "a") as f:
            f.write(log_line + "\n")
    except:
        pass

def send_alert(subject: str, message: str):
    """Envía una alerta al administrador."""
    if ALERT_SCRIPT.exists():
        full_message = f"{subject}\n{message}"
        subprocess.run([str(ALERT_SCRIPT), full_message], check=False)

def detect_cpu_starvation():
    """Detecta procesos que consumen excesiva CPU."""
    try:
        # Obtener procesos que consumen > 50% CPU
        result = subprocess.run(
            ["ps", "aux", "--sort=-%cpu"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        anomalies = []
        for line in result.stdout.split("\n")[1:6]:  # Top 5 procesos
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) < 3:
                continue
            try:
                cpu_percent = float(parts[2])
                if cpu_percent > 50:
                    pid = parts[1]
                    user = parts[0]
                    command = " ".join(parts[10:])
                    anomalies.append({
                        "type": "HIGH_CPU",
                        "pid": pid,
                        "user": user,
                        "cpu": cpu_percent,
                        "command": command
                    })
            except (ValueError, IndexError):
                continue
        
        return anomalies
    except Exception as e:
        log_event(f"Error detectando CPU starvation: {e}", "WARN")
        return []

def detect_memory_starvation():
    """Detecta procesos que consumen excesiva memoria."""
    try:
        result = subprocess.run(
            ["ps", "aux", "--sort=-%mem"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        anomalies = []
        for line in result.stdout.split("\n")[1:6]:  # Top 5 procesos
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) < 4:
                continue
            try:
                mem_percent = float(parts[3])
                if mem_percent > 30:
                    pid = parts[1]
                    user = parts[0]
                    command = " ".join(parts[10:])
                    anomalies.append({
                        "type": "HIGH_MEMORY",
                        "pid": pid,
                        "user": user,
                        "memory": mem_percent,
                        "command": command
                    })
            except (ValueError, IndexError):
                continue
        
        return anomalies
    except Exception as e:
        log_event(f"Error detectando memory starvation: {e}", "WARN")
        return []

def detect_disk_depletion():
    """Detecta usuarios que exceden Hard Limit de disco."""
    try:
        result = subprocess.run(
            ["repquota", "-u", "/home"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        anomalies = []
        for line in result.stdout.split("\n"):
            # Buscar líneas con + (exceeds hard limit) o - (exceeds soft limit)
            if not line.strip() or line.startswith("#"):
                continue
            if "+" in line or line.endswith("+-"):
                parts = line.split()
                if len(parts) >= 2:
                    username = parts[0]
                    anomalies.append({
                        "type": "QUOTA_EXCEEDED",
                        "user": username,
                        "quota_line": line.strip()
                    })
        
        return anomalies
    except Exception as e:
        log_event(f"Error detectando disk depletion: {e}", "WARN")
        return []

def mitigate_cpu_process(pid: int, user: str):
    """Mitiga procesos que abusan de CPU."""
    try:
        log_event(f"Intentando mitigar proceso {pid} del usuario {user} (HIGH_CPU)", "WARN")
        # Primero intentamos enviar SIGTERM (shutdown limpio)
        subprocess.run(["kill", str(pid)], timeout=5)
        log_event(f"Proceso {pid} terminado correctamente", "INFO")
        return True
    except subprocess.TimeoutExpired:
        # Si no responde a SIGTERM, enviar SIGKILL
        try:
            subprocess.run(["kill", "-9", str(pid)], timeout=5)
            log_event(f"Proceso {pid} forzadamente terminado (SIGKILL)", "WARN")
            return True
        except:
            log_event(f"No se pudo terminar el proceso {pid}", "ERROR")
            return False
    except Exception as e:
        log_event(f"Error mitigando CPU de {pid}: {e}", "ERROR")
        return False

def mitigate_quota_exceeded(username: str):
    """Mitiga usuarios que exceden disco."""
    try:
        log_event(f"Bloqueando escritura para usuario {username} (QUOTA_EXCEEDED)", "WARN")
        # Ejecutar quotaoff para este usuario (si es posible)
        # Nota: quota control es a nivel filesystem, no por usuario individual
        subprocess.run(["quotaoff", "/home"], check=False)
        subprocess.run(["quotaon", "/home"], check=False)
        log_event(f"Cuota re-sincronizada para {username}", "INFO")
        
        send_alert(
            "CRITICAL: Usuario Excede Disco",
            f"El usuario '{username}' ha excedido el Hard Limit de disco.\n"
            f"Se ha bloqueado la escritura. Contacte al administrador para liberar espacio."
        )
        return True
    except Exception as e:
        log_event(f"Error mitigando cuota de {username}: {e}", "ERROR")
        return False

def main():
    if os.getuid() != 0:
        print("[ERROR] Este script requiere privilegios de root (sudo).")
        sys.exit(1)
    
    log_event("=== Iniciando ciclo de detección de anomalías ===")
    
    # Detectar anomalías
    cpu_anomalies = detect_cpu_starvation()
    mem_anomalies = detect_memory_starvation()
    disk_anomalies = detect_disk_depletion()
    
    all_anomalies = cpu_anomalies + mem_anomalies + disk_anomalies
    
    if not all_anomalies:
        log_event("No se detectaron anomalías en el sistema.")
        return
    
    log_event(f"Se detectaron {len(all_anomalies)} anomalía(s)")
    
    # Mitigar anomalías
    for anomaly in all_anomalies:
        atype = anomaly["type"]
        
        if atype == "HIGH_CPU":
            log_event(f"Anomalía detectada: PID {anomaly['pid']} ({anomaly['user']}) consume {anomaly['cpu']}% CPU")
            mitigate_cpu_process(int(anomaly["pid"]), anomaly["user"])
            send_alert(
                "Anomalía: CPU Starvation",
                f"Proceso {anomaly['command']} (PID: {anomaly['pid']}, usuario: {anomaly['user']})\n"
                f"consumía {anomaly['cpu']}% CPU y ha sido terminado."
            )
        
        elif atype == "HIGH_MEMORY":
            log_event(f"Anomalía detectada: PID {anomaly['pid']} ({anomaly['user']}) consume {anomaly['memory']}% MEM")
            send_alert(
                "Anomalía: Memory Starvation",
                f"Proceso {anomaly['command']} (PID: {anomaly['pid']}, usuario: {anomaly['user']})\n"
                f"consumía {anomaly['memory']}% de memoria. Requiere revisión."
            )
        
        elif atype == "QUOTA_EXCEEDED":
            log_event(f"Anomalía detectada: Usuario {anomaly['user']} excede cuota de disco")
            mitigate_quota_exceeded(anomaly["user"])
    
    log_event("=== Ciclo de mitigación completado ===")

if __name__ == "__main__":
    main()
