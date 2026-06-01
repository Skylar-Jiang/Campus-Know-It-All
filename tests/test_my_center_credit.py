import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class MyCenterCreditTest(unittest.TestCase):
    def test_student_my_center_loads_and_displays_credit_fields(self):
        route = (ROOT / "routes" / "home_routes.py").read_text(encoding="utf-8")
        template = (ROOT / "templates" / "home" / "my_center.html").read_text(encoding="utf-8")

        self.assertIn("points, violation_count, credit_score", route)
        self.assertIn("student_profile", route)
        self.assertIn("信用分", template)
        self.assertIn("积分", template)
        self.assertIn("违规次数", template)
        self.assertIn("data.student_profile.credit_score", template)
        self.assertIn("data.student_profile.points", template)
        self.assertIn("data.student_profile.violation_count", template)


if __name__ == "__main__":
    unittest.main()
