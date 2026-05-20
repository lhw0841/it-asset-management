USE IT_Asset_DB;
GO

CREATE PROCEDURE SP_ASSIGN_ASSET
    @asset_id    INT,
    @emp_id      INT,
    @assign_date DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @assign_date IS NULL
        SET @assign_date = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1. 이미 배정된 장비인지 확인
        IF EXISTS (
            SELECT 1 FROM ASSET_ASSIGNMENT
            WHERE asset_id = @asset_id AND return_date IS NULL
        )
            THROW 50001, '이미 배정된 장비입니다. 반납 후 재배정하세요.', 1;

        -- 2. 장비 상태 확인
        IF NOT EXISTS (
            SELECT 1 FROM ASSET
            WHERE asset_id = @asset_id AND status = '보관중'
        )
            THROW 50002, '배정 가능한 상태(보관중)의 장비가 아닙니다.', 1;

        -- 3. 직원 존재 확인
        IF NOT EXISTS (SELECT 1 FROM EMPLOYEE WHERE emp_id = @emp_id)
            THROW 50003, '존재하지 않는 직원입니다.', 1;

        -- 4. 배정 이력 등록
        INSERT INTO ASSET_ASSIGNMENT (asset_id, emp_id, assign_date)
        VALUES (@asset_id, @emp_id, @assign_date);

        -- 5. 장비 상태 → 사용중 자동 변경
        UPDATE ASSET SET status = '사용중'
        WHERE asset_id = @asset_id;

        COMMIT TRANSACTION;
        SELECT '배정 완료' AS result, @asset_id AS asset_id, @emp_id AS emp_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS error_msg;
    END CATCH
END;
GO

-- 실행 테스트
EXEC SP_ASSIGN_ASSET @asset_id = 6, @emp_id = 11;

USE IT_Asset_DB;
GO

CREATE PROCEDURE SP_RETURN_ASSET
    @asset_id   INT,
    @return_date DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @return_date IS NULL
        SET @return_date = CAST(GETDATE() AS DATE);

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 현재 배정 이력 확인
        IF NOT EXISTS (
            SELECT 1 FROM ASSET_ASSIGNMENT
            WHERE asset_id = @asset_id AND return_date IS NULL
        )
            THROW 50004, '현재 배정된 이력이 없는 장비입니다.', 1;

        -- 반납일 업데이트
        UPDATE ASSET_ASSIGNMENT
        SET return_date = @return_date
        WHERE asset_id = @asset_id AND return_date IS NULL;

        -- 장비 상태 → 보관중
        UPDATE ASSET SET status = '보관중'
        WHERE asset_id = @asset_id;

        COMMIT TRANSACTION;
        SELECT '반납 완료' AS result, @asset_id AS asset_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS error_msg;
    END CATCH
END;
GO

-- 실행 테스트
EXEC SP_RETURN_ASSET @asset_id = 6;

USE IT_Asset_DB;
GO

CREATE PROCEDURE SP_REGISTER_INCIDENT
    @asset_id   INT,
    @emp_id     INT,
    @priority   TINYINT,
    @category   NVARCHAR(50),
    @description NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 장비 존재 확인
        IF NOT EXISTS (SELECT 1 FROM ASSET WHERE asset_id = @asset_id)
            THROW 50005, '존재하지 않는 장비입니다.', 1;

        -- 긴급(priority=1)이면 장비 상태 → 수리중
        IF @priority = 1
            UPDATE ASSET SET status = '수리중'
            WHERE asset_id = @asset_id;

        INSERT INTO INCIDENT (asset_id, emp_id, priority, category, description)
        VALUES (@asset_id, @emp_id, @priority, @category, @description);

        COMMIT TRANSACTION;
        SELECT '장애 등록 완료' AS result, SCOPE_IDENTITY() AS inc_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS error_msg;
    END CATCH
END;
GO

-- 실행 테스트
EXEC SP_REGISTER_INCIDENT
    @asset_id    = 25,
    @emp_id      = 5,
    @priority    = 3,
    @category    = '소프트웨어',
    @description = '윈도우 업데이트 후 부팅 불가';

USE IT_Asset_DB;
GO

CREATE PROCEDURE SP_RESOLVE_INCIDENT
    @inc_id      INT,
    @resolver_id INT,
    @resolve_note NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @asset_id INT;

        IF NOT EXISTS (SELECT 1 FROM INCIDENT WHERE inc_id = @inc_id AND resolved_at IS NULL)
            THROW 50006, '존재하지 않거나 이미 처리된 장애입니다.', 1;

        SELECT @asset_id = asset_id FROM INCIDENT WHERE inc_id = @inc_id;

        UPDATE INCIDENT
        SET resolved_at  = GETDATE(),
            resolver_id  = @resolver_id,
            resolve_note = @resolve_note
        WHERE inc_id = @inc_id;

        -- 수리중 장비 → 사용중으로 복구
        UPDATE ASSET SET status = '사용중'
        WHERE asset_id = @asset_id AND status = '수리중';

        COMMIT TRANSACTION;
        SELECT '처리 완료' AS result, @inc_id AS inc_id;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS error_msg;
    END CATCH
END;
GO

-- 실행 테스트
EXEC SP_RESOLVE_INCIDENT
    @inc_id       = 5,
    @resolver_id  = 7,
    @resolve_note = '윈도우 복구 모드로 부팅 후 정상화';

USE IT_Asset_DB;
GO

CREATE PROCEDURE SP_MONTHLY_REPORT
    @year  INT = NULL,
    @month INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @year  IS NULL SET @year  = YEAR(GETDATE());
    IF @month IS NULL SET @month = MONTH(GETDATE());

    PRINT '==============================';
    PRINT '월간 IT 자산 현황 보고서';
    PRINT '==============================';

    -- 1. 전체 자산 요약
    SELECT '자산현황' AS 구분,
        COUNT(*) AS 총장비수,
        SUM(CASE WHEN status='사용중' THEN 1 ELSE 0 END) AS 사용중,
        SUM(CASE WHEN status='보관중' THEN 1 ELSE 0 END) AS 보관중,
        SUM(CASE WHEN status='수리중' THEN 1 ELSE 0 END) AS 수리중,
        SUM(CASE WHEN status='폐기'   THEN 1 ELSE 0 END) AS 폐기,
        FORMAT(SUM(CASE WHEN status != '폐기' THEN purchase_cost ELSE 0 END), 'N0') AS 총자산가액
    FROM ASSET;

    -- 2. 부서별 장비 현황
    SELECT d.dept_name AS 부서명,
        COUNT(ag.assign_id) AS 보유장비수,
        FORMAT(SUM(a.purchase_cost), 'N0') AS 총자산가액
    FROM DEPT d
    LEFT JOIN EMPLOYEE e ON d.dept_id = e.dept_id
    LEFT JOIN ASSET_ASSIGNMENT ag ON e.emp_id = ag.emp_id AND ag.return_date IS NULL
    LEFT JOIN ASSET a ON ag.asset_id = a.asset_id
    GROUP BY d.dept_name
    ORDER BY 보유장비수 DESC;

    -- 3. 당월 장애 현황
    SELECT '장애현황' AS 구분,
        COUNT(*) AS 총건수,
        SUM(CASE WHEN resolved_at IS NOT NULL THEN 1 ELSE 0 END) AS 처리완료,
        SUM(CASE WHEN resolved_at IS NULL     THEN 1 ELSE 0 END) AS 미처리,
        CAST(AVG(CAST(resolve_hours AS FLOAT)) AS DECIMAL(5,1)) AS 평균처리시간_시간
    FROM INCIDENT
    WHERE YEAR(reported_at) = @year AND MONTH(reported_at) = @month;

    -- 4. 90일 내 만료 라이선스
    SELECT s.sw_name AS 소프트웨어,
        a.asset_name AS 설치장비,
        l.expire_date AS 만료일,
        DATEDIFF(DAY, GETDATE(), l.expire_date) AS 잔여일수,
        CASE
            WHEN l.expire_date < GETDATE()                          THEN '만료됨'
            WHEN DATEDIFF(DAY, GETDATE(), l.expire_date) <= 30      THEN '긴급갱신'
            ELSE '갱신예정'
        END AS 상태
    FROM LICENSE l
    JOIN SOFTWARE s ON l.sw_id    = s.sw_id
    JOIN ASSET    a ON l.asset_id = a.asset_id
    WHERE l.expire_date <= DATEADD(DAY, 90, GETDATE())
    ORDER BY l.expire_date;
END;
GO

-- 실행
EXEC SP_MONTHLY_REPORT;

USE IT_Asset_DB;
GO

CREATE TRIGGER TR_ASSET_AUDIT
ON ASSET
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @action NVARCHAR(10);

    IF EXISTS (SELECT 1 FROM INSERTED) AND EXISTS (SELECT 1 FROM DELETED)
        SET @action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM INSERTED)
        SET @action = 'INSERT';
    ELSE
        SET @action = 'DELETE';

    INSERT INTO AUDIT_LOG (table_name, action, record_id, old_value, new_value)
    SELECT
        'ASSET',
        @action,
        COALESCE(i.asset_id, d.asset_id),
        CASE WHEN d.asset_id IS NOT NULL THEN
            'status:' + d.status + ' | cost:' + CAST(d.purchase_cost AS NVARCHAR)
        END,
        CASE WHEN i.asset_id IS NOT NULL THEN
            'status:' + i.status + ' | cost:' + CAST(i.purchase_cost AS NVARCHAR)
        END
    FROM INSERTED i
    FULL OUTER JOIN DELETED d ON i.asset_id = d.asset_id;
END;
GO

-- 트리거 동작 확인 테스트
UPDATE ASSET SET status = '수리중' WHERE asset_id = 3;
SELECT * FROM AUDIT_LOG;
-- AUDIT_LOG에 UPDATE 이력이 기록되어야 함

USE IT_Asset_DB;
GO

CREATE TRIGGER TR_LICENSE_EXPIRE_CHECK
ON LICENSE
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 만료된 라이선스 INSERT/UPDATE 시도 시 경고 로그 기록
    INSERT INTO AUDIT_LOG (table_name, action, record_id, old_value, new_value)
    SELECT
        'LICENSE',
        'WARNING',
        i.lic_id,
        NULL,
        'expire_date:' + CONVERT(NVARCHAR, i.expire_date, 23) + ' | 만료된 라이선스 등록 시도'
    FROM INSERTED i
    WHERE i.expire_date < GETDATE();
END;
GO