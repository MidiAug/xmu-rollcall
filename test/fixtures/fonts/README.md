# 布局测试字体

`NotoSansSC-Regular.otf` 是未修改的 Noto Sans SC Regular，按同目录的 SIL Open Font License 分发。

Copyright © 2014–2021 Adobe (http://www.adobe.com/). 字体版本：2.004。

- 来源：[notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/blob/523d033d6cb47f4a80c58a35753646f5c3608a78/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf)
- 固定来源提交：`523d033d6cb47f4a80c58a35753646f5c3608a78`
- SHA-256：`faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9`
- 许可证原文：[LICENSE](https://github.com/notofonts/noto-cjk/blob/523d033d6cb47f4a80c58a35753646f5c3608a78/LICENSE)

只有显式调用 `loadDesktopPreviewFonts()` / `loadLayoutTestFonts()` 的布局测试加载此字体。常规运行将它注册到应用的平台字体族名下，以获得跨平台可重复的中文排版；这是测试替代字体，不表示原生字体度量完全相同。文件由测试直接读取，未声明为应用资产，不进入正式安装包。未显式加载字体的测试继续使用 Flutter 默认测试字体。

显式设置任一 `CAPTURE_*=1` 的捕获运行使用 Windows 本机字体，供原生视觉检查；应在 Windows 执行，不作为跨系统逐像素比较基线。普通 CI 不设置捕获开关。真实字体的截图仍受操作系统、SDK、设备像素比等影响，不能只靠统一字体保证像素相同。

更新字体时同时更新来源提交和哈希，并运行全部 Flutter 测试及 Linux / Windows CI。字体缺失必须报错，不得静默回退。无需在 CI 安装系统字体或联网下载字体。

依据：[Flutter 测试字体](https://github.com/flutter/flutter/blob/3.47.9/docs/contributing/testing/Flutter-Test-Fonts.md)、[FontLoader 与 Golden 测试限制](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html)。
