import unittest
from pathlib import Path

from app import create_app


ROOT = Path(__file__).resolve().parents[1]


class CompetitionFeatureTest(unittest.TestCase):
    def test_competition_routes_are_registered(self):
        app = create_app()
        endpoints = {rule.endpoint for rule in app.url_map.iter_rules()}

        self.assertIn("competitions", endpoints)
        self.assertIn("competition_detail", endpoints)
        self.assertIn("competition_manage", endpoints)
        self.assertIn("competition_create", endpoints)

    def test_competition_schema_has_official_information_fields(self):
        schema = (ROOT / "sql" / "02_create_tables.sql").read_text(encoding="utf-8")

        self.assertIn("CREATE TABLE competition", schema)
        self.assertIn("official_url", schema)
        self.assertIn("summary TEXT", schema)
        self.assertIn("CHECK (status IN ('draft', 'published', 'archived'))", schema)

    def test_competition_detail_has_official_link_but_no_signup_entry(self):
        template = (ROOT / "templates" / "competition_detail.html").read_text(encoding="utf-8")

        self.assertIn("official_url", template)
        self.assertIn("官方页面", template)
        self.assertNotIn("报名", template)

    def test_activity_and_competition_category_choices_are_configured(self):
        app = create_app()

        self.assertIn("志愿活动", app.config["ACTIVITY_CATEGORIES"])
        self.assertIn("音乐会", app.config["ACTIVITY_CATEGORIES"])
        self.assertIn("基础学科", app.config["COMPETITION_CATEGORIES"])
        self.assertIn("数学", app.config["COMPETITION_CATEGORIES"])
        self.assertIn("计算机", app.config["COMPETITION_CATEGORIES"])

    def test_home_dashboard_includes_competition_overview(self):
        route = (ROOT / "routes" / "home_routes.py").read_text(encoding="utf-8")
        template = (ROOT / "templates" / "home" / "dashboard.html").read_text(encoding="utf-8")

        self.assertIn("latest_competitions", route)
        self.assertIn("latest_competitions=latest_competitions", route)
        self.assertIn("最新竞赛", template)
        self.assertIn("latest_competitions", template)
        self.assertIn("competition_detail", template)


if __name__ == "__main__":
    unittest.main()
