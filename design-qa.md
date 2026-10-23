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

## 2026-10-24 后续纠正：图标位置与实际内容

用户新截图确认旧appLogoOverride实际渲染为正文左侧大图，该配置已移除。此前“系统注册路径存在、XML带图标”检查不足以证明左上角身份图标显示正确；不能据此视为像素验收通过。当前仅保留IconUri，并在原生窗口创建前显式设置同一AppUserModelID，不切换通知身份来试错。

实际发现原先由Controller缩成数量，已经改为传递完整新发现列表。单条显示课程名+类型，多条显示配对摘要；自动结果含类型并保留静音更新。示例通知明确标注，不读取或提交真实签到。

依据：[Microsoft通知内容](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-content?tabs=xml)区分顶端身份与app logo override；[进程身份接口](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-setcurrentprocessexplicitappusermodelid)要求创建UI前设置。上游[2738](https://github.com/MaikuB/flutter_local_notifications/issues/2738)仍报告身份图标显示差异；不将issue里的GUID替换推测直接用作产品方案。

本次验证：

- `flutter analyze`无问题，全量478通过、2真实网络跳过；49项内容/通知/监控/权限聚焦回归通过；6项系统字体渲染回归通过。
- Windows Debug原生构建通过，停止旧开发进程后用`flutter run -d windows --debug --no-pub`启动，仍支持热重载；已核对只有一个应用进程，未额外启动发布版。
- 通过开发VM调用实际`DesktopNotifications.test()`；原生发送完成且不设置“用户已收到”。Windows通知历史XML包含“通知测试”“示例课程”“雷达签到”，不存在`image`元素，系统IconUri路径存在。证据：`.tools/notification-polish/content-native-smoke.json`、`content-windows-history.json`、`content-test-toast.xml`。
- 当前仅证明内容与发送、注册、XML布局配置正确。真实进行中签到端到端、左上角图标像素及系统点击未手工验收；未将源码中设置进程ID或记录中图标路径存在写成图像显示已通过。

此前本文件的appLogoOverride检查为上一阶段历史记录，已被本节修正。

## 2026-10-24 本地开发文档与图标复核（当前结论）

用户最新截图再次确认系统归属区没有小图标，因此这一项仍未修复。已查本机Engineering的Flutter官方Windows集成快照（来源flutter/website提交3eb87869bb0ddf57047150c2132324afc5c55f22，快照日期2026-10-22），该指南只提供Windows原生集成、FFI与分发入口，没有说明通知应该无图标。项目2026-09-25桌面设计仍记载local_notifier和发现后停止，已标记为历史方案；2026-10-23通知流程记录也明确原生横幅未实机验收。

本机当前只有一个Debug实例；只读核对本应用的IconUri、DisplayName、CustomActivator，字段存在、字符串正常，PNG路径存在。不能据此解释为“Windows本来就没有图标”，也不能声称特定缓存或GUID就是根因。

官方依据与采用：

- [Microsoft App notification content](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-content#attribution-area)，2026-10-24复核：Windows 11顶端显示应用名与图标，由Shell配置，XML不能覆盖；appLogoOverride在正文左侧放48px图像。采用两区域分离的判断，正文图片不能修复顶端图标。
- [flutter_local_notifications_windows 3.1.1](https://pub.dev/packages/flutter_local_notifications_windows)，2026-10-24复核：现用版本；其未打包应用的通知查询/取消存在单独限制，不能将查询结果或API成功当作像素验收。
- [上游2738](https://github.com/MaikuB/flutter_local_notifications/issues/2738)，2026-10-24复核：开发/EXE版报告同类顶端图标不一致，仍开放。这里只能支持存在同类兼容问题，不能证明本机完全相同的根因。未采用将AUMID替换GUID的未解释试错，未修改系统通知数据库或全局设置。

基于用户截图和当前源码的定向UI复核（不等于全产品实机审计）：

1. **已修**：测试通知重复“示例/示例/不会提交”的长句改为示例课程标题+类型/返回一行，完整不提交说明仍在提醒设置页。真实课程通知不变。
2. **已修**：自动签到原说明仅看running，导致开启却写默认关闭、关闭却描述提交。现在同时看开关与检测状态，关闭时隐藏不相关自动雷达长说明；统一该说明为公共bodySmall。
3. **后续优先**：签到设置把“查询间隔/人数轮询/随机波动/退避”等实现术语转为用户能理解的说明；保留人数刷新作为签到卡片的共用功能，不能因自动签到关闭就隐藏该项。低频调节项可集中到按需展开区。
4. **后续优先**：monitor_page仍自绘SettingCard/PresetPill与11px说明，和公共设置行/按钮不完全一致。先统一文字层级与状态反馈，再考虑圆角或装饰；保持现有简洁分组，不增加仪表盘卡片。

本次验证：10项针对性回归通过，另以系统中文字体渲染384/960下关闭、开启未运行、开启运行六种状态，两项交互回归通过；截图`.tools/notification-polish/monitor-settings-{384,960}-{off,enabled-idle,enabled-running}.png`。已检查保存的截图并修正仅测试字体导致的TextButton方框字，最终按钮文本正常。截图为实际MonitorSettingsPage生产组件的隔离渲染，不含完整侧栏，不作为原生系统通知截图。

`flutter analyze`最终检查无问题，现有Flutter开发实例已热重载。当前改动不触及Windows注册或通知后端，未重新触发系统通知、未变更全局设置；左上角图标仍未解决。本轮未重跑全量，不用此前478项结果代替本轮验证。

补充只读核对发现：开始菜单旧Debug快捷方式的目标位于已不存在的`D:\Project\_My\xmu-rollcall`旧根，AppUserModelID为应用中文名；当前安装入口的快捷方式AppUserModelID为空，与现用通知ID不同。当前只运行本仓Debug程序，未操作或清理用户快捷方式。这说明入口维护存在缺口，但没有把它断言为本次图标缺失的确定根因。

当前激活GUID对应HKCR/HKCU的`CLSID/.../LocalServer32`均不存在；插件3.1.1源码只向运行进程`CoRegisterClassObject`注册回调，未写冷启动服务器路径。依据[微软未打包通知激活说明](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-dotnet)，退出后由系统点击启动需要COM服务器注册。因此现有“运行中恢复窗口”自动回归不能代替“退出后点击拉起”；后者仍缺集成验收，本轮没有为验证而退出用户实例。属于高于视觉装饰的后续事项，不能将上游图标issue解释成整条通知功能已正常。

UI后续顺序：通知图标/安装入口/冷启动链路；真实状态说明（本轮已修）；低频频率参数、随机波动与运行记录按需展开；SettingCard/PresetPill和公共设置控件的文字与反馈统一。当前空的“最近运行”仍占整块卡片，可改为按需查看记录，避免未运行时显示一块无用信息。

## 2026-10-24 本轮实现与证据

签到设置收敛为常用设置与按需展开区：自动开关和三态文案保留；提交时机、检测预设复用右侧公共下拉；门槛仅在相关规则下显示；人数刷新和间隔浮动在“更多设置”中，关闭自动签到仍可调整人数刷新。空运行记录不占卡片，有数据后才提供最近5条记录的展开入口。SettingsRow为该页提供窄屏说明整行排版，避免320大字下被右侧控件挤成单字短行；其他设置行默认保持原排版。编辑项统一遵守未登录与账号加载禁用态。

验证：七项新的设置状态/交互回归覆盖960浅暗、384、320/1.3字号；关闭/开启未运行/开启运行/展开更多共16张生产组件隔离渲染，已检查保存截图。真实Android系统栏、键盘及触控未作设备验收。22项聚焦回归通过；旧账号布局回归更新为新展开/选择流程后10项通过；最终全量485项通过，2项真实网络测试跳过。未改动协议、检测/提交默认值或存储结构。

Windows只交付入口身份修正：安装器在创建快捷方式后调用原生助手，写入与发送者一致的AppUserModelID、ToastActivatorCLSID及EXE图标，助手在Flutter界面初始化前退出；运行时仅维护目标确为当前EXE的已有入口。缺失快捷方式不创建，其他安装/便携/开发版本入口不改指向。隔离原生测试通过，实际读回IPropertyStore属性、图标、原参数，并验证重复执行、Unicode名称、带空格路径及其他EXE目标保持不变。测试没有修改用户开始菜单或桌面入口。检查已接入Windows CI。

退出后启动试验仍失败：额外实验按微软文档补HKCU LocalServer32并尝试隔离COM激活，返回REGDB_E_CLASSNOTREG；同进程已注册工厂可激活，系统冷启动未通过。未确定根因，未改全局COM设置、系统通知数据库或清理用户快捷方式。相关实验源代码与日志只保留在忽略的.tools/notification-polish/cold-registration-experiment*和native-registration-test.log，未进入产品与稳定回归；本轮不把新增COM服务器注册作为已修功能。已清理实验创建的测试专用注册键，保留现有产品身份。

左上角小图标仍未通过：用户实际横幅缺失的问题没有像素证据证明恢复。入口属性正确只能证明一个缺口得到修正；[微软归属区域说明](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-content#attribution-area)仍说明该区域由Shell决定，正文appLogoOverride不能代替。退出后点击启动同样保留待解决；运行中点击恢复的既有自动回归不代替系统冷启动验收。

现有开发实例因原生入口代码重新构建并仅启动一个Windows窗口，新的原生flutter run终端支持r热重载且已验证。未安装或发布Release包。

最终检查补充：flutter analyze无问题；Windows Debug与Release原生构建通过；NSIS安装器编译通过（仅生成.tools内检查包，未执行安装）。Flutter原生会话保持运行，r热重载成功。工作流语法及CHANGELOG结构检查通过。

- [PASS] AC-MONITOR-SETTINGS-02 / AC-MONITOR-CONTROLS-02 / AC-MONITOR-LAYOUT-02：上述交互、保存、禁用与隔离渲染证据通过，Android真机另验。
- [PASS] AC-WINDOWS-SHORTCUT-02：隔离快捷方式属性与归属回归通过，安装器编译通过；未覆盖安装用户程序。
- [FAIL] AC-WINDOWS-NOTIFICATION-ICON-01 实际横幅部分：用户截图的小图标缺失仍未证实恢复。
- [FAIL] 退出后点击启动扩展验收：隔离COM冷启动实验未通过，稳定产品未纳入相关注册代码；既有运行中激活回归仍通过。
