#!/usr/bin/env python3
"""用 GitHub Releases 里最新的两个 stride-v* 生成 SideStore / AltStore 源。"""

import json
import os
import subprocess


def version_key(tag: str):
    parts = []
    for piece in tag.removeprefix("stride-v").split("."):
        try:
            parts.append(int(piece))
        except ValueError:
            parts.append(0)
    return parts


def gh_json(args):
    raw = subprocess.check_output(["gh", *args], text=True)
    return json.loads(raw)


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    keep = int(os.environ.get("KEEP_RELEASES", "2"))
    raw_base = f"https://raw.githubusercontent.com/{repo}/main"
    source_url = f"{raw_base}/apps.json"
    icon_url = (
        f"{raw_base}/ios/Stride/Resources/Assets.xcassets/"
        "AppIcon.appiconset/AppIcon.png"
    )

    listed = gh_json(["release", "list", "--limit", "100", "--json", "tagName,publishedAt"])
    versions = []
    for rel in listed:
        tag = rel.get("tagName") or ""
        if not tag.startswith("stride-v"):
            continue
        detail = gh_json(["release", "view", tag, "--json", "tagName,publishedAt,assets"])
        ipa = next(
            (asset for asset in detail.get("assets") or [] if str(asset.get("name", "")).endswith(".ipa")),
            None,
        )
        if ipa is None:
            continue
        ver = tag.removeprefix("stride-v")
        size = int(ipa.get("size") or 0)
        local_ipa = os.environ.get("LOCAL_IPA")
        local_ver = os.environ.get("LOCAL_VERSION")
        if size <= 0 and local_ipa and local_ver == ver and os.path.exists(local_ipa):
            size = os.path.getsize(local_ipa)
        versions.append(
            {
                "version": ver,
                "date": detail.get("publishedAt") or rel.get("publishedAt"),
                "localizedDescription": f"步迹 {ver}。未签名安装包，用 SideStore 和 LocalDevVPN 安装。",
                "downloadURL": f"https://github.com/{repo}/releases/download/{tag}/{ipa['name']}",
                "size": size,
                "_key": version_key(tag),
            }
        )

    versions.sort(key=lambda item: item["_key"], reverse=True)
    versions = versions[:keep]
    for item in versions:
        item.pop("_key", None)

    apps = []
    if versions:
        current = versions[0]
        apps.append(
            {
                "name": "步迹",
                "bundleIdentifier": "com.yg.stride",
                "developerName": "Stride",
                "localizedDescription": "练得清楚，才练得下去。训练记录、饮水、本周计划和 AI 教练都在本机。",
                "iconURL": icon_url,
                "icon": icon_url,
                "tintColor": "5CE08F",
                "version": current["version"],
                "date": current["date"],
                "downloadURL": current["downloadURL"],
                "size": current["size"],
                "versions": versions,
            }
        )

    source = {
        "name": "步迹",
        "identifier": "com.yg.stride.source",
        "sourceURL": source_url,
        "apps": apps,
    }
    out = os.environ.get("SOURCE_PATH", "apps.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(source, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"写入 {out}，收录 {len(versions)} 个版本")


if __name__ == "__main__":
    main()
