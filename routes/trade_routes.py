from flask import flash, g, redirect, render_template, request, url_for

from core.auth import login_required
from core.db import get_db_connection


def register_trade_routes(app):
    @app.route('/trade/products')
    @login_required
    def trade_products():
        keyword = request.args.get('keyword', '').strip()
        status = request.args.get('status', '').strip()

        sql = """
        SELECT p.product_id, p.title, p.price, p.status, p.publish_time,
               u.username AS seller_name, pc.category_name
        FROM product p
        JOIN user_account u ON u.user_id = p.seller_user_id
        JOIN product_category pc ON pc.category_id = p.category_id
        WHERE 1=1
        """
        params = []
        if keyword:
            sql += ' AND p.title LIKE %s'
            params.append(f'%{keyword}%')
        if status:
            sql += ' AND p.status = %s'
            params.append(status)
        sql += ' ORDER BY p.publish_time DESC, p.product_id DESC'

        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()

        return render_template('trade/product_list.html', products=rows, keyword=keyword, status=status)

    @app.route('/trade/product/<int:product_id>')
    @login_required
    def trade_product_detail(product_id):
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT p.product_id, p.seller_user_id, p.category_id, p.title, p.description,
                           p.price, p.status, p.publish_time,
                           u.username AS seller_name, pc.category_name
                    FROM product p
                    JOIN user_account u ON u.user_id = p.seller_user_id
                    JOIN product_category pc ON pc.category_id = p.category_id
                    WHERE p.product_id = %s
                    """,
                    (product_id,),
                )
                item = cur.fetchone()

        if not item:
            flash('商品不存在。', 'error')
            return redirect(url_for('trade_products'))

        return render_template('trade/product_detail.html', product=item)

    @app.route('/trade/product/create', methods=['GET', 'POST'])
    @login_required
    def trade_product_create():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT category_id, category_name FROM product_category WHERE status='active' ORDER BY category_name")
                categories = cur.fetchall()

        if request.method == 'POST':
            title = request.form.get('title', '').strip()
            category_id = request.form.get('category_id', '').strip()
            price = request.form.get('price', '').strip()
            description = request.form.get('description', '').strip() or None

            if not title or not category_id.isdigit():
                flash('请完整填写商品标题和分类。', 'error')
                return render_template('trade/product_create.html', categories=categories)

            try:
                price_val = float(price)
            except Exception:
                flash('价格格式不正确。', 'error')
                return render_template('trade/product_create.html', categories=categories)

            with get_db_connection() as conn:
                try:
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            INSERT INTO product(seller_user_id, category_id, title, description, price, status)
                            VALUES (%s, %s, %s, %s, %s, 'on_sale')
                            """,
                            (g.current_user['user_id'], int(category_id), title, description, price_val),
                        )
                    conn.commit()
                    flash('商品发布成功。', 'success')
                    return redirect(url_for('trade_my_products'))
                except Exception as exc:
                    conn.rollback()
                    flash(f'商品发布失败：{exc}', 'error')

        return render_template('trade/product_create.html', categories=categories)

    @app.route('/trade/order/create/<int:product_id>', methods=['POST'])
    @login_required
    def trade_order_create(product_id):
        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    # Lock product row to avoid concurrent double-order.
                    cur.execute(
                        "SELECT product_id, seller_user_id, status FROM product WHERE product_id=%s FOR UPDATE",
                        (product_id,),
                    )
                    item = cur.fetchone()
                    if not item:
                        flash('商品不存在。', 'error')
                        return redirect(url_for('trade_products'))
                    if item['status'] != 'on_sale':
                        flash('商品当前不可下单。', 'error')
                        return redirect(url_for('trade_product_detail', product_id=product_id))
                    if item['seller_user_id'] == g.current_user['user_id']:
                        flash('不能购买自己发布的商品。', 'error')
                        return redirect(url_for('trade_product_detail', product_id=product_id))

                    cur.execute(
                        """
                        INSERT INTO trade_order(product_id, buyer_user_id, seller_user_id, order_status)
                        VALUES (%s, %s, %s, 'created')
                        """,
                        (product_id, g.current_user['user_id'], item['seller_user_id']),
                    )
                    cur.execute("UPDATE product SET status='locked' WHERE product_id=%s", (product_id,))
                conn.commit()
                flash('下单成功，已锁定该商品。', 'success')
            except Exception as exc:
                conn.rollback()
                flash(f'下单失败：{exc}', 'error')

        return redirect(url_for('trade_my_orders'))

    @app.route('/trade/order/status/<int:order_id>', methods=['POST'])
    @login_required
    def trade_order_status(order_id):
        new_status = request.form.get('order_status', '').strip()
        if new_status not in ('created', 'cancelled', 'completed'):
            flash('非法订单状态。', 'error')
            return redirect(url_for('trade_my_orders'))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT order_id, product_id, buyer_user_id, seller_user_id, order_status FROM trade_order WHERE order_id=%s",
                        (order_id,),
                    )
                    order = cur.fetchone()
                    if not order:
                        flash('订单不存在。', 'error')
                        return redirect(url_for('trade_my_orders'))
                    if g.current_user['user_id'] not in (order['buyer_user_id'], order['seller_user_id']):
                        flash('你没有权限修改该订单。', 'error')
                        return redirect(url_for('trade_my_orders'))

                    cur.execute(
                        "UPDATE trade_order SET order_status=%s, finish_time=IF(%s='completed', NOW(), finish_time) WHERE order_id=%s",
                        (new_status, new_status, order_id),
                    )
                    if new_status == 'cancelled':
                        cur.execute("UPDATE product SET status='on_sale' WHERE product_id=%s", (order['product_id'],))
                    if new_status == 'completed':
                        cur.execute("UPDATE product SET status='sold' WHERE product_id=%s", (order['product_id'],))
                conn.commit()
                flash('订单状态更新成功。', 'success')
            except Exception as exc:
                conn.rollback()
                flash(f'订单状态更新失败：{exc}', 'error')

        return redirect(url_for('trade_my_orders'))

    @app.route('/trade/my/products')
    @login_required
    def trade_my_products():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT p.product_id, p.title, p.price, p.status, p.publish_time, pc.category_name
                    FROM product p
                    JOIN product_category pc ON pc.category_id = p.category_id
                    WHERE p.seller_user_id = %s
                    ORDER BY p.publish_time DESC
                    """,
                    (g.current_user['user_id'],),
                )
                rows = cur.fetchall()

        return render_template('trade/my_products.html', products=rows)

    @app.route('/trade/my/orders')
    @login_required
    def trade_my_orders():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT o.order_id, o.order_status, o.create_time, o.finish_time,
                           p.product_id, p.title, p.price,
                           bu.username AS buyer_name, su.username AS seller_name
                    FROM trade_order o
                    JOIN product p ON p.product_id = o.product_id
                    JOIN user_account bu ON bu.user_id = o.buyer_user_id
                    JOIN user_account su ON su.user_id = o.seller_user_id
                    WHERE o.buyer_user_id = %s OR o.seller_user_id = %s
                    ORDER BY o.create_time DESC
                    """,
                    (g.current_user['user_id'], g.current_user['user_id']),
                )
                rows = cur.fetchall()

        return render_template('trade/my_orders.html', orders=rows)
