# 2026-10-24 课表、外观与桌面提醒验收

## 范围与依据

用户最新要求优先：课表解决字体、间距与交互；桌面和手机外观均使用应用组右侧下拉。此前的分段方案不再作为当前目标。按随后反馈移除课程左侧色条，收简桌面提醒并检查Windows图标。

源截图为用户本轮提供的课表，保存在 `.tools/timetable-polish/00-before-user.png`（仅本地，不纳入提交）。目标是提高可读性与可操作性，不逐像素复制旧截图。实施证据使用真实 CoursesPage、TimetableGridView、SettingsPage 及 shell 组件，课程与账号均为隔离测试数据，不访问用户会话。

## 渲染证据与对照

| 状态 | 文件 |
| --- | --- |
| 960×720 桌面，浅色，顶部 | `.tools/timetable-polish/desktop-light-01-top.png` |
| 960×720 桌面，暗色，晚课 | `.tools/timetable-polish/desktop-dark-02-late.png` |
| 桌面课程详情 | `.tools/timetable-polish/desktop-light-03-detail.png` |
| 桌面 1.3 字号，含周末与晚课 | `.tools/timetable-polish/desktop-large-weekend-02-late.png` |
| 384×844 窄屏 | `.tools/timetable-polish/mobile-light-01-top.png` |
| 320×844 窄屏，1.3 字号，含周末与晚课 | `.tools/timetable-polish/mobile-large-weekend-02-late.png` |
| 桌面提醒初始 / 确认 / 排查 / 失败 | `.tools/notification-polish/960-light-01-initial.png`、`02-sent.png`、`03-help.png`、`05-failed.png`（后3项同目录同前缀） |
| 桌面提醒暗色与窄屏大字 | `.tools/notification-polish/960-dark-03-help.png`、`320-dark-03-help.png` |
| Windows原生检查记录 | `.tools/notification-polish/native-smoke.json`、`windows-history.json` |
| 两端外观下拉 | `.tools/settings-polish/960-light.png`、`384-light.png` |

实现截图密度为1，像素等于Flutter逻辑视口，无CSS尺寸。用户课表截图944×711，实现桌面为项目固定960×720；课程内容、账号、更新时间不同，因此不比较具体课程坐标或文本逐字差异。源截图与最新桌面渲染已放在同一比较输入中检查；课程块文字、轴标签、浅暗配色、详情、滚动状态分别放大复核。

## 五项检查

- **字体与文案**：桌面课程名由10px改为13px，教师/地点由8px改为11px，时刻由8px改为10px；标题与说明分层，课程名不再和教学班挤成一行粗体。保留平台字体和CJK回退；可视验证载入微软雅黑与Material Icons，另以测试宽字形验证布局。班级已在课名中出现时不再重复；未知时刻不补成08:00。
- **间距与布局**：课程块桌面水平10px、垂直8px，页面24px横向留白与公共页面对齐。桌面每节至少56px、手机44px，随系统字号增加。空间不足时滚动；星期表头纵向固定，节次/时间列横向固定。含周末时课程列横向滚动，保持最小可读宽度，表头与内容同步。
- **颜色与组件**：浅色用白色网格与低饱和课程底，深色用对应暗底；课程ID配色稳定。课程名使用正文前景，课程元信息使用高对比同色系文字；100个ID在两套主题下均验证至少4.5:1。滚动条统一为轻灰4px圆角，悬浮/拖动加深；详情使用公共圆角和细边界，不使用重阴影。
- **图像与图标**：保留已有BrandMark与Material Icons，无新增位图、图标库或生成图。源截图作为问题基准，不作为图片资产进入应用。
- **交互与信息**：课程卡整块可点击并具有按钮语义；Enter打开，桌面Escape关闭。桌面居中详情可复制完整课名、教学班、时间、教师和地点，手机使用可滚动详情面板。空间较小的课程块省略次要字段，详情保持完整。外观两端统一为右侧148px下拉，支持鼠标、键盘与持久化；更新线路仍归关于的更新区。

## 发现与修复记录

1. **P2，课程文字和留白**：源截图10/8px文字、4/3px内边距难读。已提高字号、分开课程/班级层级，增加留白并设置最小行高；最新浅暗截图已复核。
2. **P2，压缩网格**：原版强制将11节塞入视口。现在保留可读尺寸，晚课滚动可达；自动化验证星期表头位置不变。
3. **P2，横向滚动的定位**：首轮实现会卷走左侧节次。已将节次列固定，并让星期栏跟随课程的横向位移；大字号周末截图及固定位置断言通过。
4. **P2，宽字形时间换行**：未载入系统字体的回归发现44px窄屏时间栏会自动多换行、挤压节次。现增加轴宽，并明确起止各一行；使用宽字形与系统字体分别检查。
5. **P2，课程卡操作**：原GestureDetector仅处理点击。已使用Material/InkWell，提供焦点、键盘、悬浮与完整语义；桌面不再弹出手机样式底部面板，详情内容可选择复制。
6. **P2，控件一致性**：外观根据最新选择统一为下拉；两端应用组右侧对齐，原分段不再展示。滚动条和弹窗边界一并收敛。

7. **P2，装饰与说明密度**：课程块移除左侧色条，保留淡底与文字层级。桌面提醒移除扩展排障面板、通知连接状态和重复长段落，固定两组；发送、确认和按需排查在同一组内，避免重复成功Toast。浅暗、320大字与发送中/成功/未收到/确认/失败状态已渲染检查。
8. **P1，Windows图标与重试**：原初始化未传iconPath，通知也未配置图像。现在注册可执行文件相对的既有PNG，同时每条通知带appLogoOverride。初始化重试创建新插件，避免FFI late-final句柄重复初始化；测试开始清除旧确认，失败后不显示已收到。

## 验证与边界

- `flutter analyze`：无问题。
- 全量`flutter test`：473通过，2真实网络项跳过（`.tools/notification-polish/full-test.log`）。
- 通知/壳/课表聚焦回归：30通过；系统字体加载后的课表、外观、桌面提醒渲染与交互：21通过。原有Android提醒权限与确认测试仍通过。
- Windows现有开发实例：重新初始化通知服务、原生测试发送完成；系统通知历史确有测试记录及appLogoOverride，注册IconUri非空且目标PNG存在。记录仅证明系统接收与图标元数据有效；没有将其标为用户已收到，也未代替实际横幅外观或系统鼠标点击验收。
- 通知点击的窗口恢复、测试保留当前页、发现打开签到根页经过隔离自动回归；真实系统点击未代操作。

Windows现有Flutter开发会话已热重载，未新开应用窗口。交互检查为生产组件的隔离Widget自动化；窄屏课表截图在Windows宿主生成，仍含宿主窗控，不作为Android原生壳、状态栏或系统字体的真机验收。Android真机和系统辅助功能手工验收未执行。

实现与自动化布局检查：passed。Windows系统接收/图标注册检查：passed。Windows横幅图像与真实点击、Android真机、多端系统行为：未手工验收。

## 通知图标依据

Engineering知识检索未命中相关既有笔记，本轮未回写知识库。核对当前本地flutter_local_notifications_windows 3.1.1源码与[初始化图标接口](https://pub.dev/documentation/flutter_local_notifications_windows/latest/flutter_local_notifications_windows/WindowsInitializationSettings-class.html)、[WindowsImage接口](https://pub.dev/documentation/flutter_local_notifications_windows/latest/flutter_local_notifications_windows/WindowsImage-class.html)。`src/plugin.cpp`将iconPath注册为系统IconUri；`notification_parts.dart`提供appLogoOverride。保留现有AUMID/GUID，未增依赖或修改系统全局通知偏好。
