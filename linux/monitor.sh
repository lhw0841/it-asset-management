#!/bin/bash
# ============================================================
# 시스템 리소스 모니터링 스크립트
# 디스크/메모리 임계값 초과 시 경고 로그 기록
# PostgreSQL 프로세스 다운 시 자동 재시작
# ============================================================

ALERT_DISK=85
ALERT_MEM=90
LOG="/var/log/it_monitor.log"
NOW=$(date +"%Y-%m-%d %H:%M:%S")
STATUS="정상"
ALERTS=""

# 로그 파일 없으면 생성
sudo touch "$LOG" 2>/dev/null || LOG="$HOME/it_monitor.log"

# 디스크 사용률
DISK_USAGE=$(df -h / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
if [ "$DISK_USAGE" -ge "$ALERT_DISK" ]; then
    STATUS="경고"
    ALERTS="${ALERTS}디스크 ${DISK_USAGE}%(임계:${ALERT_DISK}%) "
    echo "[$NOW] [경고] 디스크 사용률: ${DISK_USAGE}% (임계값: ${ALERT_DISK}%)" | tee -a "$LOG"
fi

# 메모리 사용률
MEM_TOTAL=$(free | awk '/^Mem:/{print $2}')
MEM_USED=$(free  | awk '/^Mem:/{print $3}')
MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
if [ "$MEM_PCT" -ge "$ALERT_MEM" ]; then
    STATUS="경고"
    ALERTS="${ALERTS}메모리 ${MEM_PCT}%(임계:${ALERT_MEM}%) "
    echo "[$NOW] [경고] 메모리 사용률: ${MEM_PCT}% (임계값: ${ALERT_MEM}%)" | tee -a "$LOG"
fi

# PostgreSQL 프로세스 확인
if ! pgrep -x "postgres" > /dev/null; then
    STATUS="긴급"
    echo "[$NOW] [긴급] PostgreSQL 서비스 다운 감지! 재시작 시도..." | tee -a "$LOG"
    sudo systemctl restart postgresql
    sleep 3
    if pgrep -x "postgres" > /dev/null; then
        echo "[$NOW] [복구] PostgreSQL 재시작 성공" | tee -a "$LOG"
    else
        echo "[$NOW] [실패] PostgreSQL 재시작 실패! 수동 확인 필요" | tee -a "$LOG"
    fi
fi

# CPU 로드 확인
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
echo "[$NOW] [$STATUS] 디스크:${DISK_USAGE}% | 메모리:${MEM_PCT}% | CPU부하:${CPU_LOAD} ${ALERTS}" >> "$LOG"
