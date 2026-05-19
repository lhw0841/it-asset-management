# it-asset-management
it 자산관리 시스템
# IT 자산관리 시스템 (IT Asset Management System)

기업 전산 업무 자동화를 위해 직접 설계·구현한 IT 자산관리 포트폴리오입니다.

## 기술 스택

| 항목 | 기술 |
|------|------|
| Database | MS SQL Server 2025 Express (Windows) |
| Database | PostgreSQL (Linux) |
| Language | T-SQL, Python 3.14 |
| 자동화 | Linux Cron |
| 협업 | Git / GitHub |

## 구현 내용

| 항목 | 상세 |
|------|------|
| DB 설계 | 14개 테이블, 인덱스 9개, CHECK 제약 4개 |
| 비즈니스 로직 | 저장 프로시저 5개, 트리거 2개 |
| 고급 쿼리 | CTE, 윈도우 함수(RANK/LAG), CASE WHEN, VIEW 3개 |
| Python 자동화 | 라이선스 만료 알림, Excel 월간 보고서 자동 생성 |
| Linux 운영 | DB 자동 백업(압축/보존), 시스템 모니터링, Cron 등록 |

## 주요 기능

- 장비 배정/반납 트랜잭션 처리 (SP_ASSIGN_ASSET, SP_RETURN_ASSET)
- 모든 자산 변경 이력 자동 감사추적 (TR_ASSET_AUDIT → AUDIT_LOG)
- 장비 노후화 분석 및 교체 권고 (CTE 2단계)
- 라이선스 만료 90/30/7일 전 단계별 자동 알림 (Python + schedule)
- 월간 자산현황 Excel 보고서 4시트 자동 생성 (Python + openpyxl)
- DB 자동 백업 + 30일 보존 정책 (Linux Shell + cron)
- 서버 리소스 모니터링 + PostgreSQL 자동 재시작 (Shell)

## ERD

![ERD](./docs/ERD.png)

## 폴더 구조

```
it-asset-management/
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_insert_data.sql
│   ├── 03_stored_procedures.sql
│   └── 04_advanced_queries.sql
├── python/
│   ├── db_connect.py
│   ├── license_alert.py
│   ├── monthly_report.py
│   └── requirements.txt
├── linux/
│   ├── backup.sh
│   ├── monitor.sh
│   └── crontab_example.txt
└── docs/
    ├── ERD.png
    └── operation_manual.md
```