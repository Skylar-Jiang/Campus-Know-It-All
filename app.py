from flask import Flask

from config import Config
from core.auth import init_auth_hooks
from routes.activity_routes import register_activity_routes
from routes.auth_routes import register_auth_routes
from routes.borrow_routes import register_borrow_routes
from routes.community_routes import register_community_routes
from routes.competition_routes import register_competition_routes
from routes.home_routes import register_home_routes
from routes.stats_routes import register_stats_routes
from routes.trade_routes import register_trade_routes


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    app.config["ACTIVITY_STATUS"] = ["draft", "published", "ongoing", "finished", "cancelled"]
    app.config["ORDER_STATUS"] = ["pending", "approved", "borrowed", "returned", "overdue"]
    app.config["COMPETITION_STATUS"] = ["draft", "published", "archived"]
    app.config["ACTIVITY_CATEGORIES"] = [
        "志愿活动",
        "音乐会",
        "讲座",
        "培训",
        "社团会议",
        "体育活动",
        "文化活动",
        "公益实践",
    ]
    app.config["COMPETITION_CATEGORIES"] = [
        "基础学科",
        "数学",
        "物理",
        "化学",
        "生命科学",
        "文学",
        "英语",
        "计算机",
        "创新创业",
        "艺术设计",
        "综合能力",
    ]

    # Hook user/session context and template globals.
    init_auth_hooks(app)

    # Register business routes by module.
    register_auth_routes(app)
    register_home_routes(app)
    register_activity_routes(app)
    register_competition_routes(app)
    register_borrow_routes(app)
    register_trade_routes(app)
    register_community_routes(app)
    register_stats_routes(app)

    return app


app = create_app()


if __name__ == "__main__":
    app.run(debug=True, port=5001)
