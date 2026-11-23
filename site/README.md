# 项目网站与搜索发现

网站地址：<https://midiaug.github.io/xmu-rollcall/>。公开介绍本站为“厦大签到（xmu-rollcall）”，说明厦门大学畅课（TronClass）、Android / Windows 和第三方开源身份。

## 构建与维护

```powershell
python scripts/build_site.py
python -m http.server 8765 --bind 127.0.0.1 --directory build/site
```

访问 `http://127.0.0.1:8765/` 检查概览、安装、FAQ 和账号与数据说明四页。Python 仅使用标准库，正文不依赖 JS。修改 `site/*.html`、`site/style.css` 或现有截图后重新构建；只将 `build/site` 的内容同步到本仓库的 `gh-pages` 发布分支。不要发布本项目整个根目录或 docs。GitHub Pages 使用 gh-pages 根目录发布；发布前核对 Pages 设置，只有远端实际部署成功才称上线。

内容以根 `README.md`、`CHANGELOG.md` 和 `docs/FEATURE_TRACKING.md` 的当前范围为准，截图复用 `assets/screenshots/`，不把组件预览当作真机或真实课堂验收。介绍当前源码能力与最新公开安装版本可能存在时间差，下载统一指向 GitHub 正式发布页，不在网页硬编码“最新版本”。README 的功能、平台、更新方式、数据边界变化时，同步这四页。网站采用独立的展示型设计：大字号、留白、真实界面截图、少量蓝色强调与深浅展示分区；根 DESIGN.md 面向客户端，不将其组件尺寸机械套用到网站。

网站字体优先使用设备原生字体，缺少中文无衬线字体时回退到本站托管的约 110KB WOFF2 子集，不请求外部字体服务。子集来自仓库已有的 Noto Sans SC，派生字体命名为 Rollcall Web；许可证位于 `site/fonts/OFL.txt`。修改页面文案后可运行以下维护命令，普通网站构建无需安装这些依赖：

```powershell
python -m pip install --target .tools/site-font fonttools brotli
python scripts/subset_site_font.py
```

首页以功能和界面为主，不堆叠防御性提示；保留每页的第三方身份，将具体账号、下载与提交影响集中到相应说明页。功能限制用直接回答用户问题的方式表述。

更换域名或子路径时，使用 `python scripts/build_site.py --base-url https://example.com/path/`，所有 canonical、分享图与 sitemap 随构建更新。原域名的跳转另行配置。robots.txt 只有位于域名根 `/robots.txt` 时有效；项目子路径下同名文件不能控制宿主策略。

## 收录步骤（需要站点所有者账号）

1. 先确认线上首页、`install.html`、`faq.html`、`sitemap.xml` 返回正确内容，不是旧演示或 404。发布不是收录。
2. 在 Google Search Console 添加网址前缀 `https://midiaug.github.io/xmu-rollcall/`，使用其生成的 HTML 验证文件或 meta 标签验证所有权。不能编造验证值；下载验证文件后放入部署仓库并持续保留。如希望由此构建脚本维护，需明确加入复制步骤，避免以后同步丢失。
3. 提交 `https://midiaug.github.io/xmu-rollcall/sitemap.xml`；网址检查首页、安装和 FAQ，请求编入索引。观察页面索引报告与搜索效果，不靠 `site:` 查询独自断定未收录。
4. 可在 Bing Webmaster Tools 验证同一站点并提交 sitemap。在仓库 About Website、GitHub 个人主页及真实项目介绍中链接网站；About 建议保留准确中文简介和现有相关 Topics。
5. 用项目全名与使用场景观察曝光、点击及 AI 回答引用，记录日期和搜索平台；不要用“模型知道项目了”代替联网搜索引用验证。

## AI 搜索与抓取

首页给出可核验的软件身份、源码、下载与支持范围；FAQ 回答用户真实问题。子站不生成无效的子路径 robots.txt；域名根 robots 策略由根站单独维护，不能从本项目源码推定已经部署。2026-11-24 实查根站及 `/robots.txt` 返回 404，需在根站维护时核对；Google 对 robots 的 404 按无抓取限制处理，不能将它解释为钓鱼拦截原因。若根站恢复 robots，应核对 Googlebot、Bingbot、OAI-SearchBot 的访问和 sitemap 声明。CDN 或宿主限制需另查。搜索抓取与模型训练是独立控制项，本次不额外改变训练偏好。没有添加虚构评分、评价或关键词堆叠，也不把 llms.txt 当作必要条件。

官方依据：[Google AI 搜索](https://developers.google.com/search/docs/appearance/ai-features)、[请求抓取](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl)、[OpenAI 爬虫](https://developers.openai.com/api/docs/bots)、[GitHub Pages 发布源](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)。抓取、收录、排名及 AI 引用均不保证。

## 多项目布局

`MidiAug/MidiAug.github.io` 维护根站项目导航；每个项目仓库使用自己的 Pages 发布分支，对应 `https://midiaug.github.io/仓库名/`。各项目独立构建发布，共用域名根 robots 策略；新增项目时更新根站导航与 sitemap 入口。

## 安全提示与复核

每页保留独立维护者和非官方身份，`privacy.html` 区分介绍网站、已安装客户端和托管服务的数据边界。网站不提供账号登录、凭证上传、统计脚本或广告；安装页明确当前签名状态和校验方式，不要求关闭安全防护。视觉更新和哈希校验均不代表第三方安全认证或解封。

若 Chrome 或 Edge 提示危险，先取完整 URL、提示类型、发现时间与示例页面，区分网站钓鱼标记、恶意下载与未知发布者提示。Google 以 Search Console 的安全问题报告定位，整改后提交安全审核；疑似误报可用 [Safe Browsing 反馈](https://www.google.com/safebrowsing/report_error/)。微软通过 Edge 警告页的“报告此网站不包含威胁”入口单独复核。不得把新站上线写成安全标记已解除，也不得默认通过换域名解决。
