import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("publish", Path(__file__).resolve().parents[1] / "scripts/publish.py")
publish = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publish)


class PublishingTests(unittest.TestCase):
    def config(self):
        return {"PREVIEWER_PLUGIN_ID": "123", "ROBLOX_CREATOR_ID": "42", "ROBLOX_CREATOR_TYPE": "Group", "PUBLISH_UNIVERSE_ID": "10", "PUBLISH_PLACE_ID": "20"}

    def test_missing_id(self):
        with self.assertRaises(ValueError):
            publish.configuration("organizer", self.config())

    def test_script_injection_rejected(self):
        env = self.config()
        env["PREVIEWER_PLUGIN_ID"] = '123); error("injected")'
        with self.assertRaises(ValueError):
            publish.configuration("previewer", env)

    def test_source_replacements(self):
        source = publish.engine_script(publish.configuration("previewer", self.config()))
        self.assertNotIn("__ASSET_ID__", source)
        self.assertIn('tonumber("123")', source)
        self.assertIn('local creatorType = "Group"', source)
        self.assertIn("CreateAssetVersionAsync", source)

    def test_result_verification(self):
        task = {"path": "universes/10/places/20/luau-execution-sessions/session/tasks/task", "state": "COMPLETE", "output": {"results": ["AssetToolsPublished:123:7"]}}
        self.assertEqual(publish.wait_for_task(None, task, "10", "123"), "7")
        task["output"]["results"] = ["AssetToolsPublished:456:7"]
        with self.assertRaises(RuntimeError):
            publish.wait_for_task(None, task, "10", "123")

    def test_queued_task_is_polled(self):
        class Client:
            def request(self, method, url):
                return {"state": "COMPLETE", "output": {"results": ["AssetToolsPublished:123:8"]}}
        task = {"path": "universes/10/places/20/luau-execution-sessions/s/tasks/t", "state": "QUEUED"}
        with patch.object(publish.time, "sleep"):
            self.assertEqual(publish.wait_for_task(Client(), task, "10", "123"), "8")

    def test_failed_task_rejected(self):
        task = {"path": "universes/10/places/20/luau-execution-sessions/s/tasks/t", "state": "FAILED", "error": {"message": "permission denied"}}
        with self.assertRaises(RuntimeError):
            publish.wait_for_task(None, task, "10", "123")

    def test_resource_paths_are_confined(self):
        for path in ("https://example.com", "universes/11/tasks/t", "universes/10/../../x"):
            with self.assertRaises(ValueError):
                publish.resource_url(path, "10")


if __name__ == "__main__":
    unittest.main()
