#!/usr/bin/env bash
#
# backupshield.sh - Script para crear y gestionar respaldos (Full e Incremental) y restaurar de un backup.
#
# Autor: Ricardo Andres Bonilla Prada
# Fecha: 2024-12-11
#
# Descripción:
# Sprint 1: Respaldo local básico (Full).
# Sprint 2: Añade backups incrementales y la posibilidad de restaurar un backup.
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

set -e  # Detiene el script si un comando devuelve un error.
set -u  # Detiene si se intenta usar una variable no inicializada.

#------------------------------------------------------------
# Variables Globales
#------------------------------------------------------------
# Directorio por defecto si no se especifica en full/incremental.
SOURCE_DIR="$(pwd)"

# Directorio donde se guardan los backups
BACKUP_DIR="$(pwd)/backups"

# Crear el directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Modo de operación (full, incremental, restore)
MODE="${1:-full}"

# Shift del primer argumento para procesar los siguientes de manera uniforme si se desea.
# Aunque en este caso no es estrictamente necesario, se puede dejar así.
shift || true

#------------------------------------------------------------
# Función: create_full_backup
# Crea un backup total (.tar.gz) del directorio fuente.
#
# Parámetros:
#   $1: Directorio fuente a respaldar
#
# Salida:
#   Crea un archivo backup_full_YYYYMMDD_HHMMSS.tar.gz en BACKUP_DIR
#------------------------------------------------------------
create_full_backup() {
  local SRC_DIR="$1"
  
  # Obtener la fecha y hora en formato YYYYMMDD_HHMMSS
  local DATE_STR
  DATE_STR=$(date +%Y%m%d_%H%M%S)

  # Nombre del archivo de backup full
  local BACKUP_FILE="backup_full_${DATE_STR}.tar.gz"

  # Ruta completa al archivo de backup
  local BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

  echo "Creando backup FULL de: ${SRC_DIR}"
  echo "Guardando en: ${BACKUP_PATH}"

  # Crear el backup full con tar y gzip
  tar -czf "$BACKUP_PATH" -C "$SRC_DIR" .

  echo "Backup FULL creado exitosamente: ${BACKUP_PATH}"
}

#------------------------------------------------------------
# Función: create_incremental_backup
# Crea un backup incremental usando tar con --listed-incremental.
#
# Parámetros:
#   $1: Directorio fuente a respaldar
#
# Notas:
# - Usa ${BACKUP_DIR}/snapshot.snar para determinar qué se ha modificado.
# - Si no existía snapshot.snar, este primer incremental actuará como un full.
#
# Salida:
#   Crea un archivo backup_incremental_YYYYMMDD_HHMMSS.tar.gz en BACKUP_DIR
#------------------------------------------------------------
create_incremental_backup() {
  local SRC_DIR="$1"
  
  # Obtener fecha y hora
  local DATE_STR
  DATE_STR=$(date +%Y%m%d_%H%M%S)

  # Nombre del archivo incremental
  local BACKUP_FILE="backup_incremental_${DATE_STR}.tar.gz"
  local BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

  echo "Creando backup INCREMENTAL de: ${SRC_DIR}"
  echo "Guardando en: ${BACKUP_PATH}"

  # Crear el backup incremental
  # --listed-incremental requiere un archivo snapshot para saber qué cambió.
  #   tar --listed-incremental="${BACKUP_DIR}/snapshot.snar" -czf "$BACKUP_PATH" -C "$SRC_DIR" .
  gtar --listed-incremental="${BACKUP_DIR}/snapshot.snar" -czf "$BACKUP_PATH" -C "$SRC_DIR" .

  echo "Backup INCREMENTAL creado exitosamente: ${BACKUP_PATH}"
  echo "Nota: Si no existía snapshot.snar, este backup será igual a un full inicial."
}

#------------------------------------------------------------
# Función: restore_backup
# Restaura un backup a un directorio destino.
#
# Parámetros:
#   $1: Archivo de backup (tar.gz)
#   $2: Directorio destino (opcional, por defecto el actual)
#
# Salida:
#   Extrae el contenido del backup en el directorio destino.
#------------------------------------------------------------
restore_backup() {
  local BACKUP_FILE="$1"
  local RESTORE_DIR="${2:-$(pwd)}"

  echo "Restaurando desde: $BACKUP_FILE"
  echo "Hacia el directorio: $RESTORE_DIR"

  mkdir -p "$RESTORE_DIR"
  tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"
  
  echo "Restauración completada."
}

#------------------------------------------------------------
# Flujo Principal
# Aquí interpretamos el modo (full/incremental/restore) y llamamos a la función correspondiente.
#------------------------------------------------------------
case "$MODE" in
  full)
    # Si se pasa un segundo argumento tras 'full' será el directorio fuente.
    SOURCE_DIR="${1:-$SOURCE_DIR}"
    create_full_backup "$SOURCE_DIR"
    ;;
  
  incremental)
    # Segundo argumento es el directorio fuente para incremental
    SOURCE_DIR="${1:-$SOURCE_DIR}"
    create_incremental_backup "$SOURCE_DIR"
    ;;
  
  restore)
    # Para restore, $1 es el archivo de backup, $2 el directorio destino
    BACKUP_FILE="${1:-}"
    RESTORE_DIR="${2:-$(pwd)}"
    if [[ -z "$BACKUP_FILE" ]]; then
      echo "Debe especificar el archivo de backup a restaurar."
      exit 1
    fi
    restore_backup "$BACKUP_FILE" "$RESTORE_DIR"
    ;;
  
  *)
    # Modo no reconocido, usar full por defecto
    SOURCE_DIR="${1:-$SOURCE_DIR}"
    create_full_backup "$SOURCE_DIR"
    ;;
esac

echo "Proceso finalizado."
