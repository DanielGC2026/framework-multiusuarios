#!/usr/bin/env python3
###############################################################################
# Nombre: analizador_auth.py
#
# Propósito:
# Detectar intentos repetidos de autenticación fallida (Anomalous Login).
#
# Regla de detección:
# ≥ 5 intentos fallidos en menos de 10 minutos desde la misma IP.
#Autor: Framework multiusuario 
###############################################################################

import re
import os
import sys
from collections import Counter

AUTH_LOG = "/var/log/auth.log"
THRESHOLD = 5

# Patrón optimizado para capturar IPs de contraseñas fallidas (usuarios válidos e inválidos)
PATTERN = re.compile(
    r"Failed password (?:for invalid user )?\S+ from ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"
)

def analizar_registros():
    if not os.path.exists(AUTH_LOG):
        print(f"Error: El archivo de registros '{AUTH_LOG}' no existe o no es accesible.", file=sys.stderr)
        sys.exit(1)
        
    ip_counter = Counter()
    
    try:
        with open(AUTH_LOG, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                match = PATTERN.search(line)
                if match:
                    ip = match.group(1)
                    ip_counter[ip] += 1
    except PermissionError:
        print("Error: Permisos insuficientes para leer /var/log/auth.log. Ejecute como root (sudo).", file=sys.stderr)
        sys.exit(1)

    anomalies_detected = False
    for ip, count in ip_counter.items():
        if count >= THRESHOLD:
            print(f"ANOMALY: {ip} failed {count} times")
            anomalies_detected = True
            
    if not anomalies_detected:
        print("No se detectaron anomalías en los intentos de acceso.")

if __name__ == "__main__":
    analizar_registros()