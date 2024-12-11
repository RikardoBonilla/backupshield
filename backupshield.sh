#!/usr/bin/env bash
#
# backupshield.sh - Script para crear y gestionar respaldos (Full, Incremental, Cifrado) y restaurar un backup.
#                   Ahora con subida remota (rclone) y notificaciones por correo (mailx).
#
# Autor: Ricardo Andres Bonilla Prada
# Fecha: 2024-12-11
#
# Descripción:
# Sprint 1: Respaldo local básico (Full).
# Sprint 2: Backups incrementales y restauración.
# Sprint 3: Cifrado GPG de los backups.
# Sprint 4: Subida remota con rclone y notificaciones por correo.
#
# Modo de uso:
#   ./backupshield.sh [modo] [argumentos...]
#
# Modos:
#   full [directorio_opcional]
#       Crea un backup FULL del directorio especificado o del actual.
#
#   incremental [directorio_opcional]
#       Crea un backup INCREMENTAL del directorio, respaldando sólo cambios
#       desde el último backup (full o incremental).
#
#   restore [archivo_backup] [directorio_destino_opcional]
#       Restaura el backup indicado en el directorio destino especificado o el actual.
#
# Si no se especifica modo, se asume 'full'.

set -e
set -u

#------------------------------------------------------------
# Variables Globales
#------------------------------------------------------------
SOURCE_DIR="$(pwd)"
BACKUP_DIR="$(pwd)/backups"

mkdir -p "$BACKUP_DIR"

MODE="${1:-full}"
shift || true

# Passphrase GPG (Se recomienda externalizar en el futuro)
GPG_PASSPHRASE="TuPassphraseSuperSecreta"

# Configuración de remoto (rclone)
REMOTE_NAME="myremote:backupfolder"

# Destinatario de notificaciones
MAIL_TO="correo@ejemplo.com"

#------------------------------------------------------------
# Función: encrypt_file
# Cifra un archivo con GPG usando cifrado simétrico.
#------------------------------------------------------------
encrypt_file() {
  local FILE="$1"
  gpg --batch --passphrase "$GPG_PASSPHRASE" -c "$FILE"
  rm -f "$FILE"
  echo "Archivo cifrado: ${FILE}.gpg"
}

#------------------------------------------------------------
# Función: decrypt_file
# Descifra un archivo .gpg a su versión sin cifrar.
#------------------------------------------------------------
decrypt_file() {
  local GPG_FILE="$1"
  local OUTPUT_FILE="${2:-${GPG_FILE%.gpg}}"
  gpg --batch --passphrase "$GPG_PASSPHRASE" -o "$OUTPUT_FILE" -d "$GPG_FILE"
  echo "Archivo descifrado: $OUTPUT_FILE"
}

#------------------------------------------------------------
# Función: upload_remote
# Sube el archivo especificado al remoto configurado usando rclone.
#------------------------------------------------------------
upload_remote() {
  local FILE="$1"
  echo "Subiendo ${FILE} a remoto: ${REMOTE_NAME}"
  if rclone copy "$FILE" "$REMOTE_NAME"; then
    echo "Subida a remoto exitosa."
    return 0
  else
    echo "Error al subir el archivo remoto."
    return 1
  fi
}

#------------------------------------------------------------
# Función: send_notification
# Envía una notificación por correo al finalizar el backup.
#------------------------------------------------------------
send_notification() {
  local MESSAGE="$1"
  echo "$MESSAGE" | mailx -s "BackupShield - Notificación de Respaldo" "$MAIL_TO"
  echo "Notificación enviada a $MAIL_TO."
}

#------------------------------------------------------------
# Función: create_full_backup
# Crea un backup full, lo cifra, sube a remoto y notifica por correo.
#------------------------------------------------------------
create_full_backup() {
  local SRC_DIR="$1"
  
  local DATE_STR
  DATE_STR=$(date +%Y%m%d_%H%M%S)
  local BACKUP_FILE="backup_full_${DATE_STR}.tar.gz"
  local BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

  echo "Creando backup FULL de: ${SRC_DIR}"
  echo "Guardando en: ${BACKUP_PATH}"
  tar -czf "$BACKUP_PATH" -C "$SRC_DIR" .
  echo "Backup FULL creado exitosamente: ${BACKUP_PATH}"
  
  encrypt_file "$BACKUP_PATH"
  # Ahora BACKUP_PATH sigue apuntando al .tar.gz (sin gpg). Actualizar ruta:
  BACKUP_PATH="${BACKUP_PATH}.gpg"

  # Subir a remoto
  upload_remote "$BACKUP_PATH" || echo "Advertencia: No se pudo subir el archivo al remoto."

  # Notificación por correo
  send_notification "Backup FULL completado: ${BACKUP_PATH} y subido al remoto."
}

#------------------------------------------------------------
# Función: create_incremental_backup
# Crea un backup incremental, lo cifra, sube a remoto y notifica.
#------------------------------------------------------------
create_incremental_backup() {
  local SRC_DIR="$1"
  
  local DATE_STR
  DATE_STR=$(date +%Y%m%d_%H%M%S)
  local BACKUP_FILE="backup_incremental_${DATE_STR}.tar.gz"
  local BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

  echo "Creando backup INCREMENTAL de: ${SRC_DIR}"
  echo "Guardando en: ${BACKUP_PATH}"
  gtar --listed-incremental="${BACKUP_DIR}/snapshot.snar" -czf "$BACKUP_PATH" -C "$SRC_DIR" .
  echo "Backup INCREMENTAL creado exitosamente: ${BACKUP_PATH}"
  echo "Nota: Si no existía snapshot.snar, este backup será igual a un full inicial."

  encrypt_file "$BACKUP_PATH"
  BACKUP_PATH="${BACKUP_PATH}.gpg"

  upload_remote "$BACKUP_PATH" || echo "Advertencia: No se pudo subir el archivo al remoto."
  
  send_notification "Backup INCREMENTAL completado: ${BACKUP_PATH} y subido al remoto."
}

#------------------------------------------------------------
# Función: restore_backup
# Restaura un backup. Si está cifrado, lo descifra primero.
#------------------------------------------------------------
restore_backup() {
  local BACKUP_FILE="$1"
  local RESTORE_DIR="${2:-$(pwd)}"

  echo "Restaurando desde: $BACKUP_FILE"
  echo "Hacia el directorio: $RESTORE_DIR"
  mkdir -p "$RESTORE_DIR"

  if [[ "$BACKUP_FILE" == *.gpg ]]; then
    local DECRYPTED_FILE="${BACKUP_FILE%.gpg}"
    decrypt_file "$BACKUP_FILE" "$DECRYPTED_FILE"
    tar -xzf "$DECRYPTED_FILE" -C "$RESTORE_DIR"
    rm -f "$DECRYPTED_FILE"
  else
    tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"
  fi
  
  echo "Restauración completada."
}

#------------------------------------------------------------
# Flujo Principal
#------------------------------------------------------------
case "$MODE" in
  full)
    SOURCE_DIR="${1:-$SOURCE_DIR}"
    create_full_backup "$SOURCE_DIR"
    ;;
  
  incremental)
    SOURCE_DIR="${1:-$SOURCE_DIR}"
    create_incremental_backup "$SOURCE_DIR"
    ;;
  
  restore)
    BACKUP_FILE="${1:-}"
    RESTORE_DIR="${2:-$(pwd)}"
    if [[ -z "$BACKUP_FILE" ]]; then
      echo "Debe especificar el archivo de backup a restaurar."
      exit 1
    fi
    restore_backup "$BACKUP_FILE" "$RESTORE_DIR"
    ;;
  
  *)
    SOURCE_DIR="${1:-$SOURCE_DIR}"
    create_full_backup "$SOURCE_DIR"
    ;;
esac

echo "Proceso finalizado."
