#!/bin/bash
# ============================================================
# IT 자산관리 DB 자동 백업 스크립트
# 작성일: 2024-05
# 실행: ./backup.sh 또는 cron으로 자동 실행
# ============================================================

DB_NAME="it_asset_db"
DB_USER="itadmin"
BACKUP_DIR="$HOME/backups"
RETENTION_DAYS=30
DATE=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$BACKUP_DIR/backup.log"

# 백업 디렉토리 없으면 생성
mkdir -p "$BACKUP_DIR"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 백업 시작: $DB_NAME" >> "$LOG_FILE"

# 백업 실행 (압축)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz"
PGPASSWORD='it@2024' pg_dump \
    -h localhost \
    -U "$DB_USER" \
    "$DB_NAME" | gzip > "$BACKUP_FILE"

# 성공/실패 판단
if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 성공: $(basename $BACKUP_FILE) ($SIZE)" >> "$LOG_FILE"
    
    # PostgreSQL 로그 테이블에도 기록
    PGPASSWORD='it@2024' psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c \
        "INSERT INTO asset_backup_log (file_name, file_size, status)
         VALUES ('$(basename $BACKUP_FILE)', '$SIZE', '성공');" 2>/dev/null
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 실패: 백업 오류 발생" >> "$LOG_FILE"
    
    PGPASSWORD='it@2024' psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c \
        "INSERT INTO asset_backup_log (file_name, file_size, status)
         VALUES ('FAILED_${DATE}', '0', '실패');" 2>/dev/null
    exit 1
fi

# 보존 기간 초과 파일 삭제
DELETED=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -print)
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

if [ -n "$DELETED" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] 오래된 백업 삭제: $RETENTION_DAYS일 초과" >> "$LOG_FILE"
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] 백업 완료" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"
