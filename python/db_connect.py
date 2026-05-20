# db_connect.py
import pyodbc
import pandas as pd

# ODBC 드라이버 버전 확인 후 맞게 수정
# 'ODBC Driver 17 for SQL Server' 또는 'ODBC Driver 18 for SQL Server'
DRIVER_VERSION = 17

DB_CONFIG = {
    "server":   "localhost\\SQLEXPRESS01",
    "database": "IT_Asset_DB",
}

def get_conn():
    conn_str = (
        f"DRIVER={{ODBC Driver {DRIVER_VERSION} for SQL Server}};"
        f"SERVER={DB_CONFIG['server']};"
        f"DATABASE={DB_CONFIG['database']};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)

def query_to_df(sql: str) -> pd.DataFrame:
    with get_conn() as conn:
        return pd.read_sql(sql, conn)

def execute_query(sql: str):
    with get_conn() as conn:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()

# 연결 테스트
if __name__ == "__main__":
    try:
        df = query_to_df("SELECT COUNT(*) AS cnt FROM ASSET")
        print(f"연결 성공! ASSET 테이블 행 수: {df['cnt'][0]}")
    except Exception as e:
        print(f"연결 실패: {e}")