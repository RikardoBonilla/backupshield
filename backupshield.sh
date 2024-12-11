#!/usr/bin/env bash
#
# backupshield.sh - Script para crear y gestionar respaldos con funcionalidades avanzadas.
#
# Autor: Ricardo Andres Bonilla Prada
# Fecha: 2024-12-11
#
# Características por Sprint:
# Sprint 1: Respaldo local básico (Full)
# Sprint 2: Backups incrementales y restauración
# Sprint 3: Cifrado GPG de los backups
# Sprint 4: Subida remota con rclone y notificaciones por correo
# Sprint 5: Menú interactivo y archivo de configuración externo
#
# Uso:
#   ./backupshield.sh [modo] [args...]
#
# Modos disponibles (opcional):
#   full [dir]          -> Crea backup full del directorio
#   incremental [dir]   -> Crea backup incremental
#   restore [archivo] [dir_destino] -> Restaura backup
#   menu                -> Mostrar menú interactivo
#
# Si no se especifica modo, se muestra el menú interactivo.
#

set -e
set -u

#------------------------------------------------------------
# Cargar configuración externa
#------------------------------------------------------------
CONFIG_FILE="$(dirname "$0")/backupshield.conf"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
else
  echo "No se encontró backupshield.conf. Usando valores por defecto."
  GPG_PASSPHRASE="defaultpass"
  REMOTE_NAME="myremote:backupfolder"
  MAIL_TO="correo@ejemplo.com"
fi

#------------------------------------------------------------
# Variables Globales
#------------------------------------------------------------
SOURCE_DIR="$(pwd)"
BACKUP_DIR="$(pwd)/backups"

mkdir -p "$BACKUP_DIR"

MODE="${1:-menu}"
shift || true

#------------------------------------------------------------
# Funciones de cifrado
#------------------------------------------------------------
encrypt_file() {
  local FILE="$1"
  gpg --batch --passphrase "$GPG_PASSPHRASE" -c "$FILE"
  rm -f "$FILE"
  echo "Archivo cifrado: ${FILE}.gpg"
}

decrypt_file() {
  local GPG_FILE="$1"
  local OUTPUT_FILE="${2:-${GPG_FILE%.gpg}}"
  gpg --batch --passphrase "$GPG_PASSPHRASE" -o "$OUTPUT_FILE" -d "$GPG_FILE"
  echo "Archivo descifrado: $OUTPUT_FILE"
}

#------------------------------------------------------------
# Función de subida remota
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
# Función de notificación por correo
#------------------------------------------------------------
send_notification() {
  local MESSAGE="$1"
  echo "$MESSAGE" | mailx -s "BackupShield - Notificación de Respaldo" "$MAIL_TO"
  echo "Notificación enviada a $MAIL_TO."
}

#------------------------------------------------------------
# Crear backup full
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
  BACKUP_PATH="${BACKUP_PATH}.gpg"

  upload_remote "$BACKUP_PATH" || echo "Advertencia: No se pudo subir el archivo al remoto."
  send_notification "Backup FULL completado: ${BACKUP_PATH} y subido al remoto."
}

#------------------------------------------------------------
# Crear backup incremental
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
# Restaurar backup
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
# Menú interactivo
#------------------------------------------------------------
show_menu() {
  PS3="Seleccione una opción: "
  local OPTS=("Crear Backup Full"
              "Crear Backup Incremental"
              "Restaurar Backup"
              "Ver Archivos de Backup"
              "Salir")
  select OPT in "${OPTS[@]}"; do
    case $REPLY in
      1)
        read -r -p "Ingrese el directorio a respaldar (ENTER para actual): " DIR
        DIR="${DIR:-$(pwd)}"
        create_full_backup "$DIR"
        ;;
      2)
        read -r -p "Ingrese el directorio a respaldar (ENTER para actual): " DIR
        DIR="${DIR:-$(pwd)}"
        create_incremental_backup "$DIR"
        ;;
      3)
        read -r -p "Ingrese el archivo de backup (.tar.gz.gpg): " BKP_FILE
        read -r -p "Ingrese el directorio destino (ENTER para actual): " R_DIR
        R_DIR="${R_DIR:-$(pwd)}"
        restore_backup "$BKP_FILE" "$R_DIR"
        ;;
      4)
        echo "Archivos de backup locales:"
        ls -lh "${BACKUP_DIR}"
        ;;
      5)
        echo "Saliendo del menú."
        break
        ;;
      *)
        echo "Opción inválida. Intente nuevamente."
        ;;
    esac
  done
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
  menu|*)
    show_menu
    ;;
esac

echo "Proceso finalizado."
