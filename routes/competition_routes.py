from flask import current_app, flash, g, redirect, render_template, request, url_for

from core.auth import can_manage_competition, login_required, role_required
from core.db import get_db_connection


def register_competition_routes(app):
    @app.route("/competitions")
    @login_required
    def competitions():
        title = request.args.get("title", "").strip()
        category = request.args.get("category", "").strip()

        sql = """
        SELECT cp.competition_id, cp.club_id, cp.title, cp.category, cp.organizer,
               cp.official_url, cp.start_time, cp.end_time, cp.status, c.club_name
        FROM competition cp
        JOIN club c ON c.club_id = cp.club_id
        WHERE cp.status = 'published'
        """
        params = []
        if title:
            sql += " AND cp.title LIKE %s"
            params.append(f"%{title}%")
        if category:
            sql += " AND cp.category = %s"
            params.append(category)
        sql += " ORDER BY cp.start_time DESC, cp.competition_id DESC"

        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()

        return render_template(
            "competitions.html",
            competitions=rows,
            title=title,
            category=category,
            categories=current_app.config["COMPETITION_CATEGORIES"],
        )

    @app.route("/competition/<int:competition_id>")
    @login_required
    def competition_detail(competition_id):
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT cp.competition_id, cp.club_id, cp.title, cp.category, cp.organizer,
                           cp.official_url, cp.summary, cp.start_time, cp.end_time,
                           cp.status, cp.create_time, c.club_name
                    FROM competition cp
                    JOIN club c ON c.club_id = cp.club_id
                    WHERE cp.competition_id = %s
                    """,
                    (competition_id,),
                )
                item = cur.fetchone()

        if not item:
            flash("竞赛不存在。", "error")
            return redirect(url_for("competitions"))

        if item["status"] != "published" and not can_manage_competition(g.current_user, item):
            flash("该竞赛尚未发布。", "error")
            return redirect(url_for("competitions"))

        return render_template(
            "competition_detail.html",
            competition=item,
            can_manage=can_manage_competition(g.current_user, item),
        )

    @app.route("/competition/manage")
    @role_required("admin", "club")
    def competition_manage():
        query = """
        SELECT cp.competition_id, cp.club_id, cp.title, cp.category, cp.organizer,
               cp.start_time, cp.end_time, cp.status, c.club_name
        FROM competition cp
        JOIN club c ON c.club_id = cp.club_id
        WHERE 1=1
        """
        params = []
        if g.current_user["role"] == "club":
            query += " AND cp.club_id = %s"
            params.append(g.current_user["club_id"])
        query += " ORDER BY cp.competition_id DESC"

        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, params)
                rows = cur.fetchall()

                clubs = []
                if g.current_user["role"] == "admin":
                    cur.execute("SELECT club_id, club_name FROM club ORDER BY club_name")
                    clubs = cur.fetchall()

        return render_template(
            "competition_manage.html",
            competitions=rows,
            clubs=clubs,
            categories=current_app.config["COMPETITION_CATEGORIES"],
            status_choices=current_app.config["COMPETITION_STATUS"],
        )

    @app.route("/competition/create", methods=["POST"])
    @role_required("admin", "club")
    def competition_create():
        title = request.form.get("title", "").strip()
        category = request.form.get("category", "").strip()
        organizer = request.form.get("organizer", "").strip()
        official_url = request.form.get("official_url", "").strip()
        start_time = request.form.get("start_time", "").strip()
        end_time = request.form.get("end_time", "").strip()
        summary = request.form.get("summary", "").strip()

        if not title or not category or not organizer or not official_url or not summary:
            flash("请完整填写竞赛标题、分类、主办方、官方链接和简介。", "error")
            return redirect(url_for("competition_manage"))

        club_id = g.current_user["club_id"]
        if g.current_user["role"] == "admin":
            selected = request.form.get("club_id", "").strip()
            if not selected.isdigit():
                flash("管理员创建竞赛时必须选择社团。", "error")
                return redirect(url_for("competition_manage"))
            club_id = int(selected)

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO competition(
                          club_id, title, category, organizer, official_url,
                          summary, start_time, end_time, status
                        ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'draft')
                        """,
                        (
                            club_id,
                            title,
                            category,
                            organizer,
                            official_url,
                            summary,
                            start_time or None,
                            end_time or None,
                        ),
                    )
                conn.commit()
                flash("竞赛创建成功，当前状态为 draft。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"竞赛创建失败：{exc}", "error")

        return redirect(url_for("competition_manage"))

    @app.route("/competition/update/<int:competition_id>", methods=["POST"])
    @role_required("admin", "club")
    def competition_update(competition_id):
        title = request.form.get("title", "").strip()
        category = request.form.get("category", "").strip()
        organizer = request.form.get("organizer", "").strip()
        official_url = request.form.get("official_url", "").strip()
        start_time = request.form.get("start_time", "").strip()
        end_time = request.form.get("end_time", "").strip()
        summary = request.form.get("summary", "").strip()

        if not title or not category or not organizer or not official_url or not summary:
            flash("请完整填写竞赛更新信息。", "error")
            return redirect(url_for("competition_detail", competition_id=competition_id))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT competition_id, club_id FROM competition WHERE competition_id = %s", (competition_id,))
                    row = cur.fetchone()
                    if not row:
                        flash("竞赛不存在。", "error")
                        return redirect(url_for("competition_manage"))
                    if not can_manage_competition(g.current_user, row):
                        flash("你没有权限修改该竞赛。", "error")
                        return redirect(url_for("competitions"))

                    cur.execute(
                        """
                        UPDATE competition
                        SET title=%s, category=%s, organizer=%s, official_url=%s,
                            start_time=%s, end_time=%s, summary=%s
                        WHERE competition_id=%s
                        """,
                        (
                            title,
                            category,
                            organizer,
                            official_url,
                            start_time or None,
                            end_time or None,
                            summary,
                            competition_id,
                        ),
                    )
                conn.commit()
                flash("竞赛信息更新成功。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"竞赛更新失败：{exc}", "error")

        return redirect(url_for("competition_detail", competition_id=competition_id))

    @app.route("/competition/status/<int:competition_id>", methods=["POST"])
    @role_required("admin", "club")
    def competition_change_status(competition_id):
        status = request.form.get("status", "").strip()
        if status not in current_app.config["COMPETITION_STATUS"]:
            flash("非法竞赛状态。", "error")
            return redirect(url_for("competition_manage"))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT competition_id, club_id FROM competition WHERE competition_id = %s", (competition_id,))
                    row = cur.fetchone()
                    if not row:
                        flash("竞赛不存在。", "error")
                        return redirect(url_for("competition_manage"))
                    if not can_manage_competition(g.current_user, row):
                        flash("你没有权限修改该竞赛状态。", "error")
                        return redirect(url_for("competitions"))

                    cur.execute("UPDATE competition SET status=%s WHERE competition_id=%s", (status, competition_id))
                conn.commit()
                flash(f"竞赛状态已更新为 {status}。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"竞赛状态更新失败：{exc}", "error")

        return redirect(url_for("competition_manage"))
