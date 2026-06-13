# Framework Multiusuarios - Guía de Inicio Rápido

## Instalación y Configuración

### Paso 1: Pre-flight Checks
Valida que el sistema esté listo:
```bash
sudo bash aprovicionamiento/validador_requisitos.sh
```

### Paso 2: Setup del Framework
Inicializa todos los componentes:
```bash
sudo bash orquestador_framework.sh setup
```

### Paso 3: Preparar Dataset de Usuarios
Edita el archivo de usuarios:
```bash
nano aprovicionamiento/usuarios.txt
```

Formato (usuario:uid:cuota_gb):
```
juan:1000:5
maria:1001:8
stress_user_1:2000:20
```

### Paso 4: Desplegar Usuarios
Crea todos los usuarios desde el archivo:
```bash
sudo bash aprovicionamiento/desplegar_usuarios.sh aprovicionamiento/usuarios.txt
```

---

## Operación Diaria

### Ver Estado del Framework
```bash
sudo bash orquestador_framework.sh status
```

### Visualizar Inventario (JSON)
```bash
sudo python3 observabilidad/generador_inventario.py
cat /var/log/inventory.json | python3 -m json.tool
```

### Ver Cuotas de Usuarios
```bash
sudo repquota /home
```

### Revisar Anomalías
```bash
sudo python3 recursos/mitigador_anomalias.py
tail -f /var/log/framework_mitigation.log
```

### Ver Logs Principales
```bash
# Aprovisionamiento
tail -f /var/log/framework_user_provision.log

# Detección de deriva
tail -f /var/log/framework_drift.log

# Alertas
tail -f /var/log/framework_alerts.log

# Orquestador
tail -f /var/log/framework_orchestrator.log
```

---

## Gestión de Usuarios

### Agregar Nuevo Usuario
```bash
# 1. Agregar línea a usuarios.txt
echo "nuevo_user:1100:10" >> aprovicionamiento/usuarios.txt

# 2. Ejecutar despliegue
sudo bash aprovicionamiento/desplegar_usuarios.sh aprovicionamiento/usuarios.txt
```

### Eliminar Usuario
```bash
sudo bash aprovicionamiento/rollback_emergencia.sh delete_user juan
```

### Matar Procesos de Usuario
```bash
sudo bash aprovicionamiento/rollback_emergencia.sh kill_processes maria
```

### Asignar Cuota a Usuario Existente
```bash
sudo bash recursos/asignar_cuota_usuario.sh juan 10 7
# Argumentos: usuario, capacidad_GB, grace_period_days
```

---

## Monitoreo Automático

### Systemd Timers Disponibles
```bash
# Listar timers del framework
systemctl list-timers '*framework*'

# Habilitar timers
sudo systemctl enable mantenimiento-framework.timer
sudo systemctl enable monitoreo-framework.timer
sudo systemctl enable inventario-framework.timer

# Iniciar timers
sudo systemctl start mantenimiento-framework.timer
sudo systemctl start monitoreo-framework.timer
sudo systemctl start inventario-framework.timer

# Ver estado
sudo systemctl status monitoreo-framework.timer
```

### Ejecutar Tareas Manualmente
```bash
# Limpiar /tmp (archivos > 24h)
sudo bash mantenimiento/limpieza_tmp.sh

# Detectar deriva de configuración
sudo python3 mantenimiento/detector_deriva.py

# Monitorear anomalías
sudo python3 recursos/mitigador_anomalias.py

# Generar inventario
sudo python3 observabilidad/generador_inventario.py
```

---

## Estructura de Directorios

```
framework-multiusuarios/
├── orquestador_framework.sh        # Orquestador maestro
├── configurador_permisos.sh        # Configurar permisos
├── despliegue_rapido.sh            # Despliegue automático
├── verificador_integridad.sh       # Validación
├── aprovicionamiento/
│   ├── validador_requisitos.sh     # Validación pre-requisitos
│   ├── aplicar_skel.sh             # Configurar /etc/skel
│   ├── desplegar_usuarios.sh       # Crear usuarios en masa
│   ├── usuarios.txt                # Dataset de usuarios
│   └── rollback_emergencia.sh      # Rollback/emergencia
├── recursos/
│   ├── motor_cgroup.py             # Gestión de cgroups v2
│   ├── setup_cuotas.sh             # Inicializar cuotas
│   ├── asignar_cuota_usuario.sh    # Cuota individual
│   ├── mitigador_anomalias.py      # Detección y mitigación
│   └── inicializador_usuario.sh    # Inicialización de usuario
├── mantenimiento/
│   ├── limpieza_tmp.sh             # Limpiar temporales
│   ├── detector_deriva.py          # Detectar cambios
│   ├── mantenimiento-framework.service
│   ├── mantenimiento-framework.timer
│   ├── monitoreo-framework.service
│   ├── monitoreo-framework.timer
│   └── logrotate_core.conf
├── observabilidad/
│   ├── analizador_auth.py          # Detectar login anómalos
│   ├── despachador_alertas.sh      # Enviar alertas
│   ├── generador_inventario.py     # Reporte de usuarios
│   ├── inventario-framework.service
│   └── inventario-framework.timer
└── configuracion/
    ├── framework.yaml              # Configuración principal
    └── limits.yaml                 # Límites de recursos
```

---

## Archivos de Logs

| Log | Descripción |
|-----|------------|
| `/var/log/framework_user_provision.log` | Creación de usuarios |
| `/var/log/framework_drift.log` | Cambios de configuración |
| `/var/log/framework_alerts.log` | Alertas generadas |
| `/var/log/framework_quota_assignment.log` | Asignación de cuotas |
| `/var/log/framework_mitigation.log` | Mitigación de anomalías |
| `/var/log/framework_orchestrator.log` | Orquestador |
| `/var/log/inventory.json` | Inventario en JSON |
| `/var/log/inventory.csv` | Inventario en CSV |

---

## Parámetros de Configuración

Ver `configuracion/limits.yaml`:

```yaml
quotas:
  disk:
    soft_limit_percent: 90      # Advertencia
    hard_limit_percent: 100     # Bloqueo
    grace_period: "7days"       # Plazo para limpiar

cgroups:
  cpu:
    max_percentage: 40          # 40% de un core
  memory:
    memory_high_bytes: 1GB      # Límite elástico

permissions:
  umask: "027"                  # 750 = no lectura para otros

security:
  failed_login_threshold: 5     # Intentos fallidos
  failed_login_window_minutes: 10
```

---

## Solución de Problemas

### Problema: Usuarios no se crean
```bash
# 1. Validar archivo usuarios.txt
cat aprovicionamiento/usuarios.txt

# 2. Ejecutar preflight checks
sudo bash aprovicionamiento/validador_requisitos.sh

# 3. Ver logs
tail -f /var/log/framework_user_provision.log
```

### Problema: Cuotas no funcionan
```bash
# Verificar que estén activas
mount | grep usrquota

# Reconstruir base de datos de cuotas
sudo quotacheck -cum /home
sudo quotaon /home

# Ver estado
sudo repquota /home
```

### Problema: Cgroups no encontrado
```bash
# Verificar que v2 está activo
ls -la /sys/fs/cgroup/cgroup.controllers

# Recrear cgroup
sudo python3 recursos/motor_cgroup.py
```

### Emergencia: Reset completo
```bash
# ¡ADVERTENCIA! Elimina TODOS los usuarios del framework
sudo bash aprovicionamiento/rollback_emergencia.sh reset_all
```

---

## Próximas Implementaciones

- [ ] Dashboard web en tiempo real
- [ ] API REST para automatización
- [ ] Integración con LDAP/Active Directory
- [ ] Snapshots automáticos de usuarios
- [ ] Análisis predictivo de anomalías
- [ ] Backup automático de directorios

---

## Contacto y Soporte

Proyecto: Framework Multiusuarios de Alta Disponibilidad
Institución: Facultad de Contaduría y Administración UNAM
Integrantes: Daniel González, Uriel Hernández, Eduardo Merino
