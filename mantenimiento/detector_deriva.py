#!/usr/bin/env python3

###############################################################################
# Nombre: detector_deriva.py
#
# Propósito:
# Detectar y corregir deriva de configuración en permisos y propietarios.
###############################################################################

import json
import subprocess
from pathlib import Path

# Estado ideal esperado del entorno multiusuario
BASELINE = {
    "/home": "755",
    "/etc/skel": "755"
}

LOGFILE = "/var/log/framework_drift.log"


def get_perm(path):
    """Obtiene los permisos actuales del directorio en formato octal."""
    result = subprocess.run(
        ["stat", "-c", "%a", path],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()


def main():
    for directory, expected in BASELINE.items():
        if not Path(directory).exists():
            continue
            
        current = get_perm(directory)

        if current != expected:
            # Registrar el evento de deriva detectada
            with open(LOGFILE, "a") as log:
                log.write(
                    f"[Drift Detectado] {directory} cambió de {current} -> esperado {expected}\n"
                )

            # Corrección automática del estado del directorio
            subprocess.run(
                ["chmod", expected, directory],
                check=True
            )


if __name__ == "__main__":
    main()