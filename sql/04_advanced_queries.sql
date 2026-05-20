USE IT_Asset_DB;
GO
WITH AssetAge AS (
    SELECT
        a.asset_id, a.asset_name, a.purchase_date, a.purchase_cost,
        at.type_name, at.depreciation_years,
        d.dept_name,
        DATEDIFF(YEAR, a.purchase_date, GETDATE()) AS age_year,
        e.emp_name AS assigned_user
    FROM ASSET a
    JOIN ASSET_TYPE at ON a.type_id = at.type_id
    LEFT JOIN ASSET_ASSIGNMENT ag ON a.asset_id = ag.asset_id
                                  AND ag.return_date IS NULL
    LEFT JOIN EMPLOYEE e ON ag.emp_id = e.emp_id
    LEFT JOIN DEPT     d ON e.dept_id = d.dept_id
    WHERE a.status != '폐기'
),
ReplaceFlag AS (
    SELECT *,
        CASE
            WHEN age_year >= depreciation_years + 2 THEN '즉시교체'
            WHEN age_year >= depreciation_years     THEN '교체권고'
            WHEN age_year >= depreciation_years - 1 THEN '교체예정'
            ELSE '정상'
        END AS replace_status
    FROM AssetAge
)
SELECT
    dept_name AS 부서, type_name AS 유형, asset_name AS 장비명,
    assigned_user AS 사용자, age_year AS 사용연수,
    replace_status AS 교체상태,
    FORMAT(purchase_cost, 'N0') AS 구매가격
FROM ReplaceFlag
WHERE replace_status != '정상'
ORDER BY
    CASE replace_status
        WHEN '즉시교체' THEN 1
        WHEN '교체권고' THEN 2
        ELSE 3
    END;

USE IT_Asset_DB;
GO

SELECT
    월,
    장애건수,
    긴급건수,
    처리완료,
    평균처리시간,
    LAG(장애건수) OVER (ORDER BY 월) AS 전월건수,
    장애건수 - LAG(장애건수) OVER (ORDER BY 월) AS 증감,
    SUM(장애건수) OVER (ORDER BY 월 ROWS UNBOUNDED PRECEDING) AS 누적건수
FROM (
    SELECT
        FORMAT(reported_at, 'yyyy-MM') AS 월,
        COUNT(*) AS 장애건수,
        SUM(CASE WHEN priority = 1 THEN 1 ELSE 0 END) AS 긴급건수,
        SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END) AS 처리완료,
        CAST(AVG(CAST(resolve_hours AS FLOAT)) AS DECIMAL(5,1)) AS 평균처리시간
    FROM INCIDENT
    GROUP BY FORMAT(reported_at, 'yyyy-MM')
) AS monthly
ORDER BY 월;

USE IT_Asset_DB;
GO

SELECT
    d.dept_name AS 부서,
    a.asset_name AS 장비명,
    at.type_name AS 유형,
    FORMAT(a.purchase_cost, 'N0') AS 구매가,
    -- 부서 내 구매가 순위
    RANK() OVER (PARTITION BY d.dept_name ORDER BY a.purchase_cost DESC) AS 부서내순위,
    -- 전체 구매가 순위
    RANK() OVER (ORDER BY a.purchase_cost DESC) AS 전체순위,
    -- 부서별 평균 대비
    FORMAT(a.purchase_cost - AVG(a.purchase_cost)
        OVER (PARTITION BY d.dept_name), 'N0') AS 부서평균대비
FROM ASSET a
JOIN ASSET_TYPE at ON a.type_id = at.type_id
LEFT JOIN ASSET_ASSIGNMENT ag ON a.asset_id = ag.asset_id AND ag.return_date IS NULL
LEFT JOIN EMPLOYEE e ON ag.emp_id = e.emp_id
LEFT JOIN DEPT d ON e.dept_id = d.dept_id
WHERE a.status = '사용중'
ORDER BY d.dept_name, 부서내순위;

USE IT_Asset_DB;
GO

SELECT
    s.sw_name AS 소프트웨어,
    a.asset_name AS 설치장비,
    e.emp_name AS 사용자,
    d.dept_name AS 부서,
    l.expire_date AS 만료일,
    DATEDIFF(DAY, GETDATE(), l.expire_date) AS 잔여일수,
    CASE
        WHEN l.expire_date < GETDATE()                          THEN '⚠ 만료됨'
        WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 7       THEN '🔴 긴급(7일 이내)'
        WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 30      THEN '🟠 주의(30일 이내)'
        WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 90      THEN '🟡 예정(90일 이내)'
        ELSE '🟢 정상'
    END AS 알림상태,
    l.seat_count AS 라이선스수
FROM LICENSE l
JOIN SOFTWARE s ON l.sw_id    = s.sw_id
JOIN ASSET    a ON l.asset_id = a.asset_id
LEFT JOIN ASSET_ASSIGNMENT ag ON a.asset_id = ag.asset_id AND ag.return_date IS NULL
LEFT JOIN EMPLOYEE e ON ag.emp_id = e.emp_id
LEFT JOIN DEPT     d ON e.dept_id = d.dept_id
ORDER BY l.expire_date;

USE IT_Asset_DB;
GO

-- VIEW 1: 자산 전체 현황 대시보드
CREATE VIEW VW_ASSET_DASHBOARD AS
SELECT
    a.asset_id, a.asset_name, at.type_name,
    a.status, a.serial_no, a.purchase_date, a.purchase_cost,
    a.warranty_end, a.location,
    v.vendor_name AS 공급업체,
    e.emp_name AS 사용자,
    d.dept_name AS 부서,
    DATEDIFF(YEAR, a.purchase_date, GETDATE()) AS 사용연수,
    CASE
        WHEN a.warranty_end IS NULL      THEN '정보없음'
        WHEN a.warranty_end < GETDATE()  THEN '보증만료'
        ELSE '보증유효'
    END AS 보증상태
FROM ASSET a
JOIN ASSET_TYPE at ON a.type_id = at.type_id
LEFT JOIN VENDOR v ON a.vendor_id = v.vendor_id
LEFT JOIN ASSET_ASSIGNMENT ag ON a.asset_id = ag.asset_id AND ag.return_date IS NULL
LEFT JOIN EMPLOYEE e ON ag.emp_id = e.emp_id
LEFT JOIN DEPT d ON e.dept_id = d.dept_id;
GO

-- VIEW 2: 미처리 장애 현황 (SLA 포함)
CREATE VIEW VW_OPEN_INCIDENTS AS
SELECT
    i.inc_id, i.priority,
    CASE i.priority
        WHEN 1 THEN '긴급'
        WHEN 2 THEN '높음'
        WHEN 3 THEN '보통'
        WHEN 4 THEN '낮음'
        ELSE '최저'
    END AS 우선순위,
    a.asset_name, at.type_name,
    e.emp_name AS 신고자, d.dept_name AS 부서,
    i.reported_at, i.description,
    DATEDIFF(HOUR, i.reported_at, GETDATE()) AS 경과시간_시간,
    CASE
        WHEN DATEDIFF(HOUR, i.reported_at, GETDATE()) > 48 THEN 'SLA 심각위반'
        WHEN DATEDIFF(HOUR, i.reported_at, GETDATE()) > 24 THEN 'SLA 위반'
        ELSE '처리중'
    END AS SLA상태
FROM INCIDENT i
JOIN ASSET     a  ON i.asset_id = a.asset_id
JOIN ASSET_TYPE at ON a.type_id  = at.type_id
JOIN EMPLOYEE  e  ON i.emp_id   = e.emp_id
JOIN DEPT      d  ON e.dept_id  = d.dept_id
WHERE i.resolved_at IS NULL;
GO

-- VIEW 3: 라이선스 현황 + 만료 알림
CREATE VIEW VW_LICENSE_STATUS AS
SELECT
    l.lic_id, s.sw_name, s.version, s.license_type,
    a.asset_name, e.emp_name AS 사용자, d.dept_name AS 부서,
    l.expire_date, l.seat_count,
    DATEDIFF(DAY, GETDATE(), l.expire_date) AS 잔여일수,
    CASE
        WHEN l.expire_date < GETDATE()                     THEN '만료됨'
        WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 30 THEN '긴급갱신'
        WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 90 THEN '갱신예정'
        ELSE '정상'
    END AS 만료상태
FROM LICENSE l
JOIN SOFTWARE s ON l.sw_id    = s.sw_id
JOIN ASSET    a ON l.asset_id = a.asset_id
LEFT JOIN ASSET_ASSIGNMENT ag ON a.asset_id = ag.asset_id AND ag.return_date IS NULL
LEFT JOIN EMPLOYEE e ON ag.emp_id = e.emp_id
LEFT JOIN DEPT     d ON e.dept_id = d.dept_id;
GO

-- 뷰 테스트
SELECT * FROM VW_ASSET_DASHBOARD;
SELECT * FROM VW_OPEN_INCIDENTS;
SELECT * FROM VW_LICENSE_STATUS WHERE 만료상태 != '정상';

