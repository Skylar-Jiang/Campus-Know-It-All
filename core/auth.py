from functools import wraps

from flask import current_app, flash, g, redirect, request, session, url_for

from core.db import get_db_connection


def login_required(view_func):
    @wraps(view_func)
    def wrapped(*args, **kwargs):
        if not g.current_user:
            flash("请先登录。", "error")
            return redirect(url_for("login", next=request.path))
        return view_func(*args, **kwargs)

    return wrapped


def role_required(*roles):
    def decorator(view_func):
        @wraps(view_func)
        def wrapped(*args, **kwargs):
            if not g.current_user:
                flash("请先登录。", "error")
                return redirect(url_for("login"))
            if g.current_user["role"] not in roles:
                flash("你没有权限执行该操作。", "error")
                return redirect(url_for("activities"))
            return view_func(*args, **kwargs)

        return wrapped

    return decorator


def can_manage_activity(user, activity):
    if user["role"] == "admin":
        return True
    if user["role"] == "club" and user.get("club_id") == activity["club_id"]:
        return True
    return False


def load_user(user_id):
    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT user_id, username, role, phone FROM user_account WHERE user_id = %s",
                (user_id,),
            )
            user = cur.fetchone()
            if not user:
                return None

            user["student_id"] = None
            user["club_id"] = None

            if user["role"] == "student":
                cur.execute("SELECT student_id FROM student WHERE user_id = %s", (user_id,))
                row = cur.fetchone()
                user["student_id"] = row["student_id"] if row else None

            if user["role"] == "club":
                cur.execute("SELECT club_id FROM club WHERE president_user_id = %s", (user_id,))
                row = cur.fetchone()
                user["club_id"] = row["club_id"] if row else None

            return user


def init_auth_hooks(app):
    @app.before_request
    def inject_user():
        user_id = session.get("user_id")
        g.current_user = load_user(user_id) if user_id else None
        if user_id and not g.current_user:
            session.clear()

    @app.context_processor
    def context_data():
        return {
            "current_user": g.current_user,
            "activity_status": current_app.config["ACTIVITY_STATUS"],
            "order_status": current_app.config["ORDER_STATUS"],
        }
