from flask import flash, g, redirect, render_template, request, session, url_for

from core.auth import login_required
from core.db import get_db_connection


def register_auth_routes(app):
    @app.route("/")
    def index():
        if not g.current_user:
            return redirect(url_for("login"))
        return redirect(url_for("home_dashboard"))

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "POST":
            username = request.form.get("username", "").strip()
            password = request.form.get("password", "").strip()

            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT user_id, username, role FROM user_account WHERE username = %s AND password = %s",
                        (username, password),
                    )
                    user = cur.fetchone()

            if not user:
                flash("用户名或密码错误。", "error")
                return render_template("login.html", active_tab="login")

            session["user_id"] = user["user_id"]
            next_url = request.args.get("next")
            flash(f"欢迎回来，{user['username']}。", "success")
            return redirect(next_url or url_for("home_dashboard"))

        return render_template("login.html", active_tab="login")

    @app.route("/register", methods=["POST"])
    def register():
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "").strip()
        role = request.form.get("role", "student").strip()
        phone = request.form.get("phone", "").strip() or None

        student_no = request.form.get("student_no", "").strip()
        real_name = request.form.get("real_name", "").strip()
        grade = request.form.get("grade", "").strip() or None
        major = request.form.get("major", "").strip() or None

        if not username or not password:
            flash("请填写用户名和密码。", "error")
            return render_template("login.html", active_tab="register")

        if role not in ("student", "club"):
            flash("注册角色仅支持 student 或 club。", "error")
            return render_template("login.html", active_tab="register")

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT user_id FROM user_account WHERE username=%s", (username,))
                    if cur.fetchone():
                        flash("用户名已存在，请更换。", "error")
                        return render_template("login.html", active_tab="register")

                    cur.execute(
                        "INSERT INTO user_account(username, password, role, phone) VALUES (%s, %s, %s, %s)",
                        (username, password, role, phone),
                    )
                    new_user_id = cur.lastrowid

                    if role == "student":
                        if not student_no or not real_name:
                            conn.rollback()
                            flash("学生注册需要 student_no 和 real_name。", "error")
                            return render_template("login.html", active_tab="register")
                        cur.execute(
                            """
                            INSERT INTO student(user_id, student_no, real_name, grade, major)
                            VALUES (%s, %s, %s, %s, %s)
                            """,
                            (new_user_id, student_no, real_name, grade, major),
                        )

                conn.commit()
                flash("注册成功，请使用新账号登录。", "success")
                return render_template("login.html", active_tab="login")
            except Exception as exc:
                conn.rollback()
                flash(f"注册失败：{exc}", "error")
                return render_template("login.html", active_tab="register")

    @app.route("/logout", methods=["POST"])
    @login_required
    def logout():
        session.clear()
        flash("已退出登录。", "success")
        return redirect(url_for("login"))
