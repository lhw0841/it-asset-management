# IT 자산관리 시스템 운영 매뉴얼

## 1. 장비 배정

```sql
EXEC SP_ASSIGN_ASSET @asset_id = 5, @emp_id = 3;
```
장비 상태가 '보관중'일 때만 배정 가능. 배정 시 자동으로 '사용중'으로 변경.

## 2. 장비 반납

```sql
EXEC SP_RETURN_ASSET @asset_id = 5;
```
반납 시 자동으로 '보관중'으로 변경.

## 3. 장애 등록

```sql
EXEC SP_REGISTER_INCIDENT
    @asset_id    = 3,
    @emp_id      = 2,
    @priority    = 2,
    @category    = '하드웨어',
    @description = '모니터 화면 줄 발생';
```
priority: 1=긴급, 2=높음, 3=보통, 4=낮음, 5=최저.
긴급(1) 등록 시 장비 상태 자동으로 '수리중' 변경.

## 4. 장애 처리 완료

```sql
EXEC SP_RESOLVE_INCIDENT
    @inc_id       = 10,
    @resolver_id  = 7,
    @resolve_note = '모니터 교체 완료';
```

## 5. 월간 보고서 생성

```bash
cd python/
python monthly_report.py
# IT자산보고서_YYYYMM.xlsx 생성
```

## 6. DB 백업 및 복구 (Linux)

```bash
# 수동 백업
./linux/backup.sh

# 백업 파일 확인
ls -lh ~/backups/

# 복구
gunzip -c ~/backups/it_asset_db_20260520_142248.sql.gz | \
  psql -h localhost -U itadmin -d it_asset_db
```

## 7. 라이선스 만료 알림

```bash
cd python/
python license_alert.py
```