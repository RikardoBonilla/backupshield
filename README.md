# BackupShield

BackupShield es un script en Bash que proporciona una solución integral para la creación, cifrado, gestión, restauración y notificación de respaldos (backups) locales y remotos. El proyecto se ha desarrollado gradualmente a lo largo de varios sprints, agregando funcionalidades en cada etapa, y culmina con una interfaz de menú interactivo y un archivo de configuración externo.

## Funcionalidades por Sprint

- **Sprint 1:** Respaldo local básico (Full)  
  - Crear un backup `.tar.gz` de un directorio fuente.  
  - Guardar el backup en el directorio `backups/`.  
  - Código limpio y documentado.

- **Sprint 2:** Backups incrementales y restauración  
  - Añadir respaldos incrementales utilizando GNU tar (`gtar`) con `--listed-incremental`.  
  - Restaurar backups a un directorio destino.  
  - Mantener versión incrementales y full de los backups.

- **Sprint 3:** Cifrado GPG de los backups  
  - Cifrar los backups `.tar.gz` en `.tar.gz.gpg` usando GPG y una passphrase.  
  - Desencriptar al restaurar, ofreciendo mayor seguridad en reposo.

- **Sprint 4:** Subida remota con rclone y notificaciones por correo  
  - Subir los backups cifrados a un servicio remoto configurado en `rclone`.  
  - Enviar notificaciones por correo electrónico (`mailx`) al completar el respaldo.  
  - Ahora los backups están seguros, redundantes y se notifica al responsable cuando se completan.

- **Sprint 5:** Menú interactivo y archivo de configuración externo  
  - Configurar parámetros (passphrase, destino remoto, correo) en un archivo de configuración externo `backupshield.conf`.  
  - Menú interactivo en la terminal para crear Full, Incremental, Restaurar, Ver backups y Salir.  
  - Con este menú no es necesario recordar los comandos; el usuario puede seleccionar la opción deseada.

## Requisitos y Dependencias

1. **Bash 4+:**  
   Asegúrese de usar Bash 4 o superior. En macOS, la versión por defecto es antigua; se recomienda instalar Bash vía `brew install bash` y ajustar el `#!/usr/bin/env bash` si es necesario.

2. **GNU tar (gtar):**  
   En macOS, instale `gtar` para soportar `--listed-incremental`:  
   ```bash
   brew install gnu-tar
   ```
   En Linux la mayoría de las distribuciones incluyen GNU tar por defecto.

3. **GPG:**  
   Necesario para cifrar y descifrar backups:  
   ```bash
   brew install gnupg  # macOS
   sudo apt-get install gnupg   # Debian/Ubuntu Linux
   ```

4. **rclone:**  
   Para subir backups a un remoto (S3, GDrive, etc.):  
   ```bash
   brew install rclone   # macOS
   sudo apt-get install rclone  # Debian/Ubuntu
   ```
   Luego configurar `rclone config` para crear un remoto, por ejemplo `myremote:`.

5. **mailx (o mailutils):**  
   Para enviar notificaciones por correo:  
   ```bash
   brew install mailutils   # macOS con Homebrew
   sudo apt-get install mailutils  # Debian/Ubuntu
   ```
   Configurar SMTP si es necesario.

6. **Archivo de configuración `backupshield.conf`:**  
   Crear un archivo en el mismo directorio que `backupshield.sh` con:  
   ```bash
   # backupshield.conf
   GPG_PASSPHRASE="TuPassphraseSuperSecreta"
   REMOTE_NAME="myremote:backupfolder"
   MAIL_TO="correo@ejemplo.com"
   ```
   Ajustar los valores según su entorno.

## Instalación

1. Clonar el repositorio:  
   ```bash
   git clone https://github.com/RikardoBonilla/ecoclean.git
   cd ecoclean/backupshield
   ```

2. Dar permisos de ejecución al script:  
   ```bash
   chmod +x backupshield.sh
   ```

3. Crear el archivo de configuración `backupshield.conf` (ver ejemplo arriba).

4. Crear el directorio `backups/`:  
   ```bash
   mkdir -p backups
   ```

## Uso

Hay dos formas de usar `backupshield.sh`:

1. **Menú Interactivo (sin argumentos):**
   ```bash
   ./backupshield.sh
   ```
   Aparecerá un menú:
   ```
   1) Crear Backup Full
   2) Crear Backup Incremental
   3) Restaurar Backup
   4) Ver Archivos de Backup
   5) Salir
   Seleccione una opción:
   ```

   Seleccione la opción deseada y siga las instrucciones en pantalla.

2. **Modo por Argumentos:**
   ```bash
   ./backupshield.sh full [directorio_opcional]
   ./backupshield.sh incremental [directorio_opcional]
   ./backupshield.sh restore [archivo_backup] [directorio_destino_opcional]
   ./backupshield.sh menu
   ```
   
   Si no se proporciona modo, se mostrará el menú por defecto.

## Ejemplo de Flujo

- **Backup Full Interactivo:**
  1. `./backupshield.sh`
  2. Seleccionar `1) Crear Backup Full`
  3. Dejar el directorio en blanco para usar el actual o ingresar otro.
  4. Se crea el backup, se cifra, se sube al remoto y se envía un correo a `MAIL_TO`.

- **Backup Incremental por Argumentos:**
  ```bash
  ./backupshield.sh incremental /path/a/respaldar
  ```
  Crear un backup incremental. Si no existe `snapshot.snar` se comportará como un full inicial.

- **Restaurar:**
  ```bash
  ./backupshield.sh restore backups/backup_full_20241211_123456.tar.gz.gpg /ruta/de/restauracion
  ```
  Descifra el backup, lo extrae y luego elimina el tar.gz temporal.

## Posibles Mejoras Futuras

1. **Soporte para múltiples perfiles de configuración:**  
   Poder especificar un archivo de configuración alternativo (ej: `backupshield.sh --config work.conf`) para usar diferentes destinos o llaves GPG según el entorno (trabajo, personal, cliente X).

2. **Programación Automática de Backups (Cron / systemd timers):**  
   Añadir una función para programar la ejecución automática de backups full o incrementales en horarios específicos desde el menú interactivo.

3. **Reportes HTML o PDF Detallados:**  
   Generar reportes (HTML/PDF) con información del tamaño de backups, históricos, y estadísticas de versiones. Esto haría más amigable la visualización del historial de respaldos.

4. **Soporte para múltiples destinos remotos:**  
   Permitir subir el backup a más de un remoto (ej. S3 y Google Drive simultáneamente), reforzando la redundancia.

5. **Integración con llaves GPG asimétricas:**  
   En lugar de usar cifrado simétrico con passphrase, usar llaves públicas/privadas GPG sin interacción, permitiendo distribuir la llave pública a múltiples entornos y descifrar sólo con la llave privada, aumentando la seguridad y flexibilidad.
