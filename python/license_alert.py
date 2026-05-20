# license_alert.py
from db_connect import query_to_df
from datetime import datetime
import schedule
import time

SQL = """
SELECT
    s.sw_name,
    a.asset_name,
    e.emp_name AS user_name,
    d.dept_name,
    l.expire_date,
    DATEDIFF(DAY, GETDATE(), l.expire_date) AS days_left,
    CASE
        WHEN l.expire_date < GETDATE()                          THEN '만료됨'
        WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 7       THEN '긴급'
        WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 30      THEN '주의'
        ELSE '예정'
    END AS alert_level
FROM LICENSE l
JOIN SOFTWARE s ON l.sw_id    = s.sw_id
JOIN ASSET    a ON l.asset_id = a.asset_id
LEFT JOIN ASSET_ASSIGNMENT ag ON a.asset_id = ag.asset_id AND ag.return_date IS NULL
LEFT JOIN EMPLOYEE e ON ag.emp_id = e.emp_id
LEFT JOIN DEPT     d ON e.dept_id = d.dept_id
WHERE l.expire_date <= DATEADD(DAY, 90, GETDATE())
ORDER BY l.expire_date
"""

LEVEL_ICON = {
    '만료됨': '[만료]',
    '긴급':   '[긴급]',
    '주의':   '[주의]',
    '예정':   '[예정]',
}

def check_licenses():
    now = datetime.now().strftime('%Y-%m-%d %H:%M')
    print(f"\n{'='*55}")
    print(f"[{now}] 라이선스 만료 현황 점검")
    print(f"{'='*55}")

    df = query_to_df(SQL)

    if df.empty:
        print("만료 예정 라이선스 없음")
        return

    for _, row in df.iterrows():
        icon = LEVEL_ICON.get(row['alert_level'], '[알림]')
        expire = str(row['expire_date'])[:10]
        days = int(row['days_left']) if row['days_left'] is not None else 0
        user = row['user_name'] if row['user_name'] else '미배정'
        dept = row['dept_name'] if row['dept_name'] else '-'

        print(
            f"{icon} {row['sw_name']:<25} | "
            f"장비: {row['asset_name']:<20} | "
            f"사용자: {user} ({dept}) | "
            f"만료: {expire} | 잔여: {days}일"
        )

    print(f"\n총 {len(df)}건 / "
          f"만료됨: {len(df[df.alert_level=='만료됨'])}건 / "
          f"긴급: {len(df[df.alert_level=='긴급'])}건 / "
          f"주의: {len(df[df.alert_level=='주의'])}건")

# 매일 오전 9시 자동 실행 (한 번 실행 후 스케줄 대기)
schedule.every().day.at("09:00").do(check_licenses)

if __name__ == "__main__":
    check_licenses()   # 즉시 1회 실행
    print("\n[스케줄 대기 중] 매일 09:00에 자동 실행됩니다. Ctrl+C로 종료.")
    while True:
        schedule.run_pending()
        time.sleep(60)