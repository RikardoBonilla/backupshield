#!/usr/bin/env bash
#
# backupshield.sh - Script para realizar un respaldo local básico (Sprint 1)
#
# Autor: [Tu Nombre]
# Fecha: [Fecha Actual]
#
# Descripción:
# Este script toma un directorio (fuente) y crea un backup comprimido con tar y gzip,
# guardándolo en el directorio 'backups'. Si no se proporciona un directorio fuente
# como parámetro, se asume el directorio actual.
#
# Uso:
#   ./backupshield.sh [directorio_fuente_opcional]
#
# Ejemplo:
#   ./backupshield.sh /home/usuario/documentos
# Si no se especifica, por defecto: ./backupshield.sh  (usará el directorio actual)

set -e  # Detener el script si ocurre un error
set -u  # Detener si se usan variables sin definir

#------------------------------------------------------------
# Variables Globales
#------------------------------------------------------------
SOURCE_DIR="${1:-$(pwd)}"   # Directorio fuente, por defecto el actual
BACKUP_DIR="$(pwd)/backups" # Directorio donde se guardan los backups

# Crear el directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

#------------------------------------------------------------
# Función: create_backup
# Descripción:
#   Crea un archivo de respaldo .tar.gz del directorio fuente especificado.
#   El nombre del backup incluirá la fecha y hora para ser único.
#
# Parámetros:
#   $1 - Directorio fuente (obligatorio)
#
# Salida:
#   Crea un archivo en BACKUP_DIR con el nombre backup_YYYYMMDD_HHMMSS.tar.gz
#   Imprime un mensaje indicando el resultado.
#------------------------------------------------------------
create_backup() {
  local SRC_DIR="$1"
  
  # Obtener fecha en formato YYYYMMDD_HHMMSS para el nombre del backup
  local DATE_STR
  DATE_STR=$(date +%Y%m%d_%H%M%S)

  # Nombre del archivo de backup
  local BACKUP_FILE="backup_${DATE_STR}.tar.gz"

  # Ruta completa del archivo de backup
  local BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

  echo "Creando backup de: ${SRC_DIR}"
  echo "Guardando en: ${BACKUP_PATH}"

  # Crear el archivo tar comprimido con gzip
  # -c: crear
  # -z: comprimir con gzip
  # -f: nombre del archivo
  # -C: cambiar al directorio especificado antes de agregar archivos
  # Asumimos que se quiere respaldar el contenido del directorio, no el directorio en sí.
  # Si se quiere incluir el directorio en la ruta del backup, ajustar el comando.
  tar -czf "$BACKUP_PATH" -C "$SRC_DIR" .

  echo "Backup creado exitosamente: ${BACKUP_PATH}"
}

#------------------------------------------------------------
# Flujo Principal
#------------------------------------------------------------
echo "Iniciando BackupShield - Sprint 1"
echo "Directorio fuente: $SOURCE_DIR"
echo "Directorio de backups: $BACKUP_DIR"

# Crear el backup
create_backup "$SOURCE_DIR"

echo "Proceso finalizado."