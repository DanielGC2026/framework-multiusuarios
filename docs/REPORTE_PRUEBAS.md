# Reporte Técnico de Pruebas de Estrés

## Introducción

Este documento detalla los procedimientos para ejecutar pruebas de estrés en el framework multiusuarios. Las pruebas están diseñadas para validar el comportamiento del sistema bajo condiciones de alta carga, asegurando que los cgroups, cuotas de disco y límites de recursos funcionan correctamente.

## Requisitos Previos

Antes de ejecutar las pruebas de estrés, asegúrate de que:

1. El framework multiusuarios está completamente instalado y configurado siguiendo la [GUIA_MV.md]

2. Los servicios del framework están activos:
    - sudo systemctl status mantenimiento-framework.service
    - sudo systemctl status monitoreo-framework.service
    - sudo systemctl status inventario-framework.service

3. Al menos hay un usuario creado en el sistema con el comando:
    - sudo bash aprovicionamiento/desplegar_usuarios.sh aprovicionamiento/usuarios.txt

4. El grupo de control (cgroup) "framework_users" está configurado. Si no existe, créalo de la siguiente manera:
    
    Ejecuta el orquestador del framework que configurará todo automáticamente:
    - sudo bash orquestador_framework.sh setup
    
    Comprueba que el cgroup se creó correctamente:
    - ls /sys/fs/cgroup/framework_users/
    
    Deberías ver archivos como: cpu.max, memory.high, cgroup.procs, etc.
    
    Si deseas verificar los límites configurados:
    - cat /sys/fs/cgroup/framework_users/cpu.max
    - cat /sys/fs/cgroup/framework_users/memory.high

5. La herramienta stress-ng está instalada:
    - stress-ng --version

    Si no está instalada, ejecuta:
    - sudo apt install stress-ng

## Prueba 1: Prueba de Estrés General del Framework

Esta prueba valida que el framework puede manejar carga simultánea de CPU y memoria dentro de los límites configurados en los cgroups.

### Pasos para ejecutar la prueba:

1. Abre una terminal en el directorio del framework:
    - cd ~/framework-multiusuarios

2. Asigna permisos de ejecución al script de prueba (si aún no los tiene):
    - chmod +x recursos/prueba_estres.sh

3. Ejecuta el script de prueba de estrés:
    - sudo bash recursos/prueba_estres.sh

    **Imagen 1**: Ejecución del script de prueba de estrés inicial

4. El sistema ejecutará durante 120 segundos (2 minutos) con:
    - 4 trabajadores de CPU
    - 1 trabajador de memoria con 900 MB de consumo
    - El proceso se aislará automáticamente en el cgroup del framework

5. Durante la ejecución, observa la salida en la terminal. La prueba mostrará:
    - Confirmación de movimiento del PID al cgroup
    - Fecha y hora de inicio de la prueba
    - Información de los trabajadores de estrés activos

    **Imagen 2**: Salida de la prueba durante la ejecución

### Verificación de resultados:

6. Una vez finalizada la prueba (después de 120 segundos), verifica que:
    - No hay errores críticos en la salida
    - El sistema permanece responsivo

7. Abre una segunda terminal para monitorear el consumo de recursos en tiempo real mientras se ejecuta la prueba:
    - top

    **Imagen 3**: Monitoreo con 'top' durante la prueba de estrés

8. En el mismo monitor, verifica el estado del cgroup:
    - cat /sys/fs/cgroup/framework_users/cpu.max
    - cat /sys/fs/cgroup/framework_users/memory.max

    **Imagen 4**: Límites configurados en los cgroups

## Prueba 2: Prueba de Estrés de CPU Avanzada

Esta prueba valida específicamente la limitación de CPU por usuario mediante cgroups v2.

### Pasos para ejecutar la prueba:

1. En la terminal, navega al directorio del framework:
    - cd ~/framework-multiusuarios

2. Ejecuta stress-ng directamente para simular 100% de carga de CPU durante 60 segundos:
    - sudo stress-ng --cpu 8 --cpu-method all --timeout 60

    **Imagen 5**: Ejecución de prueba avanzada de CPU

3. Mientras se ejecuta, abre otra terminal y monitorea con 'top':
    - top

    Presiona 'f' para agregar columnas y selecciona '%CPU' para ordenar por consumo de CPU

    **Imagen 6**: Visualización de CPU en 'top' ordenado por uso de CPU

4. Verifica que el consumo de CPU no supere el límite configurado en los cgroups (40% según configuración):
    - watch -n 1 'cat /sys/fs/cgroup/framework_users/cpu.stat'

    **Imagen 7**: Estadísticas de CPU del cgroup en tiempo real

### Interpretación de resultados:

5. Si el CPU no supera el 40%, significa que:
    - Los cgroups están correctamente limitando recursos
    - El framework está protegiendo otros usuarios del sistema

6. Si el CPU supera el 40%, verifica:
    - Que el cgroup framework_users existe y está activo
    - Que el kernel tiene cgroups v2 habilitado
    - Ejecuta: grep cgroup /proc/filesystems

## Prueba 3: Prueba de Estrés de Memoria

Esta prueba valida la limitación de memoria por usuario mediante cgroups v2.

### Pasos para ejecutar la prueba:

1. Ejecuta stress-ng con énfasis en asignación de memoria:
    - sudo stress-ng --vm 2 --vm-bytes 2G --timeout 60

    **Imagen 8**: Ejecución de prueba de memoria avanzada

2. En una segunda terminal, monitorea el consumo de memoria:
    - watch -n 1 'free -h'

    **Imagen 9**: Estado de memoria durante la prueba

3. Verifica que la memoria asignada al cgroup no supera el límite configurado (1 GB por usuario):
    - watch -n 1 'cat /sys/fs/cgroup/framework_users/memory.current'

    **Imagen 10**: Consumo actual de memoria del cgroup

4. Observa si el sistema activa swap o si hay mensajes de OOM (Out of Memory):
    - tail -f /var/log/syslog | grep -i "memory\|oom"

    **Imagen 11**: Verificación de mensajes de OOM en los logs

### Interpretación de resultados:

5. Si la memoria se limita a 1 GB y no hay OOM killer:
    - Los límites de memoria están funcionando correctamente
    - El framework protege la estabilidad del sistema

6. Si aparecen errores de OOM:
    - Los procesos excesivos se están deteniendo (esperado)
    - El framework está funcionando como se espera para contener anomalías

## Prueba 4: Prueba de Estrés de Disco y Cuotas

Esta prueba valida que las cuotas de disco funcionan correctamente y los usuarios no pueden exceder sus límites.

### Pasos para ejecutar la prueba:

1. Verifica el estado actual de cuotas de disco:
    - sudo repquota -a

    **Imagen 12**: Estado de cuotas antes de la prueba

2. Crea un archivo de prueba grande para llenar el disco del usuario:
    - dd if=/dev/zero of=archivo_prueba.img bs=1M count=1000

    Esto crea un archivo de aproximadamente 1 GB

    **Imagen 13**: Creación de archivo para llenar cuota

3. Verifica si el sistema impide exceder el límite configurado (Hard Limit):
    - sudo repquota -a

    **Imagen 14**: Estado de cuotas después de intentar exceder límite

4. Intenta crear otro archivo para verificar el bloqueo de cuota:
    - dd if=/dev/zero of=archivo_prueba2.img bs=1M count=1000

    Debería fallar con "Disk quota exceeded"

    **Imagen 15**: Mensaje de error al exceder cuota

### Interpretación de resultados:

5. Si el sistema bloquea la escritura al alcanzar Hard Limit:
    - Las cuotas están correctamente configuradas
    - El framework protege el almacenamiento del sistema

6. Si se permite exceder el límite:
    - Verifica que las cuotas están habilitadas: mount | grep /home
    - Reconfigura cuotas: sudo bash recursos/setup_cuotas.sh

7. Limpia el archivo de prueba después de completar:
    - rm -f archivo_prueba.img archivo_prueba2.img

## Prueba 5: Monitoreo Integrado Durante Pruebas de Estrés

Esta prueba valida que los sistemas de observabilidad funcionan correctamente durante carga.

### Pasos para ejecutar la prueba:

1. En una terminal, verifica que el generador de inventario está activo:
    - sudo systemctl status inventario-framework.service

    **Imagen 16**: Estado del servicio de inventario

2. Ejecuta la prueba de estrés nuevamente:
    - sudo bash recursos/prueba_estres.sh

    **Imagen 17**: Ejecución de prueba durante monitoreo

3. En otra terminal, monitorea el inventario generado en tiempo real:
    - tail -f /var/log/framework/inventario.log

    **Imagen 18**: Logs del inventario durante la prueba

4. Verifica que el detector de anomalías está detectando la carga:
    - sudo python3 observabilidad/analizador_auth.py

    **Imagen 19**: Análisis de eventos durante la prueba

5. Comprueba que los servicios de monitoreo están registrando eventos:
    - sudo systemctl status monitoreo-framework.service

    **Imagen 20**: Estado del servicio de monitoreo

### Interpretación de resultados:

6. Si los logs muestran actividad durante la prueba:
    - El sistema de observabilidad está funcionando correctamente
    - Los eventos se registran en tiempo real

## Prueba 6: Recuperación Post-Estrés

Esta prueba valida que el sistema se recupera correctamente después de la prueba de estrés.

### Pasos para ejecutar la prueba:

1. Después de que finalice la prueba de estrés, espera 1-2 minutos para que el sistema se estabilice

2. Verifica que el sistema responde correctamente:
    - ps aux | wc -l

    Debería mostrar un número razonable de procesos

    **Imagen 21**: Conteo de procesos después de la prueba

3. Verifica la integridad del sistema de archivos:
    - sudo fsck -n /dev/vda1

    (O la partición correspondiente, usualmente sin -n para escribir cambios)

    **Imagen 22**: Verificación de integridad del sistema de archivos

4. Revisa que no hay procesos zombis:
    - ps aux | grep defunct

    No debería mostrar procesos zombis

    **Imagen 23**: Verificación de procesos zombis

5. Comprueba el estado de todos los servicios del framework:
    - sudo systemctl status mantenimiento-framework.service
    - sudo systemctl status monitoreo-framework.service
    - sudo systemctl status inventario-framework.service

    **Imagen 24**: Estado de servicios después de la prueba

### Interpretación de resultados:

6. Si todos los servicios están activos y no hay procesos anómalos:
    - El sistema se recuperó correctamente de la prueba de estrés
    - El framework está estable y listo para producción

7. Si algún servicio está caído:
    - Reinicia el servicio: sudo systemctl restart nombre-servicio
    - Revisa los logs: sudo journalctl -u nombre-servicio -n 50

## Conclusión

Las pruebas de estrés descritas en este documento validan que:

- Los cgroups v2 están limitando correctamente el uso de CPU y memoria
- Las cuotas de disco están protegiendo el almacenamiento del sistema
- Los sistemas de observabilidad están registrando eventos bajo carga
- El framework se recupera correctamente después de períodos de alta carga
- El sistema multiusuarios mantiene la estabilidad incluso bajo condiciones adversas

Se recomienda ejecutar estas pruebas regularmente, especialmente después de:
- Cambios de configuración en framework.yaml
- Actualizaciones del kernel
- Modificaciones en los límites de recursos
- Cambios en la topología del hardware

Para más información sobre la configuración del sistema, consulta la [GUIA_MV.md](GUIA_MV.md).