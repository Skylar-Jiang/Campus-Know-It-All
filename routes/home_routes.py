from flask import g, render_template

from core.auth import login_required
from core.db import get_db_connection


def register_home_routes(app):
    @app.route('/home')
    @login_required
    def home_dashboard():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT activity_id, title, status, start_time FROM activity ORDER BY activity_id DESC LIMIT 5")
                latest_activities = cur.fetchall()

                cur.execute(
                    """
                    SELECT product_id, title, status, publish_time
                    FROM product
                    ORDER BY product_id DESC
                    LIMIT 5
                    """
                )
                latest_products = cur.fetchall()

                cur.execute("SELECT post_id, title, status, create_time FROM post ORDER BY post_id DESC LIMIT 5")
                latest_posts = cur.fetchall()

        return render_template(
            'home/dashboard.html',
            latest_activities=latest_activities,
            latest_products=latest_products,
            latest_posts=latest_posts,
            user=g.current_user,
        )

    @app.route('/my')
    @login_required
    def my_center():
        user = g.current_user
        data = {
            'club_activities': [],
            'club_recent_regs': [],
            'student_regs': [],
            'student_recent_orders': [],
            'student_recent_posts': [],
            'summary': {
                'activity_count': 0,
                'reg_count': 0,
                'checked_count': 0,
                'trade_count': 0,
                'post_count': 0,
            },
        }

        with get_db_connection() as conn:
            with conn.cursor() as cur:
                if user['role'] == 'club' and user.get('club_id'):
                    cur.execute(
                        """
                        SELECT a.activity_id, a.title, a.status, a.start_time, a.signup_deadline,
                               a.max_capacity,
                               COALESCE(r.reg_count, 0) AS reg_count,
                               COALESCE(r.waiting_count, 0) AS waiting_count,
                               COALESCE(r.checked_count, 0) AS checked_count,
                               COALESCE(r.absent_count, 0) AS absent_count
                        FROM activity a
                        LEFT JOIN (
                            SELECT activity_id,
                                   COUNT(*) AS reg_count,
                                   COUNT(CASE WHEN reg_status='waiting' THEN 1 END) AS waiting_count,
                                   COUNT(CASE WHEN checkin_status='checked' THEN 1 END) AS checked_count,
                                   COUNT(CASE WHEN checkin_status='absent' THEN 1 END) AS absent_count
                            FROM activity_registration
                            GROUP BY activity_id
                        ) r ON r.activity_id = a.activity_id
                        WHERE a.club_id = %s
                        ORDER BY a.activity_id DESC
                        LIMIT 12
                        """,
                        (user['club_id'],),
                    )
                    data['club_activities'] = cur.fetchall()

                    cur.execute(
                        """
                        SELECT ar.reg_id, ar.activity_id, a.title, s.real_name,
                               ar.reg_status, ar.checkin_status, ar.register_time
                        FROM activity_registration ar
                        JOIN activity a ON a.activity_id = ar.activity_id
                        JOIN student s ON s.student_id = ar.student_id
                        WHERE a.club_id = %s
                        ORDER BY ar.reg_id DESC
                        LIMIT 12
                        """,
                        (user['club_id'],),
                    )
                    data['club_recent_regs'] = cur.fetchall()

                    data['summary']['activity_count'] = len(data['club_activities'])
                    data['summary']['reg_count'] = sum(x['reg_count'] for x in data['club_activities'])
                    data['summary']['checked_count'] = sum(x['checked_count'] for x in data['club_activities'])

                elif user['role'] == 'student' and user.get('student_id'):
                    cur.execute(
                        """
                        SELECT ar.reg_id, ar.activity_id, a.title, c.club_name,
                               ar.reg_status, ar.checkin_status, ar.register_time
                        FROM activity_registration ar
                        JOIN activity a ON a.activity_id = ar.activity_id
                        JOIN club c ON c.club_id = a.club_id
                        WHERE ar.student_id = %s
                        ORDER BY ar.reg_id DESC
                        LIMIT 12
                        """,
                        (user['student_id'],),
                    )
                    data['student_regs'] = cur.fetchall()

                    cur.execute(
                        """
                        SELECT o.order_id, o.order_status, o.create_time,
                               p.title, p.price, su.username AS seller_name
                        FROM trade_order o
                        JOIN product p ON p.product_id = o.product_id
                        JOIN user_account su ON su.user_id = o.seller_user_id
                        WHERE o.buyer_user_id = %s OR o.seller_user_id = %s
                        ORDER BY o.order_id DESC
                        LIMIT 10
                        """,
                        (user['user_id'], user['user_id']),
                    )
                    data['student_recent_orders'] = cur.fetchall()

                    cur.execute(
                        """
                        SELECT post_id, title, status, create_time
                        FROM post
                        WHERE author_user_id = %s
                        ORDER BY post_id DESC
                        LIMIT 8
                        """,
                        (user['user_id'],),
                    )
                    data['student_recent_posts'] = cur.fetchall()

                    data['summary']['reg_count'] = len(data['student_regs'])
                    data['summary']['checked_count'] = sum(1 for x in data['student_regs'] if x['checkin_status'] == 'checked')
                    data['summary']['trade_count'] = len(data['student_recent_orders'])
                    data['summary']['post_count'] = len(data['student_recent_posts'])

        return render_template('home/my_center.html', user=user, data=data)
