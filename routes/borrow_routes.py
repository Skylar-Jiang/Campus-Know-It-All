from datetime import datetime

from flask import flash, g, redirect, render_template, request, url_for

from core.auth import role_required
from core.db import get_db_connection


def register_borrow_routes(app):
    def _ensure_order_uid_column(cur):
        cur.execute("SHOW COLUMNS FROM borrow_order LIKE 'order_uid'")
        exists = cur.fetchone() is not None
        if not exists:
            cur.execute("ALTER TABLE borrow_order ADD COLUMN order_uid VARCHAR(32) NULL UNIQUE AFTER order_id")
            cur.execute(
                """
                UPDATE borrow_order
                SET order_uid = CONCAT('BOR-', DATE_FORMAT(apply_time, '%Y%m%d'), '-', LPAD(order_id, 6, '0'))
                WHERE order_uid IS NULL
                """
            )

    @app.route("/borrow")
    @role_required("admin", "club")
    def borrow_manage():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                _ensure_order_uid_column(cur)
                cur.execute(
                    """
                    SELECT order_id,
                           order_uid,
                           activity_id,
                           applicant_user_id,
                           apply_time,
                           expected_return_time, actual_return_time, order_status
                    FROM borrow_order
                    WHERE (%s = 'admin') OR (applicant_user_id = %s)
                    ORDER BY order_id DESC
                    """,
                    (g.current_user["role"], g.current_user["user_id"]),
                )
                orders = cur.fetchall()

                detail_target_orders = [
                    o for o in orders if o["order_status"] in ("pending", "approved", "borrowed", "overdue")
                ]

                cur.execute(
                    """
                    SELECT resource_id, item_name, category, total_qty, available_qty, unit, status
                    FROM resource_item
                    ORDER BY resource_id
                    """
                )
                resources = cur.fetchall()

                if g.current_user["role"] == "admin":
                    cur.execute("SELECT activity_id, title FROM activity ORDER BY activity_id DESC")
                    activities = cur.fetchall()
                else:
                    cur.execute(
                        "SELECT activity_id, title FROM activity WHERE club_id = %s ORDER BY activity_id DESC",
                        (g.current_user["club_id"],),
                    )
                    activities = cur.fetchall()

        return render_template(
            "borrow_manage.html",
            orders=orders,
            resources=resources,
            activities=activities,
            detail_target_orders=detail_target_orders,
        )

    @app.route("/borrow/create", methods=["POST"])
    @role_required("admin", "club")
    def borrow_create():
        activity_id = request.form.get("activity_id", "").strip()
        expected_return_time = request.form.get("expected_return_time", "").strip()
        status = request.form.get("order_status", "approved").strip()
        if not activity_id.isdigit() or status not in app.config["ORDER_STATUS"]:
            flash("借用单参数非法。", "error")
            return redirect(url_for("borrow_manage"))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    _ensure_order_uid_column(cur)
                    cur.execute(
                        """
                        INSERT INTO borrow_order(activity_id, applicant_user_id, expected_return_time, order_status)
                        VALUES (%s, %s, %s, %s)
                        """,
                        (int(activity_id), g.current_user["user_id"], expected_return_time, status),
                    )
                    new_order_id = cur.lastrowid
                    order_uid = f"BOR-{datetime.now():%Y%m%d}-{new_order_id:06d}"
                    cur.execute(
                        "UPDATE borrow_order SET order_uid=%s WHERE order_id=%s",
                        (order_uid, new_order_id),
                    )
                conn.commit()
                flash(f"借用单创建成功：{order_uid}", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"借用单创建失败：{exc}", "error")

        return redirect(url_for("borrow_manage"))

    @app.route("/borrow/detail/add", methods=["POST"])
    @role_required("admin", "club")
    def borrow_detail_add():
        order_ref = request.form.get("order_ref", "").strip()
        resource_id = request.form.get("resource_id", "").strip()
        borrow_qty = request.form.get("borrow_qty", "").strip()
        if not order_ref or not resource_id.isdigit() or not borrow_qty.isdigit():
            flash("明细参数非法。", "error")
            return redirect(url_for("borrow_manage"))

        resource_id = int(resource_id)
        borrow_qty = int(borrow_qty)

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    _ensure_order_uid_column(cur)
                    if order_ref.isdigit():
                        cur.execute(
                            "SELECT order_id, applicant_user_id FROM borrow_order WHERE order_id=%s",
                            (int(order_ref),),
                        )
                    else:
                        cur.execute(
                            "SELECT order_id, applicant_user_id FROM borrow_order WHERE order_uid=%s",
                            (order_ref,),
                        )
                    order = cur.fetchone()
                    if not order:
                        flash("借用单不存在。", "error")
                        return redirect(url_for("borrow_manage"))
                    order_id = order["order_id"]
                    if g.current_user["role"] != "admin" and order["applicant_user_id"] != g.current_user["user_id"]:
                        flash("你没有权限修改该借用单。", "error")
                        return redirect(url_for("borrow_manage"))

                    # Lock stock row before checking quantity to avoid race updates.
                    cur.execute(
                        "SELECT available_qty FROM resource_item WHERE resource_id=%s FOR UPDATE",
                        (resource_id,),
                    )
                    resource = cur.fetchone()
                    if not resource:
                        flash("物资不存在。", "error")
                        return redirect(url_for("borrow_manage"))
                    if resource["available_qty"] < borrow_qty:
                        flash("库存不足，无法借用。", "error")
                        return redirect(url_for("borrow_manage"))

                    cur.execute(
                        "INSERT INTO borrow_detail(order_id, resource_id, borrow_qty) VALUES (%s, %s, %s)",
                        (order_id, resource_id, borrow_qty),
                    )
                    cur.execute(
                        "UPDATE resource_item SET available_qty = available_qty - %s WHERE resource_id = %s",
                        (borrow_qty, resource_id),
                    )
                    cur.execute("UPDATE borrow_order SET order_status='borrowed' WHERE order_id=%s", (order_id,))
                conn.commit()
                flash("借用明细添加成功。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"借用明细添加失败：{exc}", "error")

        return redirect(url_for("borrow_manage"))

    @app.route("/borrow/return/<int:order_id>", methods=["POST"])
    @role_required("admin", "club")
    def borrow_return(order_id):
        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT applicant_user_id, order_status FROM borrow_order WHERE order_id=%s",
                        (order_id,),
                    )
                    order = cur.fetchone()
                    if not order:
                        flash("借用单不存在。", "error")
                        return redirect(url_for("borrow_manage"))
                    if g.current_user["role"] != "admin" and order["applicant_user_id"] != g.current_user["user_id"]:
                        flash("你没有权限归还该借用单。", "error")
                        return redirect(url_for("borrow_manage"))
                    if order["order_status"] not in ("borrowed", "overdue"):
                        flash("当前借用单状态不可归还，请先确认借用明细。", "error")
                        return redirect(url_for("borrow_manage"))

                    cur.execute(
                        "SELECT detail_id, resource_id, borrow_qty, returned_qty FROM borrow_detail WHERE order_id=%s",
                        (order_id,),
                    )
                    details = cur.fetchall()
                    if not details:
                        flash("该借用单无明细，无法归还。", "error")
                        return redirect(url_for("borrow_manage"))

                    for d in details:
                        to_return = d["borrow_qty"] - d["returned_qty"]
                        if to_return > 0:
                            cur.execute(
                                "UPDATE borrow_detail SET returned_qty = borrow_qty WHERE detail_id=%s",
                                (d["detail_id"],),
                            )
                            cur.execute(
                                "UPDATE resource_item SET available_qty = available_qty + %s WHERE resource_id=%s",
                                (to_return, d["resource_id"]),
                            )

                    cur.execute(
                        "UPDATE borrow_order SET order_status='returned', actual_return_time=NOW() WHERE order_id=%s",
                        (order_id,),
                    )
                conn.commit()
                flash("归还成功，库存已回补。", "success")
            except Exception as exc:
                conn.rollback()
                flash(f"归还失败：{exc}", "error")

        return redirect(url_for("borrow_manage"))
