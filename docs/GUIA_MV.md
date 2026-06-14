# Guía de Configuración de la Máquina Virtual

## Descarga Ubuntu Server 26.04 LTS
Para obtener Ubuntu Server 26.04 LTS se debe acceder a la página oficial de Ubuntu y descargar el archivo: https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso

## Descarga VirtualBox
Para obtener VirtualBox se debe acceder a la página oficial de VirtualBox y descarhar el archivo: https://www.virtualbox.org/wiki/Downloads

## Configuración de la Máquina Virual
1. Al abrir la MV de VirualBox, seleccionaremos "Nueva" representada por un ícono azul en al parte superior izquiera de la ventana

2. Nos pedirán los siguientes datos:
    - VM Name: framework_multiusuarios
    - VM Folder: C:\Users\[Usuario]\VirtualBox VMs
    - ISO Image: [Vacío]
    - OS: Linux
    - OS: Distribution: Ubuntu
    - OS Version: Ubuntu(64-bit)

3. Después, entraremos al apartado de especificaciones del hardware:
    - Base memory: 4096 MB
    - Número de CPUs: 2
    - Disk size: 30 GB

4. Aparecerá una pantalla con un resmuen de las especificaciones seleccionadas, y continuaremos con la instalación

5. Seleccionamos la MV creada y seleccionamos del menú la opción "Configuración"

6. En la sección izquiera "Pantalla", iremos al apartado "Almacenamiento"

7. Ingresaremos al Controlador: IDE, y seleccionaremos el archivo que instalamos de Ubuntu Server 24.06 LTS

8. Al colocar el archivo, guardaremos los cambios

9. Inicamos la MV con la opción "Iniciar" 

10. Creamos el usuario y la contraseña para poder acceder

11. Actualizamos el sistema una vez iniciada la MV:
    - sudo apt update

    - sudo apt upgrade -y

12. Reiniciamos la MV:
    - sudo reboot

13. Instalamos la dependecias:
    - sudo apt install python3
    - sudo apt install quota
    - sudo apt install logrotate
    - sudo apt install mailutils
    - sudo apt install stress-ng
    - sudo apt install git -y

14. Verificamos las versiones de las dependencias instaladas:
    - python3 --version
    - git --version
    - quota --version
    - logrotate --version

15. Clonamos el repositorio del framework:
    - cd ~
    - git clone [github.com:DanielGC2026/framework-multiusuarios.git]
    - cd framework-multiusuarios

16. Otorgamos permisos de ejecución a los scripts principales:
    - chmod +x orquestador_framework.sh
    - chmod +x configurador_permisos.sh
    - chmod +x verificador_integridad.sh
    - chmod +x aprovicionamiento/*.sh
    - chmod +x mantenimiento/*.sh
    - chmod +x recursos/*.sh
    - chmod +x observabilidad/*.sh

17. Verificamos la integridad del framework:
    - sudo ./verificador_integridad.sh

18. Copiamos los archivos de configuración a las ubicaciones del sistema:
    - sudo cp configuracion/framework.yaml /etc/
    - sudo cp configuracion/limits.yaml /etc/

19. Copiamos los servicios y timers de systemd:
    - sudo cp mantenimiento/*.service /etc/systemd/system/
    - sudo cp mantenimiento/*.timer /etc/systemd/system/
    - sudo cp observabilidad/*.service /etc/systemd/system/
    - sudo cp observabilidad/*.timer /etc/systemd/system/

20. Recargamos los servicios de systemd:
    - sudo systemctl daemon-reload

21. Verificamos la configuración del framework:
    - sudo ./configurador_permisos.sh --verificar

22. Reiniciamos la MV para aplicar todos los cambios:
    - sudo reboot

23. Después del reinicio, verificamos que todos los servicios estén activos:
    - sudo systemctl status mantenimiento-framework.service
    - sudo systemctl status monitoreo-framework.service
    - sudo systemctl status inventario-framework.service