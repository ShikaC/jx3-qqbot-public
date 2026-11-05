#!/usr/bin/env python3
"""Configure a fresh AstrBot instance for the JX3 QQ bot.

This script intentionally only edits local JSON/SQLite files. It never calls
JX3API or the configured LLM, so setup can run without spending quota.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_PLATFORM_ID = "jx3-qq"
DEFAULT_PROVIDER_SOURCE_ID = "deepseek"
DEFAULT_PROVIDER = "deepseek"
DEFAULT_LLM_BASE_URL = "https://api.deepseek.com/v1"
DEFAULT_LLM_MODEL = "deepseek-flash"
DEFAULT_JX3_WSS = "wss://socket.nicemoe.cn"


def _read_json(path: Path, *, missing_ok: bool = False) -> dict[str, Any]:
    if not path.exists():
        if missing_ok:
            return {}
        raise SystemExit(f"配置文件不存在：{path}")
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        raise SystemExit(f"无法读取 JSON：{path}（{exc}）") from exc


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # AstrBot writes cmd_config.json as UTF-8 with BOM; keep that convention.
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    path.write_text(text, encoding="utf-8-sig")


def _find_or_add(items: list[dict[str, Any]], *, ids: set[str], factory) -> dict[str, Any]:
    for item in items:
        if str(item.get("id") or "") in ids:
            return item
    item = factory()
    items.append(item)
    return item


def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")


def configure_astrbot(
    root: Path,
    *,
    jx3_token: str,
    llm_key: str,
    llm_base_url: str,
    llm_model: str,
    llm_provider: str,
    onebot_token: str,
    onebot_port: int,
    dashboard_port: int,
    dashboard_username: str,
) -> None:
    path = root / "data" / "cmd_config.json"
    config = _read_json(path)

    platforms = config.setdefault("platform", [])
    if not isinstance(platforms, list):
        raise SystemExit("cmd_config.json 的 platform 字段不是列表，拒绝覆盖。")
    platform = _find_or_add(
        platforms,
        ids={DEFAULT_PLATFORM_ID, "aiocqhttp"},
        factory=lambda: {"id": DEFAULT_PLATFORM_ID, "type": "aiocqhttp"},
    )
    platform.update(
        {
            "id": DEFAULT_PLATFORM_ID,
            "type": "aiocqhttp",
            "enable": True,
            "ws_reverse_host": "127.0.0.1",
            "ws_reverse_port": int(onebot_port),
            "ws_reverse_token": onebot_token,
        }
    )

    platform_settings = config.setdefault("platform_settings", {})
    platform_settings["enable_id_white_list"] = False
    platform_settings["id_whitelist"] = []

    if llm_key:
        sources = config.setdefault("provider_sources", [])
        if not isinstance(sources, list):
            raise SystemExit("cmd_config.json 的 provider_sources 字段不是列表，拒绝覆盖。")
        source = _find_or_add(
            sources,
            ids={DEFAULT_PROVIDER_SOURCE_ID},
            factory=lambda: {"id": DEFAULT_PROVIDER_SOURCE_ID, "provider": llm_provider},
        )
        source.update(
            {
                "id": DEFAULT_PROVIDER_SOURCE_ID,
                "provider": llm_provider,
                "type": "openai_chat_completion",
                "provider_type": "chat_completion",
                "enable": True,
                "key": [llm_key],
                "api_base": llm_base_url,
                "timeout": 120,
                "proxy": "",
                "custom_headers": {},
            }
        )

        provider_id = f"{DEFAULT_PROVIDER_SOURCE_ID}/{llm_model}"
        providers = config.setdefault("provider", [])
        if not isinstance(providers, list):
            raise SystemExit("cmd_config.json 的 provider 字段不是列表，拒绝覆盖。")
        provider = _find_or_add(
            providers,
            ids={provider_id},
            factory=lambda: {"id": provider_id},
        )
        provider.update(
            {
                "id": provider_id,
                "enable": True,
                "provider_source_id": DEFAULT_PROVIDER_SOURCE_ID,
                "model": llm_model,
                "modalities": ["text", "image", "tool_use"],
                "custom_extra_body": {},
                "max_context_tokens": 1000000,
            }
        )

        runner = config.setdefault("agent_runner", {})
        runner["runner_type"] = "local"
        runner_config = runner.setdefault("config", {})
        model = runner_config.setdefault("model", {})
        model["provider_id"] = provider_id
        model["fallback_provider_ids"] = []
        model.setdefault("request_max_retries", 5)
        compression = runner_config.setdefault("compression", {})
        compression["provider_id"] = provider_id
        persona = runner_config.setdefault("persona", {})
        persona["persona_id"] = "default"
        persona.setdefault("safety_mode", True)
        persona.setdefault("safety_mode_strategy", "system_prompt")

        provider_settings = config.setdefault("provider_settings", {})
        provider_settings["enable"] = True
        provider_settings["default_image_caption_provider_id"] = provider_id
        provider_settings["provider_pool"] = ["*"]
        provider_settings["persona_pool"] = ["*"]
        provider_settings["web_search"] = False
        provider_settings["wake_prefix"] = ""
        provider_settings.setdefault("datetime_system_prompt", True)
    else:
        # 没有 LLM Key 时关掉默认对话能力，只保留剑三查询。
        provider_settings = config.setdefault("provider_settings", {})
        provider_settings["enable"] = False

    dashboard = config.setdefault("dashboard", {})
    dashboard["host"] = "127.0.0.1"
    dashboard["port"] = int(dashboard_port)
    dashboard["username"] = dashboard_username
    dashboard["password_change_required"] = False
    if not dashboard.get("jwt_secret"):
        dashboard["jwt_secret"] = secrets.token_hex(32)

    config["timezone"] = "Asia/Shanghai"
    config["plugin_set"] = ["*"]
    _write_json(path, config)

    plugin_config_path = root / "data" / "config" / "astrbot_plugin_jx3_config.json"
    plugin_config = _read_json(plugin_config_path, missing_ok=True)
    prefix = plugin_config.setdefault("prefix", {})
    prefix["follow_astrbot_wake"] = False
    prefix["enable"] = False
    prefix["text"] = prefix.get("text") or "剑三"
    plugin_config["jx3api_token"] = jx3_token
    plugin_config["jx3api_ticket"] = plugin_config.get("jx3api_ticket") or ""
    plugin_config["jx3api_wss"] = plugin_config.get("jx3api_wss") or DEFAULT_JX3_WSS
    plugin_config["jx3api_wss_token"] = plugin_config.get("jx3api_wss_token") or ""
    plugin_config["tls_verify"] = True
    # 清理旧版本遗留字段；features 是修改版功能开关，必须保留。
    plugin_config.pop("llm_only_on_wake", None)
    plugin_config.pop("pz_current_zlp", None)
    plugin_config.setdefault(
        "team_management",
        {
            "view_output": "图片",
            "blacklist_provider": "",
            "blacklist_prompt": (
                "你是剑网3团队管理助手。请从团队成员中选择一名加入团队黑本。"
                "必须且只能选择团队数据中真实存在的一个角色，并严格使用以下格式回复：\n"
                "角色名：角色名称\n理由：简短明确的理由\n"
                "理由需要主要结合该成员的角色名称、不要参考心法、职责或老板标记，"
                "不要编造团队数据中不存在的信息，也不要输出其他内容。"
            ),
        },
    )
    plugin_config.setdefault(
        "image_render_quality",
        {"device_scale_factor": "1.0", "format": "jpeg", "jpeg_quality": 100},
    )
    _write_json(plugin_config_path, plugin_config)

    print(f"已写入 AstrBot 配置：{path}")
    print(f"已写入 JX3 插件配置：{plugin_config_path}")


def seed_persona(root: Path, persona_file: Path) -> None:
    if not persona_file or not persona_file.exists():
        return
    text = persona_file.read_text(encoding="utf-8").strip()
    if not text:
        return

    db_path = root / "data" / "data_v4.db"
    if not db_path.exists():
        # AstrBot creates the database on first run; setup calls this again after start.
        return

    connection = sqlite3.connect(str(db_path))
    try:
        now = _utc_now()
        row = connection.execute(
            "SELECT id FROM personas WHERE persona_id = ?",
            ("default",),
        ).fetchone()
        if row:
            connection.execute(
                "UPDATE personas SET system_prompt = ?, updated_at = ? WHERE persona_id = ?",
                (text, now, "default"),
            )
        else:
            connection.execute(
                """
                INSERT INTO personas (
                    created_at, updated_at, persona_id, system_prompt,
                    begin_dialogs, tools, skills, custom_error_message,
                    folder_id, sort_order
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (now, now, "default", text, "[]", None, None, None, None, 0),
            )
        connection.commit()
    finally:
        connection.close()
    print(f"已写入默认人格：{persona_file}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="配置 AstrBot 的 JX3 机器人实例")
    parser.add_argument("--root", required=True, help="AstrBot 实例根目录")
    parser.add_argument("--jx3-token", default=os.environ.get("JX3_SETUP_JX3_TOKEN", ""))
    parser.add_argument("--llm-key", default=os.environ.get("JX3_SETUP_LLM_KEY", ""))
    parser.add_argument("--llm-base-url", default=DEFAULT_LLM_BASE_URL)
    parser.add_argument("--llm-model", default=DEFAULT_LLM_MODEL)
    parser.add_argument("--llm-provider", default=DEFAULT_PROVIDER)
    # 仅在写入完整配置时需要；--persona-only 走不到这个校验。
    parser.add_argument("--onebot-token", default="")
    parser.add_argument("--onebot-port", type=int, default=6199)
    parser.add_argument("--dashboard-port", type=int, default=6185)
    parser.add_argument("--dashboard-username", default="astrbot")
    parser.add_argument("--persona-file", type=Path)
    parser.add_argument("--persona-only", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    root = Path(args.root).resolve()
    if not (root / "data" / "cmd_config.json").exists():
        raise SystemExit(f"不是有效的 AstrBot 实例目录：{root}")

    if args.persona_only:
        if args.persona_file:
            seed_persona(root, args.persona_file)
        return 0

    if not args.jx3_token:
        raise SystemExit("缺少 JX3API Token；请通过 --jx3-token 或环境变量传入。")
    if not args.onebot_token:
        raise SystemExit("缺少 OneBot WS Token。")

    configure_astrbot(
        root,
        jx3_token=args.jx3_token,
        llm_key=args.llm_key,
        llm_base_url=args.llm_base_url,
        llm_model=args.llm_model,
        llm_provider=args.llm_provider,
        onebot_token=args.onebot_token,
        onebot_port=args.onebot_port,
        dashboard_port=args.dashboard_port,
        dashboard_username=args.dashboard_username,
    )
    if args.persona_file:
        seed_persona(root, args.persona_file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
