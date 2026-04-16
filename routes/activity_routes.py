from flask import flash, g, redirect, render_template, request, url_for

from core.auth import can_manage_activity, login_required, role_required
from core.db import get_db_connection


def _friendly_register_error(exc):
    raw = str(exc)
    mappings = [
        ("Activity is not published", "活动尚未发布，暂不能报名。"),
        ("Signup deadline has passed", "报名截止时间已过。"),
        ("Duplicate registration is not allowed", "你已经报过这个活动，不能重复报名。"),
        ("Credit score too low for hot activity", "当前信用分不足，无法报名热门活动。"),
        ("Activity does not exist", "活动不存在或已被删除。"),
    ]
    for key, val in mappings:
        if key in raw:
            return val
    return f"系统拒绝此次报名，请检查活动状态或稍后再试。详情：{raw}"


def register_activity_routes(app):
    @app.route("/activities")
    @login_required
    def activities():
        title = request.args.get("title", "").strip()
        status = request.args.get("status", "").strip()

        sql = """
        SELECT
          a.activity_id,
          a.club_id,
          a.title,
          a.category,
          a.start_time,
          a.end_time,
          a.signup_deadline,
          a.max_capacity,
          a.status,
          c.club_name,
          v.venue_name,
          COALESCE(r.confirmed_count, 0) AS confirmed_count,
          COALESCE(r.waiting_count, 0) AS waiting_count
        FROM activity a
        JOIN club c ON c.club_id = a.club_id
        JOIN venue v ON v.venue_id = a.venue_id
        LEFT JOIN (
          SELECT
            activity_id,
            COUNT(CASE WHEN reg_status = 'confirmed' THEN 1 END) AS confirmed_count,
            COUNT(CASE WHEN reg_status = 'waiting' THEN 1 END) AS waiting_count
          FROM activity_registration
          GROUP BY activity_id
        ) r ON r.activity_id = a.activity_id
        WHERE 1=1
        """

        params = []
        club_scope_notice = None
        if g.current_user["role"] == "club" and g.current_user.get("club_id"):
            sql += " AND a.club_id = %s"
            params.append(g.current_user["club_id"])
        elif g.current_user["role"] == "club":
            club_scope_notice = "当前账号未绑定社团，已显示全部活动；如需管理功能，请把账号绑定到对应社团。"
        if title:
            sql += " AND a.title LIKE %s"
            params.append(f"%{title}%")
        if status:
            sql += " AND a.status = %s"
            params.append(status)

        sql += """
        ORDER BY
            FIELD(a.status, 'published', 'ongoing', 'draft', 'finished', 'cancelled'),
            a.start_time ASC,
            a.activity_id DESC
        """

        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()

        return render_template(
            "activities.html",
            activities=rows,
            title=title,
            status=status,
            club_scope_notice=club_scope_notice,
        )

    @app.route("/activity/<int:activity_id>")
    @login_required
    def activity_detail(activity_id):
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT
                      a.activity_id,
                      a.club_id,
                      a.venue_id,
                      a.title,
                      a.category,
                      a.description,
                      a.start_time,
                      a.end_time,
                      a.signup_deadline,
                      a.max_capacity,
                      a.status,
                      c.club_name,
                      v.venue_name,
                      COALESCE(r.confirmed_count, 0) AS confirmed_count,
                      COALESCE(r.waiting_count, 0) AS waiting_count
                    FROM activity a
                    JOIN club c ON c.club_id = a.club_id
                    JOIN venue v ON v.venue_id = a.venue_id
                    LEFT JOIN (
                      SELECT
                        activity_id,
                        COUNT(CASE WHEN reg_status = 'confirmed' THEN 1 END) AS confirmed_count,
                        COUNT(CASE WHEN reg_status = 'waiting' THEN 1 END) AS waiting_count
                      FROM activity_registration
                      GROUP BY activity_id
                    ) r ON r.activity_id = a.activity_id
                    WHERE a.activity_id = %s
                    """,
                    (activity_id,),
                )
                item = cur.fetchone()

                reg_rows = []
                if item and g.current_user["role"] in ("admin", "club"):
                    cur.execute(
                        """
                        SELECT ar.reg_id, ar.student_id, s.real_name, ar.reg_status, ar.checkin_status, ar.queue_no
                        FROM activity_registration ar
                        JOIN student s ON s.student_id = ar.student_id
                        WHERE ar.activity_id = %s
                        ORDER BY ar.reg_id DESC
                        """,
                        (activity_id,),
                    )
                    reg_rows = cur.fetchall()

        if not item:
            flash("活动不存在。", "error")
            return redirect(url_for("activities"))

        allowed_to_manage = can_manage_activity(g.current_user, item)
        if g.current_user["role"] == "club" and not allowed_to_manage:
            flash("你只能查看本社团活动。", "error")
            return redirect(url_for("activities"))

        return render_template("activity_detail.html", activity=item, regs=reg_rows, can_manage=allowed_to_manage)

    @app.route("/activity/register/<int:activity_id>", methods=["POST"])
    @role_required("student")
    def register_activity(activity_id):
        student_id = g.current_user.get("student_id")
        if not student_id:
            flash("当前账号不是学生，无法报名。", "error")
            return redirect(url_for("activity_detail", activity_id=activity_id))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "INSERT INTO activity_registration(activity_id, student_id) VALUES (%s, %s)",
                        (activity_id, int(student_id)),
                    )
                conn.commit()
                flash("报名提交成功，系统已自动判断是否候补。", "success")
            except Exception as exc:
                conn.rollback()
                flash(_friendly_register_error(exc), "error")

        return redirect(url_for("activity_detail", activity_id=activity_id))

    @app.route("/activity/finish/<int:activity_id>", methods=["POST"])
    @role_required("admin", "club")
    def finish_activity(activity_id):
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT activity_id, club_id FROM activity WHERE activity_id = %s", (activity_id,))
                row = cur.fetchone()
        if not row:
            flash("活动不存在。", "error")
            return redirect(url_for("activities"))
        if not can_manage_activity(g.current_user, row):
            flash("你没有权限结算该活动。", "error")
            return redirect(url_for("activities"))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("CALL sp_finish_activity(%s)", (activity_id,))
                conn.commit()
                flash("活动结算成功。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"活动结算失败：{exc}", "error")

        return redirect(url_for("activities"))

    @app.route("/activity/delete/<int:activity_id>", methods=["POST"])
    @role_required("admin", "club")
    def delete_activity(activity_id):
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT activity_id, club_id FROM activity WHERE activity_id = %s", (activity_id,))
                row = cur.fetchone()
        if not row:
            flash("活动不存在。", "error")
            return redirect(url_for("activities"))
        if not can_manage_activity(g.current_user, row):
            flash("你没有权限删除该活动。", "error")
            return redirect(url_for("activities"))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("CALL sp_delete_cancelled_activity(%s)", (activity_id,))
                conn.commit()
                flash("活动删除成功。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"活动删除失败：{exc}", "error")

        return redirect(url_for("activities"))

    @app.route("/activity/manage")
    @role_required("admin", "club")
    def activity_manage():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT venue_id, venue_name FROM venue ORDER BY venue_name")
                venues = cur.fetchall()

                query = """
                  SELECT a.activity_id, a.club_id, c.club_name, v.venue_name, a.title, a.status,
                         a.start_time, a.end_time, a.signup_deadline, a.max_capacity
                  FROM activity a
                  JOIN club c ON c.club_id = a.club_id
                  JOIN venue v ON v.venue_id = a.venue_id
                  WHERE 1=1
                """
                params = []
                if g.current_user["role"] == "club":
                    query += " AND a.club_id = %s"
                    params.append(g.current_user["club_id"])
                query += " ORDER BY a.activity_id DESC"
                cur.execute(query, params)
                items = cur.fetchall()

                clubs = []
                if g.current_user["role"] == "admin":
                    cur.execute("SELECT club_id, club_name FROM club ORDER BY club_name")
                    clubs = cur.fetchall()

        return render_template(
            "activity_manage.html",
            activities=items,
            venues=venues,
            clubs=clubs,
            activity_status=app.config["ACTIVITY_STATUS"],
        )

    @app.route("/activity/create", methods=["POST"])
    @role_required("admin", "club")
    def activity_create():
        title = request.form.get("title", "").strip()
        category = request.form.get("category", "").strip() or None
        venue_id = request.form.get("venue_id", "").strip()
        start_time = request.form.get("start_time", "").strip()
        end_time = request.form.get("end_time", "").strip()
        signup_deadline = request.form.get("signup_deadline", "").strip()
        max_capacity = request.form.get("max_capacity", "").strip()
        description = request.form.get("description", "").strip() or None

        if not title or not venue_id.isdigit() or not max_capacity.isdigit():
            flash("请完整填写活动标题、场地和人数上限。", "error")
            return redirect(url_for("activity_manage"))

        club_id = g.current_user["club_id"]
        if g.current_user["role"] == "admin":
            selected = request.form.get("club_id", "").strip()
            if not selected.isdigit():
                flash("管理员创建活动时必须选择社团。", "error")
                return redirect(url_for("activity_manage"))
            club_id = int(selected)

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO activity(
                          club_id, venue_id, title, category, start_time, end_time,
                          signup_deadline, max_capacity, status, description
                        ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'draft',%s)
                        """,
                        (
                            club_id,
                            int(venue_id),
                            title,
                            category,
                            start_time,
                            end_time,
                            signup_deadline,
                            int(max_capacity),
                            description,
                        ),
                    )
                conn.commit()
                flash("活动创建成功，当前状态为 draft。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"活动创建失败：{exc}", "error")

        return redirect(url_for("activity_manage"))

    @app.route("/activity/update/<int:activity_id>", methods=["POST"])
    @role_required("admin", "club")
    def activity_update(activity_id):
        title = request.form.get("title", "").strip()
        category = request.form.get("category", "").strip() or None
        venue_id = request.form.get("venue_id", "").strip()
        start_time = request.form.get("start_time", "").strip()
        end_time = request.form.get("end_time", "").strip()
        signup_deadline = request.form.get("signup_deadline", "").strip()
        max_capacity = request.form.get("max_capacity", "").strip()
        description = request.form.get("description", "").strip() or None

        if not title or not venue_id.isdigit() or not max_capacity.isdigit():
            flash("请完整填写更新信息。", "error")
            return redirect(url_for("activity_detail", activity_id=activity_id))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT activity_id, club_id FROM activity WHERE activity_id = %s", (activity_id,))
                    row = cur.fetchone()
                    if not row:
                        flash("活动不存在。", "error")
                        return redirect(url_for("activity_manage"))
                    if not can_manage_activity(g.current_user, row):
                        flash("你没有权限修改该活动。", "error")
                        return redirect(url_for("activities"))

                    cur.execute(
                        """
                        UPDATE activity
                        SET title=%s, category=%s, venue_id=%s, start_time=%s, end_time=%s,
                            signup_deadline=%s, max_capacity=%s, description=%s
                        WHERE activity_id=%s
                        """,
                        (
                            title,
                            category,
                            int(venue_id),
                            start_time,
                            end_time,
                            signup_deadline,
                            int(max_capacity),
                            description,
                            activity_id,
                        ),
                    )
                conn.commit()
                flash("活动信息更新成功。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"活动更新失败：{exc}", "error")

        return redirect(url_for("activity_detail", activity_id=activity_id))

    @app.route("/activity/status/<int:activity_id>", methods=["POST"])
    @role_required("admin", "club")
    def activity_change_status(activity_id):
        status = request.form.get("status", "").strip()
        if status not in app.config["ACTIVITY_STATUS"]:
            flash("非法状态。", "error")
            return redirect(url_for("activity_manage"))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT activity_id, club_id FROM activity WHERE activity_id = %s", (activity_id,))
                    row = cur.fetchone()
                    if not row:
                        flash("活动不存在。", "error")
                        return redirect(url_for("activity_manage"))
                    if not can_manage_activity(g.current_user, row):
                        flash("你没有权限修改该活动状态。", "error")
                        return redirect(url_for("activities"))

                    cur.execute("UPDATE activity SET status=%s WHERE activity_id=%s", (status, activity_id))
                conn.commit()
                flash(f"活动状态已更新为 {status}。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"状态更新失败：{exc}", "error")

        return redirect(url_for("activity_manage"))

    @app.route("/checkin/<int:reg_id>", methods=["POST"])
    @role_required("admin", "club")
    def checkin(reg_id):
        return _do_checkin(reg_id, "checked")

    @app.route("/absent/<int:reg_id>", methods=["POST"])
    @role_required("admin", "club")
    def absent(reg_id):
        return _do_checkin(reg_id, "absent")

    def _do_checkin(reg_id, status):
        # Keep check-in write and registration status update in one transaction.
        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        SELECT ar.reg_id, ar.activity_id, a.club_id, ar.reg_status, ar.checkin_status
                        FROM activity_registration ar
                        JOIN activity a ON a.activity_id = ar.activity_id
                        WHERE ar.reg_id = %s
                        """,
                        (reg_id,),
                    )
                    row = cur.fetchone()
                    if not row:
                        flash("报名记录不存在。", "error")
                        return redirect(url_for("activities"))
                    if not can_manage_activity(g.current_user, row):
                        flash("你没有权限操作该签到记录。", "error")
                        return redirect(url_for("activities"))
                    if row["reg_status"] != "confirmed":
                        flash("候补用户不可签到/标记缺席，请先转正为 confirmed。", "error")
                        return redirect(url_for("activity_detail", activity_id=row["activity_id"]))

                    cur.execute(
                        "UPDATE activity_registration SET checkin_status=%s WHERE reg_id=%s",
                        (status, reg_id),
                    )
                    cur.execute("SELECT checkin_id FROM checkin WHERE reg_id=%s", (reg_id,))
                    existing = cur.fetchone()
                    if existing:
                        cur.execute(
                            "UPDATE checkin SET checkin_time=NOW(), operator_id=%s, status=%s WHERE reg_id=%s",
                            (g.current_user["user_id"], status, reg_id),
                        )
                    else:
                        cur.execute(
                            "INSERT INTO checkin(reg_id, operator_id, status) VALUES (%s, %s, %s)",
                            (reg_id, g.current_user["user_id"], status),
                        )
                conn.commit()
                flash("签到状态更新成功。", "success")
                return redirect(url_for("activity_detail", activity_id=row["activity_id"]))
            except Exception as exc:
                conn.rollback()
                flash(f"签到更新失败：{exc}", "error")
                return redirect(url_for("activities"))
