from contextlib import contextmanager

import pymysql
from flask import current_app


@contextmanager
def get_db_connection():
    """Create a short-lived DB connection for each request operation."""
    conn = pymysql.connect(
        host=current_app.config["DB_HOST"],
        port=current_app.config["DB_PORT"],
        user=current_app.config["DB_USER"],
        password=current_app.config["DB_PASSWORD"],
        database=current_app.config["DB_NAME"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
    )
    try:
        yield conn
    finally:
        conn.close()
