import pathlib
import unittest


class IOSCITestSeparationTests(unittest.TestCase):
    def test_app_failures_stop_before_the_ui_suite(self):
        workflow = pathlib.Path(".github/workflows/ios-ci.yml").read_text(
            encoding="utf-8"
        )

        app_step = workflow.index("- name: Test CangJie App on iPad Simulator")
        ui_step = workflow.index("- name: Test CangJie UI on iPad Simulator")
        probe_step = workflow.index(
            "- name: Test Keychain Isolation Probe on iPad Simulator"
        )

        self.assertLess(app_step, ui_step)
        self.assertLess(ui_step, probe_step)
        self.assertIn("-skip-testing:CangJieUITests", workflow[app_step:ui_step])
        self.assertIn("-only-testing:CangJieUITests", workflow[ui_step:probe_step])
        self.assertIn("TestResults/CangJieUI.xcresult", workflow)


if __name__ == "__main__":
    unittest.main()
