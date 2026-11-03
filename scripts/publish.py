"""Publish a checked plugin artifact through Open Cloud Luau execution (no cookies)."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://apis.roblox.com/cloud/v2/"
ROOT = Path(__file__).resolve().parent.parent


def positive_id(value: str, name: str) -> str:
    if not re.fullmatch(r"[1-9][0-9]{0,14}", value):
        raise ValueError(f"{name} must be a positive Roblox ID")
    return value


def configuration(plugin: str, env: dict[str, str]) -> dict[str, str]:
    prefix = plugin.upper()
    result = {
        "asset": positive_id(env.get(f"{prefix}_PLUGIN_ID", ""), f"{prefix}_PLUGIN_ID"),
        "creator": positive_id(env.get("ROBLOX_CREATOR_ID", ""), "ROBLOX_CREATOR_ID"),
        "universe": positive_id(env.get("PUBLISH_UNIVERSE_ID", ""), "PUBLISH_UNIVERSE_ID"),
        "place": positive_id(env.get("PUBLISH_PLACE_ID", ""), "PUBLISH_PLACE_ID"),
        "creator_type": env.get("ROBLOX_CREATOR_TYPE", "User"),
        "plugin_name": "Asset " + plugin.title(),
        "description": (
            "Preview selected Roblox assets with an adaptive, paginated Studio viewer."
            if plugin == "previewer" else
            "Organize Roblox assets with described tags, bounded attributes, and scoped queries."
        ),
    }
    if result["creator_type"] not in ("User", "Group"):
        raise ValueError("ROBLOX_CREATOR_TYPE must be User or Group")
    return result


def engine_script(config: dict[str, str]) -> str:
    source = (ROOT / "scripts/publish-engine.luau").read_text(encoding="utf-8")
    for token, value in {"ASSET_ID": config["asset"], "CREATOR_ID": config["creator"], "CREATOR_TYPE": config["creator_type"], "PLUGIN_NAME": config["plugin_name"], "DESCRIPTION": config["description"]}.items():
        source = source.replace(f"__{token}__", value)
    return source


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Unexpected redirect; refusing to forward publishing credentials")


class Client:
    def __init__(self, key: str):
        if not key:
            raise ValueError("ROBLOX_OPEN_CLOUD_API_KEY is required")
        self.key = key
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method: str, url: str, payload: bytes | dict | None = None) -> dict:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("Expected an HTTPS upload URL")
        is_api = parsed.hostname == "apis.roblox.com"
        headers = {"User-Agent": "nightcycle-asset-tools/0.1.0"}
        if is_api:
            headers["x-api-key"] = self.key
        if isinstance(payload, dict):
            data = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        else:
            data = payload
            headers["Content-Type"] = "application/octet-stream"
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        # Never automatically retry a task-creation POST: it could publish a second version.
        for attempt in range(4):
            try:
                with self.opener.open(request, timeout=60) as response:
                    body = response.read()
                return json.loads(body) if body else {}
            except urllib.error.HTTPError as error:
                if method == "GET" and error.code in (429, 500, 502, 503, 504) and attempt < 3:
                    time.sleep(2 ** (attempt + 1))
                    continue
                raise RuntimeError(f"Roblox {method} failed (HTTP {error.code}); check permissions and API availability") from None
        raise RuntimeError("Request retries exhausted")


def resource_url(path: str, universe: str) -> str:
    if not path.startswith(f"universes/{universe}/") or ".." in path or not re.fullmatch(r"[A-Za-z0-9/_-]+", path):
        raise ValueError("Unexpected Open Cloud resource path")
    return BASE + path


def wait_for_task(client: Client, task: dict, universe: str, asset: str, timeout: float = 600) -> str:
    url = resource_url(task["path"], universe)
    deadline = time.monotonic() + timeout
    while task.get("state") in ("QUEUED", "PROCESSING", "STATE_UNSPECIFIED"):
        if time.monotonic() >= deadline:
            raise TimeoutError(f"Publishing task timed out; inspect {task['path']} before retrying")
        time.sleep(3)
        task = client.request("GET", url)
    if task.get("state") != "COMPLETE":
        raise RuntimeError(f"Publishing task failed: {task.get('state')}: {task.get('error', {})}")
    results = task.get("output", {}).get("results", [])
    for result in results:
        if isinstance(result, str) and re.fullmatch(rf"AssetToolsPublished:{asset}:[1-9][0-9]*", result):
            return result.rsplit(":", 1)[1]
    raise RuntimeError("Task completed without a verified plugin version; inspect task output before retrying")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plugin", choices=("previewer", "organizer"))
    parser.add_argument("--dry-run", action="store_true", help="Validate config and artifact without network access")
    args = parser.parse_args()
    config = configuration(args.plugin, dict(os.environ))
    artifact = ROOT / "build" / f"Asset{args.plugin.title()}.rbxm"
    content = artifact.read_bytes()
    if not content.startswith(b"<roblox!") or len(content) > 100 * 1024 * 1024:
        raise ValueError("Expected a binary Roblox model smaller than 100 MiB")
    source = engine_script(config)
    print(f"{artifact.name} -> plugin {config['asset']} ({len(content)} bytes, SHA256 {hashlib.sha256(content).hexdigest()})")
    if args.dry_run:
        print("Dry run passed. No requests sent.")
        return
    client = Client(os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", ""))
    upload = client.request("POST", BASE + f"universes/{config['universe']}/luau-execution-session-task-binary-inputs", {"size": len(content)})
    resource_url(upload["path"], config["universe"])
    client.request("PUT", upload["uploadUri"], content)
    task = client.request("POST", BASE + f"universes/{config['universe']}/places/{config['place']}/luau-execution-session-tasks", {
        "script": source, "timeout": "300s", "binaryInput": upload["path"], "enableBinaryOutput": False,
    })
    print(f"Publishing task: {task['path']}")
    version = wait_for_task(client, task, config["universe"], config["asset"])
    print(f"Published {args.plugin} plugin {config['asset']} version {version}")


if __name__ == "__main__":
    main()
