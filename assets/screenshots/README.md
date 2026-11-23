# README 预览维护

这些图片来自当前 Flutter 页面和虚构的课程、姓名、成绩数据，不是设计效果图或真实账号截屏。手机图在 Windows 上以 Android 布局渲染；桌面图包括完整壳层和单页组件渲染。不能据此声称完成 Android 真机、相机、定位、系统通知或真实课堂验收。

在 Windows 完成锁文件依赖安装后运行：

```powershell
pwsh -File scripts/capture-readme.ps1
```

脚本使用项目 Flutter 入口、`--no-pub` 和现有 `CAPTURE_*` 开关，测试通过后才将选定 PNG 复制到本目录，结束时恢复工作目录和环境变量。生成时使用 Windows 本机字体，详见 [字体说明](../../test/fixtures/fonts/README.md)。中间图片保留在被忽略的 `build/` 和 `.tools/`，不整批提交。

| 图片 | 真实页面与生成入口 |
| --- | --- |
| `windows-rollcall.png`、`windows-history.png`、`windows-tools.png` | `desktop_workspace_test.dart`，完整 AdaptiveShell，1120 × 780 |
| `android-rollcall.png`、`android-rollcall-dark.png` | `mobile_campus_design_test.dart`，手机签到页及真实导航组件，390 × 844 |
| `android-homework.png`、`android-homework-dark.png`、`windows-homework.png` | `readme_preview_test.dart`，HomeworkHubPage；手机 390 × 844、桌面 1120 × 780 |
| `windows-gpa.png` | `gpa_page_test.dart`，GpaPage，960 × 1000 |

提交前逐张实看：没有真实身份或凭据，没有加载中/错误占位、调试横幅或失焦菜单；文案、导航、功能范围与当前源码一致。截图中的历史日期和测试课程是演示数据，不代表在线业务状态。新功能说明以 [功能状态](../../docs/FEATURE_TRACKING.md) 为准。
