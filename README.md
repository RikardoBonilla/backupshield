# BackupShield

**Autor:** Ricardo Andres Bonilla Prada  
**Fecha:** 2024-12-11

**Descripción General:**  
BackupShield es una solución en Bash para la creación, gestión y restauración de respaldos (backups) con funcionalidades avanzadas. Su objetivo es permitir a los usuarios realizar respaldos totales o incrementales de sus datos, cifrarlos para mayor seguridad, subirlos a un servicio remoto en la nube y notificar por correo electrónico el resultado, todo esto configurado mediante un archivo externo y controlado por medio de un menú interactivo.

## Características por Sprint

- **Sprint 1:**  
  - Respaldo local básico (Full) usando `tar` y `gzip`.
  - Generación de archivos `.tar.gz` en el directorio `backups`.

- **Sprint 2:**  
  - Añadido backups incrementales usando `gtar` con `--listed-incremental`.
  - Posibilidad de restaurar un backup a un directorio específico.

- **Sprint 3:**  
  - Integración con GPG para cifrar los backups (`.tar.gz.gpg`).
  - Descifrado automático durante la restauración.

- **Sprint 4:**  
  - Subida remota de los backups cifrados a la nube usando `rclone`.
  - Notificaciones por correo electrónico (usando `mailx`) al completar el backup.

- **Sprint 5:**  
  - Lectura de configuración desde un archivo externo (`backupshield.conf`) para no hardcodear valores críticos.
  - Menú interactivo mediante el cual el usuario puede seleccionar opciones sin necesidad de parámetros en la línea de comandos.

## Requisitos y Dependencias

1. **Bash:**  
   Asegúrate de tener Bash 4.0 o superior (en macOS se recomienda instalar con Homebrew).

2. **Herramientas de compresión y tar:**
   - `tar` (en macOS utilizar `gtar` instalado vía `brew install gnu-tar` para backups incrementales).
   - `gzip` (normalmente incluido en macOS/Linux por defecto).

3. **GPG:**  
   Para cifrar y descifrar los backups:  
   ```bash
   brew install gnupg  # macOS
   sudo apt-get install gnupg  # Debian/Ubuntu
   ```

4. **rclone:**  
   Para subir los backups remotos:  
   ```bash
   brew install rclone  # macOS
   sudo apt-get install rclone  # Debian/Ubuntu
   ```
   Configurar un remoto con `rclone config` antes de usar BackupShield.

5. **mailx (o equivalente):**  
   Para enviar notificaciones por correo:  
   - En macOS se puede usar `mailx` vía:
     ```bash
     brew install mailutils
     ```
   - En Linux:
     ```bash
     sudo apt-get install mailutils
     ```
   Configurar `mailx`/`sendmail` según tu entorno.

6. **GPG Passphrase / Llaves:**  
   Si se usa cifrado simétrico, define una passphrase en `backupshield.conf`.
   Asegúrate de manejar la passphrase de forma segura.

7. **Archivo de Configuración `backupshield.conf`:**
   Crear un archivo `backupshield.conf` en el mismo directorio que `backupshield.sh`:
   ```bash
   # backupshield.conf
   GPG_PASSPHRASE="TuPassphraseSuperSecreta"
   REMOTE_NAME="myremote:backupfolder"
   MAIL_TO="tucorreo@ejemplo.com"
   ```
   
   Ajustar las variables según tu entorno:
   - `GPG_PASSPHRASE`: Passphrase para cifrar backups.
   - `REMOTE_NAME`: Remoto configurado con rclone (ej. `myremote:carpeta`).
   - `MAIL_TO`: Dirección de correo a la que se enviarán notificaciones.

8. **Directorio de Backups:**
   El script creará automáticamente el directorio `backups/` en el directorio actual.

## Uso del Proyecto

1. **Clonar el repositorio (si aplica)**:
   ```bash
   git clone https://github.com/RikardoBonilla/backupshield.git
   cd backupshield
   ```

2. **Dar permisos de ejecución:**
   ```bash
   chmod +x backupshield.sh
   ```

3. **Editar el archivo de configuración `backupshield.conf`:**
   Ajusta las variables a tu entorno (passphrase, remoto, correo).

4. **Ejecutar el menú interactivo:**
   ```bash
   ./backupshield.sh
   ```
   
   Aparecerá un menú con las siguientes opciones:
   ```
   1) Crear Backup Full
   2) Crear Backup Incremental
   3) Restaurar Backup
   4) Ver Archivos de Backup
   5) Salir
   ```

5. **Crear un Backup Full:**
   Selecciona la opción `1`. Ingresa el directorio a respaldar (ENTER para actual). Se creará el backup, se cifrará, se subirá al remoto y se enviará una notificación por correo.

6. **Crear un Backup Incremental:**
   Selecciona la opción `2`. Similar al Full, pero sólo se respaldan cambios desde el último backup.

7. **Restaurar un Backup:**
   Selecciona la opción `3`. Ingresa el archivo de backup (ej. `backups/backup_full_20241211_153000.tar.gz.gpg`) y el directorio destino. El script descifrará y extraerá el contenido.

8. **Ver Archivos de Backup Locales:**
   Selecciona la opción `4`. Listará los archivos en el directorio `backups/`.

9. **Salir:**
   Selecciona la opción `5`.

## Ejecución Vía Línea de Comandos (Opcional)

Puedes seguir usando los modos originales sin menú si lo deseas:  
- `./backupshield.sh full /ruta/al/directorio`  
- `./backupshield.sh incremental /ruta/al/directorio`  
- `./backupshield.sh restore /ruta/al/backup.tar.gz.gpg /ruta/destino`

## Posibles Problemas y Soluciones

- **No se encuentra `gtar`:**  
  Instalar con `brew install gnu-tar` en macOS y usar `gtar` en lugar de `tar` en el script (ya implementado en el código).
  
- **No se puede enviar correo:**  
  Asegurar configuración SMTP o postfix. Puedes probar enviarte un correo con `echo "test" | mailx -s "Test" tu@correo.com` antes de usar BackupShield.

- **No se puede subir al remoto con rclone:**  
  Ejecutar `rclone config` y verificar que `REMOTE_NAME` esté correctamente definido.

- **Cifrado falla:**  
  Asegurar que GPG esté instalado y `GPG_PASSPHRASE` definido en `backupshield.conf`.

## Futuras Mejoras

- Integrar llaves asimétricas con GPG en vez de cifrado simétrico.
- Añadir más perfiles de configuración y selección de ellos desde el menú.
- Añadir logs más detallados en un archivo externo.
- Integrar notificaciones más avanzadas (Slack, Telegram, etc.).

## Licencia

Este proyecto puede ser adaptado o distribuido según se requiera (seleccionar una licencia, p. ej. MIT, GPL).