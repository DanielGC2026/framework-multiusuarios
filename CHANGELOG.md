# Historial de Cambios

Todos los cambios relevantes del proyecto serán documentados en este archivo.

---

## [1.0.0] - 07/06/2026

### Agregado

#### Módulo 1 — Aprovisionamiento

- Script de creación masiva de usuarios.
- Validación de UID.
- Validación de nombre de usuario.
- Configuración de directorios esqueleto.
- Configuración global de UMASK.
- Verificación de idempotencia.

#### Módulo 2 — Gestión de Recursos

- Configuración de cuotas de disco.
- Grace Period.
- Gestión de CPU mediante Cgroups v2.
- Gestión de memoria mediante Cgroups v2.
- Pruebas de estrés.

#### Módulo 3 — Mantenimiento Autónomo

- Timers de systemd.
- Limpieza automática de archivos temporales.
- Rotación de logs.
- Detección de deriva de configuración.

#### Módulo 4 — Observabilidad

- Detección de anomalías en auth.log.
- Sistema de alertas.
- Inventario dinámico.
- Reportes JSON.
- Reportes CSV.

### Documentación

- README.
- Guía de configuración de VM.
- Documento de diseño.
- Reporte técnico de pruebas.