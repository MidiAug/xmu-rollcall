"""Build the public project site using only the Python standard library."""
import argparse
import html
import json
import shutil
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
REPO = "https://github.com/MidiAug/xmu-rollcall"
PAGES = {
    "index.html": ("厦大签到（xmu-rollcall）｜厦门大学畅课开源客户端", "面向厦门大学畅课（TronClass）的开源客户端，支持 Android 和 Windows，提供课堂签到、作业查看与课表管理。查看界面、安装指南和常见问题。"),
    "install.html": ("下载安装厦大签到｜Android 与 Windows 安装指南", "厦大签到 xmu-rollcall 安装指南：从 GitHub Release 下载 Android APK、Windows 安装程序或便携 ZIP，了解更新、签名和系统提示。"),
    "faq.html": ("厦大签到常见问题｜平台支持、账号存储与后台提醒", "了解厦大签到 xmu-rollcall 的适用学校、Android 和 Windows 支持、账号安全存储、后台提醒、自动签到默认行为与问题反馈。"),
}


def build(base_url: str) -> Path:
    parts = urlsplit(base_url)
    if parts.scheme != "https" or not parts.netloc or parts.query or parts.fragment:
        raise ValueError("base-url must be an absolute HTTPS URL without query or fragment")
    base_url = base_url.rstrip("/") + "/"
    output = ROOT / "build" / "site"
    output.mkdir(parents=True, exist_ok=True)
    assets = output / "assets"
    assets.mkdir(exist_ok=True)
    shutil.copyfile(ROOT / "site" / "style.css", assets / "style.css")
    shutil.copyfile(ROOT / "assets/icon/app_icon.png", assets / "app_icon.png")
    for name in ("windows-rollcall.png", "android-rollcall.png", "android-homework.png"):
        shutil.copyfile(ROOT / "assets/screenshots" / name, assets / name)
    for filename, (title, description) in PAGES.items():
        url = base_url + ("" if filename == "index.html" else filename)
        data = {"@context": "https://schema.org", "@type": "SoftwareApplication",
                "name": "厦大签到", "alternateName": "xmu-rollcall", "url": base_url,
                "description": PAGES["index.html"][1], "applicationCategory": "EducationalApplication",
                "operatingSystem": "Android, Windows", "license": REPO + "/blob/main/LICENSE",
                "sameAs": REPO, "downloadUrl": REPO + "/releases/latest",
                "author": {"@type": "Person", "name": "MidiAug", "url": "https://github.com/MidiAug"}}
        structured = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c") if filename == "index.html" else ""
        head = f'''<meta name="description" content="{html.escape(description, quote=True)}">
<link rel="canonical" href="{html.escape(url, quote=True)}">
<meta property="og:type" content="website"><meta property="og:locale" content="zh_CN">
<meta property="og:title" content="{html.escape(title, quote=True)}">
<meta property="og:description" content="{html.escape(description, quote=True)}">
<meta property="og:url" content="{html.escape(url, quote=True)}">
<meta property="og:image" content="{html.escape(base_url, quote=True)}assets/windows-rollcall.png">
<meta name="twitter:card" content="summary_large_image">'''
        if structured:
            head += f'\n<script type="application/ld+json">{structured}</script>'
        nav = ''.join(f'<a href="{name}"' + (' aria-current="page"' if name == filename else '') + f'>{label}</a>'
                      for name, label in (("index.html", "概览"), ("install.html", "安装"), ("faq.html", "常见问题")))
        body = (ROOT / "site" / filename).read_text(encoding="utf-8")
        page = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>{head}
<meta name="theme-color" content="#3d5afe"><link rel="icon" href="assets/app_icon.png">
<link rel="stylesheet" href="assets/style.css"></head><body>
<a class="skip" href="#main">跳到正文</a>
<header><div class="nav"><a class="brand" href="index.html"><img src="assets/app_icon.png" width="32" height="32" alt="">厦大签到</a><nav aria-label="主导航">{nav}<a href="{REPO}">GitHub ↗</a></nav></div></header>
<main id="main">{body}</main>
<footer><span>厦大签到 · xmu-rollcall</span><span>由 MidiAug 维护 · MIT 开源 · 非学校官方应用</span><a href="{REPO}/issues">反馈问题 ↗</a></footer>
</body></html>\n'''
        (output / filename).write_text(page, encoding="utf-8")
    locations = [base_url + ("" if p == "index.html" else p) for p in PAGES]
    (output / "sitemap.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
        ''.join(f'<url><loc>{html.escape(url)}</loc></url>\n' for url in locations) + '</urlset>\n', encoding="utf-8")
    # Only effective at an origin root; project Pages cannot set the host's robots policy.
    (output / "robots.txt").write_text(f'User-agent: *\nAllow: /\n\nSitemap: {base_url}sitemap.xml\n', encoding="utf-8")
    (output / ".nojekyll").touch()
    print(f"Built {len(PAGES)} pages in {output} (canonical base: {base_url})")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="https://midiaug.github.io/")
    build(parser.parse_args().base_url)
