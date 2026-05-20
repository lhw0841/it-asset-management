USE IT_Asset_DB;
GO
-- 1단계 : 핵심 엔티티 테이블 4개 (참조 당하는 테이블 먼저)
CREATE TABLE DEPT (
    dept_id   INT          PRIMARY KEY IDENTITY(1,1),
    dept_name NVARCHAR(50) NOT NULL,
    location  NVARCHAR(100)
);

CREATE TABLE VENDOR (
    vendor_id    INT          PRIMARY KEY IDENTITY(1,1),
    vendor_name  NVARCHAR(100) NOT NULL,
    contact      NVARCHAR(100),
    contract_end DATE
);

CREATE TABLE ASSET_TYPE (
    type_id            INT          PRIMARY KEY IDENTITY(1,1),
    type_name          NVARCHAR(50) NOT NULL,
    depreciation_years INT DEFAULT 5,
    replace_cycle      INT DEFAULT 5
);

CREATE TABLE SOFTWARE (
    sw_id        INT          PRIMARY KEY IDENTITY(1,1),
    sw_name      NVARCHAR(100) NOT NULL,
    vendor       NVARCHAR(100),
    version      NVARCHAR(30),
    license_type NVARCHAR(30)
);
GO

USE IT_Asset_DB;
GO

CREATE TABLE EMPLOYEE (
    emp_id    INT          PRIMARY KEY IDENTITY(1,1),
    emp_name  NVARCHAR(50) NOT NULL,
    dept_id   INT          REFERENCES DEPT(dept_id),
    position  NVARCHAR(30),
    join_date DATE,
    email     NVARCHAR(100) UNIQUE,
    phone     NVARCHAR(20)
);

CREATE TABLE ASSET (
    asset_id      INT           PRIMARY KEY IDENTITY(1,1),
    asset_name    NVARCHAR(100) NOT NULL,
    type_id       INT           NOT NULL REFERENCES ASSET_TYPE(type_id),
    vendor_id     INT           REFERENCES VENDOR(vendor_id),
    serial_no     NVARCHAR(50)  UNIQUE NOT NULL,
    purchase_date DATE          NOT NULL,
    purchase_cost DECIMAL(12,2) NOT NULL,
    warranty_end  DATE,
    status        NVARCHAR(20)  NOT NULL DEFAULT '사용중',
    location      NVARCHAR(100),
    note          NVARCHAR(500),
    created_at    DATETIME      DEFAULT GETDATE(),
    CONSTRAINT CK_ASSET_STATUS CHECK (status IN ('사용중','보관중','수리중','폐기')),
    CONSTRAINT CK_ASSET_COST   CHECK (purchase_cost >= 0)
);
CREATE INDEX IX_ASSET_STATUS   ON ASSET(status);
CREATE INDEX IX_ASSET_TYPE     ON ASSET(type_id);
CREATE INDEX IX_ASSET_PURCHASE ON ASSET(purchase_date);

CREATE TABLE NETWORK_DEVICE (
    dev_id     INT          PRIMARY KEY IDENTITY(1,1),
    dev_type   NVARCHAR(50) NOT NULL,
    ip_addr    NVARCHAR(45),
    location   NVARCHAR(100),
    managed_by INT          REFERENCES EMPLOYEE(emp_id)
);
GO

USE IT_Asset_DB;
GO

CREATE TABLE ASSET_ASSIGNMENT (
    assign_id   INT  PRIMARY KEY IDENTITY(1,1),
    asset_id    INT  NOT NULL REFERENCES ASSET(asset_id),
    emp_id      INT  NOT NULL REFERENCES EMPLOYEE(emp_id),
    assign_date DATE NOT NULL,
    return_date DATE
);
CREATE INDEX IX_ASSIGN_ASSET ON ASSET_ASSIGNMENT(asset_id);
CREATE INDEX IX_ASSIGN_EMP   ON ASSET_ASSIGNMENT(emp_id);

CREATE TABLE LICENSE (
    lic_id      INT  PRIMARY KEY IDENTITY(1,1),
    sw_id       INT  NOT NULL REFERENCES SOFTWARE(sw_id),
    asset_id    INT  NOT NULL REFERENCES ASSET(asset_id),
    expire_date DATE NOT NULL,
    seat_count  INT  DEFAULT 1
);
CREATE INDEX IX_LIC_EXPIRE ON LICENSE(expire_date);

CREATE TABLE MAINTENANCE (
    maint_id   INT           PRIMARY KEY IDENTITY(1,1),
    asset_id   INT           NOT NULL REFERENCES ASSET(asset_id),
    vendor_id  INT           REFERENCES VENDOR(vendor_id),
    type       NVARCHAR(50),
    cost       DECIMAL(12,2),
    maint_date DATE          NOT NULL,
    note       NVARCHAR(500)
);

CREATE TABLE INCIDENT (
    inc_id       INT           PRIMARY KEY IDENTITY(1,1),
    asset_id     INT           NOT NULL REFERENCES ASSET(asset_id),
    emp_id       INT           NOT NULL REFERENCES EMPLOYEE(emp_id),
    priority     TINYINT       NOT NULL DEFAULT 3,
    category     NVARCHAR(50),
    description  NVARCHAR(500) NOT NULL,
    reported_at  DATETIME      NOT NULL DEFAULT GETDATE(),
    resolved_at  DATETIME,
    resolver_id  INT           REFERENCES EMPLOYEE(emp_id),
    resolve_note NVARCHAR(500),
    resolve_hours AS (DATEDIFF(MINUTE, reported_at, resolved_at) / 60.0),
    CONSTRAINT CK_INC_PRIORITY CHECK (priority BETWEEN 1 AND 5),
    CONSTRAINT CK_INC_DATE     CHECK (resolved_at IS NULL OR resolved_at >= reported_at)
);
CREATE INDEX IX_INC_ASSET    ON INCIDENT(asset_id);
CREATE INDEX IX_INC_PRIORITY ON INCIDENT(priority, resolved_at);
GO

USE IT_Asset_DB;
GO

CREATE TABLE USER_ACCOUNT (
    acct_id     INT          PRIMARY KEY IDENTITY(1,1),
    emp_id      INT          NOT NULL REFERENCES EMPLOYEE(emp_id),
    system_name NVARCHAR(100) NOT NULL,
    username    NVARCHAR(100) NOT NULL,
    created_at  DATETIME     DEFAULT GETDATE(),
    expired_at  DATETIME,
    is_active   BIT          DEFAULT 1
);

CREATE TABLE IP_MGMT (
    ip_id    INT         PRIMARY KEY IDENTITY(1,1),
    ip_addr  NVARCHAR(45) NOT NULL UNIQUE,
    subnet   NVARCHAR(50),
    dev_id   INT         REFERENCES NETWORK_DEVICE(dev_id),
    emp_id   INT         REFERENCES EMPLOYEE(emp_id),
    purpose  NVARCHAR(100),
    status   NVARCHAR(20) DEFAULT '사용중'
);

CREATE TABLE AUDIT_LOG (
    log_id     INT           PRIMARY KEY IDENTITY(1,1),
    table_name NVARCHAR(50)  NOT NULL,
    action     NVARCHAR(10)  NOT NULL,
    record_id  INT,
    old_value  NVARCHAR(MAX),
    new_value  NVARCHAR(MAX),
    changed_by NVARCHAR(100) DEFAULT SYSTEM_USER,
    changed_at DATETIME      DEFAULT GETDATE(),
    ip_address NVARCHAR(45)
);
GO