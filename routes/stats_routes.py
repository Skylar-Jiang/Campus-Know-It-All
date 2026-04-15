from flask import render_template

from core.auth import login_required
from core.db import get_db_connection


def register_stats_routes(app):
    @app.route("/statistics")
    @login_required
    def statistics():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM v_activity_summary ORDER BY activity_id")
                rows = cur.fetchall()
                cur.execute("SELECT * FROM v_hot_activity_top10")
                top_rows = cur.fetchall()

        return render_template("statistics.html", rows=rows, top_rows=top_rows)
