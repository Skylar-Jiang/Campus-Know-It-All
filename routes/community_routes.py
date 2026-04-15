from flask import flash, g, redirect, render_template, request, url_for

from core.auth import login_required
from core.db import get_db_connection


def register_community_routes(app):
    def _has_post_like_table(cur):
        cur.execute("SHOW TABLES LIKE 'post_like'")
        return cur.fetchone() is not None

    @app.route('/community/posts')
    @login_required
    def community_posts():
        keyword = request.args.get('keyword', '').strip()
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                like_ready = _has_post_like_table(cur)
                sql = """
                SELECT p.post_id, p.title, p.status, p.create_time,
                       u.username AS author_name, pc.category_name,
                       SUBSTRING(p.content, 1, 80) AS content_preview,
                       COALESCE(c.comment_count, 0) AS comment_count,
                       {like_expr} AS like_count
                FROM post p
                JOIN user_account u ON u.user_id = p.author_user_id
                JOIN post_category pc ON pc.category_id = p.category_id
                LEFT JOIN (
                    SELECT post_id, COUNT(*) AS comment_count
                    FROM post_comment
                    GROUP BY post_id
                ) c ON c.post_id = p.post_id
                {like_join}
                WHERE p.status = 'visible'
                """.format(
                    like_expr="COALESCE(l.like_count, 0)" if like_ready else "0",
                    like_join="""
                LEFT JOIN (
                    SELECT post_id, COUNT(*) AS like_count
                    FROM post_like
                    GROUP BY post_id
                ) l ON l.post_id = p.post_id
                """
                    if like_ready
                    else "",
                )

                params = []
                if keyword:
                    sql += ' AND p.title LIKE %s'
                    params.append(f'%{keyword}%')
                sql += ' ORDER BY p.create_time DESC, p.post_id DESC'

                cur.execute(sql, params)
                rows = cur.fetchall()

        if not rows and keyword:
            flash('没有匹配的帖子，已为你保留筛选条件。', 'success')

        return render_template('community/post_list.html', posts=rows, keyword=keyword, like_ready=like_ready)

    @app.route('/community/post/<int:post_id>')
    @login_required
    def community_post_detail(post_id):
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                like_ready = _has_post_like_table(cur)
                cur.execute(
                    """
                    SELECT p.post_id, p.author_user_id, p.title, p.content, p.create_time, p.status,
                           u.username AS author_name, pc.category_name,
                           COALESCE(c.comment_count, 0) AS comment_count,
                           {like_expr} AS like_count
                    FROM post p
                    JOIN user_account u ON u.user_id = p.author_user_id
                    JOIN post_category pc ON pc.category_id = p.category_id
                    LEFT JOIN (
                        SELECT post_id, COUNT(*) AS comment_count
                        FROM post_comment
                        GROUP BY post_id
                    ) c ON c.post_id = p.post_id
                    {like_join}
                    WHERE p.post_id = %s
                    """.format(
                        like_expr="COALESCE(l.like_count, 0)" if like_ready else "0",
                        like_join="""
                    LEFT JOIN (
                        SELECT post_id, COUNT(*) AS like_count
                        FROM post_like
                        GROUP BY post_id
                    ) l ON l.post_id = p.post_id
                    """
                        if like_ready
                        else "",
                    ),
                    (post_id,),
                )
                post = cur.fetchone()
                user_liked = False
                if post:
                    if like_ready:
                        cur.execute(
                            "SELECT 1 FROM post_like WHERE post_id=%s AND user_id=%s",
                            (post_id, g.current_user['user_id']),
                        )
                        user_liked = cur.fetchone() is not None

                    cur.execute(
                        """
                        SELECT c.comment_id, c.content, c.create_time, u.username
                        FROM post_comment c
                        JOIN user_account u ON u.user_id = c.user_id
                        WHERE c.post_id = %s
                        ORDER BY c.create_time ASC
                        """,
                        (post_id,),
                    )
                    comments = cur.fetchall()
                else:
                    comments = []

        if not post:
            flash('帖子不存在。', 'error')
            return redirect(url_for('community_posts'))

        return render_template(
            'community/post_detail.html',
            post=post,
            comments=comments,
            user_liked=user_liked,
            like_ready=like_ready,
        )

    @app.route('/community/post/like/<int:post_id>', methods=['POST'])
    @login_required
    def community_post_like(post_id):
        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    if not _has_post_like_table(cur):
                        flash('点赞功能尚未启用，请先执行 sql/09_add_post_like.sql。', 'error')
                        return redirect(url_for('community_post_detail', post_id=post_id))

                    cur.execute("SELECT post_id FROM post WHERE post_id=%s", (post_id,))
                    if not cur.fetchone():
                        flash('帖子不存在。', 'error')
                        return redirect(url_for('community_posts'))

                    cur.execute(
                        "SELECT like_id FROM post_like WHERE post_id=%s AND user_id=%s",
                        (post_id, g.current_user['user_id']),
                    )
                    row = cur.fetchone()
                    if row:
                        cur.execute("DELETE FROM post_like WHERE like_id=%s", (row['like_id'],))
                        flash('已取消点赞。', 'success')
                    else:
                        cur.execute(
                            "INSERT INTO post_like(post_id, user_id) VALUES (%s, %s)",
                            (post_id, g.current_user['user_id']),
                        )
                        flash('点赞成功。', 'success')
                conn.commit()
            except Exception as exc:
                conn.rollback()
                flash(f'点赞操作失败：{exc}', 'error')

        return redirect(url_for('community_post_detail', post_id=post_id))

    @app.route('/community/post/create', methods=['GET', 'POST'])
    @login_required
    def community_post_create():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT category_id, category_name FROM post_category WHERE status='active' ORDER BY category_name")
                categories = cur.fetchall()

        if request.method == 'POST':
            title = request.form.get('title', '').strip()
            content = request.form.get('content', '').strip()
            category_id = request.form.get('category_id', '').strip()
            if not title or not content or not category_id.isdigit():
                flash('请填写完整帖子信息。', 'error')
                return render_template('community/post_create.html', categories=categories)

            with get_db_connection() as conn:
                try:
                    with conn.cursor() as cur:
                        cur.execute(
                            "INSERT INTO post(author_user_id, category_id, title, content, status) VALUES (%s, %s, %s, %s, 'visible')",
                            (g.current_user['user_id'], int(category_id), title, content),
                        )
                    conn.commit()
                    flash('发帖成功。', 'success')
                    return redirect(url_for('community_my_posts'))
                except Exception as exc:
                    conn.rollback()
                    flash(f'发帖失败：{exc}', 'error')

        return render_template('community/post_create.html', categories=categories)

    @app.route('/community/comment/create/<int:post_id>', methods=['POST'])
    @login_required
    def community_comment_create(post_id):
        content = request.form.get('content', '').strip()
        if not content:
            flash('评论内容不能为空。', 'error')
            return redirect(url_for('community_post_detail', post_id=post_id))

        with get_db_connection() as conn:
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT post_id FROM post WHERE post_id=%s", (post_id,))
                    if not cur.fetchone():
                        flash('帖子不存在。', 'error')
                        return redirect(url_for('community_posts'))
                    cur.execute(
                        "INSERT INTO post_comment(post_id, user_id, content) VALUES (%s, %s, %s)",
                        (post_id, g.current_user['user_id'], content),
                    )
                conn.commit()
                flash('评论成功。', 'success')
            except Exception as exc:
                conn.rollback()
                flash(f'评论失败：{exc}', 'error')

        return redirect(url_for('community_post_detail', post_id=post_id))

    @app.route('/community/my/posts')
    @login_required
    def community_my_posts():
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT p.post_id, p.title, p.status, p.create_time, pc.category_name
                    FROM post p
                    JOIN post_category pc ON pc.category_id = p.category_id
                    WHERE p.author_user_id = %s
                    ORDER BY p.create_time DESC
                    """,
                    (g.current_user['user_id'],),
                )
                rows = cur.fetchall()

        return render_template('community/my_posts.html', posts=rows)
