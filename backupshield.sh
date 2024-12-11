#!/usr/bin/env bash
#
# backupshield.sh - Script para crear y gestionar respaldos (Full e Incremental) y restaurar un backup.
#
# Autor: Ricardo Andres Bonilla Prada
# Fecha: 2024-12-11
#
# Descripción:
# Sprint 1: Respaldo local básico (Full).
# Sprint 2: Añade backups incrementales y la posibilidad de restaurar un backup.
# Sprint 3: Añade cifrado GPG a los backups y descifrado al restaurar.
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

set -e  # Detiene el script si un comando devuelve un error
set -u  # Detiene si se usa una variable sin definir

#------------------------------------------------------------
# Variables Globales
#------------------------------------------------------------
# Directorio por defecto si no se especifica en full/incremental
SOURCE_DIR="$(pwd)"

# Directorio donde se guardan los backups
BACKUP_DIR="$(pwd)/backups"

# Crear el directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Modo de operación (full, incremental, restore)
MODE="${1:-full}"
shift || true

# Passphrase para el cifrado simétrico con GPG (en un entorno real se debería
# almacenar de forma más segura, por ejemplo en un archivo externo o una variable
# de entorno)
GPG_PASSPHRASE="RKDSoft"

#------------------------------------------------------------
# Función: encrypt_file
# Cifra un archivo con GPG usando cifrado simétrico.
#
# Parámetros:
#   $1: Ruta del archivo a cifrar
#
# Salida:
#   Crea un archivo cifrado con extensión .gpg y elimina el original.
#------------------------------------------------------------
encrypt_file() {
  local FILE="$1"
  gpg --batch --passphrase "$GPG_PASSPHRASE" -c "$FILE"
  rm -f "$FILE"
  echo "Archivo cifrado: ${FILE}.gpg"
}

#------------------------------------------------------------
# Función: decrypt_file
# Descifra un archivo cifrado con GPG a su versión sin cifrar.
#
# Parámetros:
#   $1: Archivo .gpg a descifrar
#   $2: Nombre de archivo de salida descifrado (opcional)
#
# Si no se especifica el segundo parámetro, se quita el .gpg del nombre.
#
# Salida:
#   Crea el archivo desencriptado y conserva el cifrado intacto.
#------------------------------------------------------------
decrypt_file() {
  local GPG_FILE="$1"
  local OUTPUT_FILE="${2:-${GPG_FILE%.gpg}}"
  gpg --batch --passphrase "$GPG_PASSPHRASE" -o "$OUTPUT_FILE" -d "$GPG_FILE"
  echo "Archivo descifrado: $OUTPUT_FILE"
}

#------------------------------------------------------------
# Función: create_full_backup
# Crea un backup total (.tar.gz) del directorio fuente, luego lo cifra con GPG.
#
# Parámetros:
#   $1: Directorio fuente a respaldar
#
# Salida:
#   Crea un archivo backup_full_YYYYMMDD_HHMMSS.tar.gz.gpg en BACKUP_DIR
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
  
  # Cifrar el backup
  encrypt_file "$BACKUP_PATH"
  echo "Backup FULL cifrado creado exitosamente: ${BACKUP_PATH}.gpg"
}

#------------------------------------------------------------
# Función: create_incremental_backup
# Crea un backup incremental usando gtar (GNU tar) con --listed-incremental,
# luego cifra el resultado.
#
# Parámetros:
#   $1: Directorio fuente a respaldar
#
# Notas:
# - Usa ${BACKUP_DIR}/snapshot.snar para determinar cambios.
# - Si no existía snapshot.snar, el primer incremental será un full.
#
# Salida:
#   Crea un archivo backup_incremental_YYYYMMDD_HHMMSS.tar.gz.gpg en BACKUP_DIR
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

  # Crear el backup incremental con gtar
  gtar --listed-incremental="${BACKUP_DIR}/snapshot.snar" -czf "$BACKUP_PATH" -C "$SRC_DIR" .

  echo "Backup INCREMENTAL creado exitosamente: ${BACKUP_PATH}"
  echo "Nota: Si no existía snapshot.snar, este backup será igual a un full inicial."

  # Cifrar el backup incremental
  encrypt_file "$BACKUP_PATH"
  echo "Backup INCREMENTAL cifrado creado exitosamente: ${BACKUP_PATH}.gpg"
}

#------------------------------------------------------------
# Función: restore_backup
# Restaura un backup a un directorio destino. Si el backup está cifrado (.gpg),
# primero lo descifra, luego extrae el tar.gz resultante y elimina el tar.gz desencriptado.
#
# Parámetros:
#   $1: Archivo de backup (tar.gz o tar.gz.gpg)
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

  # Si el backup está cifrado (termina en .gpg)
  if [[ "$BACKUP_FILE" == *.gpg ]]; then
    local DECRYPTED_FILE="${BACKUP_FILE%.gpg}"  # Quitar .gpg
    decrypt_file "$BACKUP_FILE" "$DECRYPTED_FILE"
    tar -xzf "$DECRYPTED_FILE" -C "$RESTORE_DIR"
    rm -f "$DECRYPTED_FILE"
  else
    # Caso en el que el backup no esté cifrado (compatibilidad con versiones viejas)
    tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"
  fi
  
  echo "Restauración completada."
}

#------------------------------------------------------------
# Flujo Principal
# Interpretamos el modo (full/incremental/restore) y llamamos a la función correspondiente.
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
