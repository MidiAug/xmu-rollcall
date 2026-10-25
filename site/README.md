# 项目网站与搜索发现

网站地址：<https://midiaug.github.io/>。公开介绍本站为“厦大签到（xmu-rollcall）”，说明厦门大学畅课（TronClass）、Android / Windows 和第三方开源身份。

## 构建与维护

```powershell
python scripts/build_site.py
python -m http.server 8765 --bind 127.0.0.1 --directory build/site
```

访问 `http://127.0.0.1:8765/` 检查三页。Python 仅使用标准库，正文不依赖 JS。修改 `site/*.html`、`site/style.css` 或现有截图后重新构建；只将 `build/site` 的内容同步到独立仓库 `MidiAug/midiaug.github.io`。不要发布本项目整个根目录或 docs。该独立仓库沿用 GitHub Pages 的 main 根目录发布；发布前核对 Pages 设置，只有远端实际部署成功才称上线。

更换域名或子路径时，使用 `python scripts/build_site.py --base-url https://example.com/path/`，所有 canonical、分享图与 sitemap 随构建更新。原域名的跳转另行配置。robots.txt 只有位于域名根 `/robots.txt` 时有效；项目子路径下同名文件不能控制宿主策略。

## 收录步骤（需要站点所有者账号）

1. 先确认线上首页、`install.html`、`faq.html`、`sitemap.xml` 和 `/robots.txt` 返回正确内容，不是旧演示或 404。发布不是收录。
2. 在 Google Search Console 添加网址前缀 `https://midiaug.github.io/`，使用其生成的 HTML 验证文件或 meta 标签验证所有权。不能编造验证值；下载验证文件后放入部署仓库并持续保留。如希望由此构建脚本维护，需明确加入复制步骤，避免以后同步丢失。
3. 提交 `https://midiaug.github.io/sitemap.xml`；网址检查首页、安装和 FAQ，请求编入索引。观察页面索引报告与搜索效果，不靠 `site:` 查询独自断定未收录。
4. 可在 Bing Webmaster Tools 验证同一站点并提交 sitemap。在仓库 About Website、GitHub 个人主页及真实项目介绍中链接网站；About 建议保留准确中文简介和现有相关 Topics。
5. 用项目全名与使用场景观察曝光、点击及 AI 回答引用，记录日期和搜索平台；不要用“模型知道项目了”代替联网搜索引用验证。

## AI 搜索与抓取

首页给出可核验的软件身份、源码、下载与支持范围；FAQ 回答用户真实问题。robots.txt 默认允许公开爬虫，包括 Googlebot、Bingbot、OAI-SearchBot；CDN 或宿主限制还需单独检查。搜索抓取与模型训练是独立控制项，本次不额外改变训练偏好。没有添加虚构评分、评价或关键词堆叠，也不把 llms.txt 当作必要条件。

官方依据：[Google AI 搜索](https://developers.google.com/search/docs/appearance/ai-features)、[请求抓取](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl)、[OpenAI 爬虫](https://developers.openai.com/api/docs/bots)、[GitHub Pages 发布源](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)。抓取、收录、排名及 AI 引用均不保证。
