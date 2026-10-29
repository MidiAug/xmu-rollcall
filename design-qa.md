## 2026-10-29 导航胶囊与个人页层级修订

Android导航高亮为随Tab槽宽铺开的椭圆胶囊，不使用正圆；高亮相对导航外框上下/端点内缩5px，54px高度取27px圆角，与64px外框的32px圆角构成一致内缩轮廓。保留连续滑动、快速改向与减少动画行为。个人页顶部移除重复“我的”标题，以56px头像、22px姓名和账号状态作为唯一身份区；整行继续进入账号管理或登录，导航文字仍为“我的”。

验证：`flutter analyze --no-pub lib test`无问题；导航运动、设置外观/账号、搜索和移动主页30项通过。已有账号交互回归增加“我的”只在导航出现一次的断言；导航运动断言改为横向胶囊。实看`.tools/settings-polish/mobile-account-light.png`、`mobile-account-dark.png`和`build/nav-motion/in-flight.png`，浅深色身份区及移动中的胶囊正常；Android release构建成功（81.2MB，`build/nav-pill-profile-android-release.log`），比对设备427b338f原APK与新包证书一致后`adb install -r`返回Success，启动成功，版本0.3.0+6，保留原数据；真机观感由用户观察。

## 2026-10-29 Android导航圆形滑动高亮

Android四Tab浮动导航改为同一圆形底层高亮，270ms easeOutCubic连续移动；尺寸按槽宽限制至54px。移除各项独立选中背景，保留图标/文字选中、点击反馈、角标与搜索。current由原切页逻辑确认，系统减少动画时直接定位，IgnorePointer避免滑块截获点击。

`flutter analyze --no-pub lib test`无问题；导航运动、导航提醒、搜索与移动主页共18项通过，运动回归验证1→4途中位置、途中改到作业的连续性、最终中心、圆形尺寸、角标及减少动画。已实看`build/nav-motion/in-flight.png`，高亮位于工具/我的之间且没有额外背景。真实手机交互效果交由用户体验。

Android release重新构建成功（81.2MB，`build/nav-motion-android-release.log`），新包与设备427b338f现有APK证书一致；`adb install -r`返回Success并启动成功。继续0.3.0+6，保留原数据，未执行真实签到。

### 2026-10-29 本轮手机覆盖安装

`7031ed5` 源码构建 Android release 成功（81.2MB，`build/ui-spacing-android-release.log`），沿用0.3.0+6。连接设备427b338f，从设备读取原APK并验证新旧证书SHA-256一致；`adb install -r`返回Success，安装后查询versionName0.3.0/versionCode6。未卸载或清空数据；APK同时更新至`dist/xmu-rollcall-0.3.0-android.apk`。启动Intent已成功交给当前前台实例，页面实际观感交由用户检查，未执行真实签到。

## 2026-10-29 手机签到、搜索与作业角标微调

- 历史/设置图标上对齐并使用muted灰色，保持48px点击区域；Android开始检测改浅底描边，启动/停止条件保持原逻辑。
- 搜索列表明确只保留底部安全区，组标题上距12px；行内水平14px、图文间距12px、最小64px高度，文字随系统缩放，组内轻分隔。作业导航数量角标offset调整为(8,-4)。
- `flutter test`：搜索、移动主页、页头几何、页面inset、签到身份/二维码和导航提醒共65项通过；保留搜索底部安全区后单独重跑搜索1项通过。
- `flutter analyze --no-pub lib test`：No issues found。首次全目录分析长时间未返回，停止后改用源码范围，未声称全目录分析通过。
- 实看生产组件渲染：`build/android-masthead-polish/search.png`、`build/mobile-campus-design/idle-light.png`、`long-dark.png`。搜索初次渲染暴露显式样式丢字体继承，已改为沿用主题bodyMedium后重新渲染核对；浅色、深色和320宽1.3倍字体无溢出。
- 本轮未构建安装包、未安装或执行真机验收；未调用真实签到或联网查询。

# 2026-10-28 账号范围、区域地点和 GPA 工具

Final result: implemented scope verified; authenticated grade endpoint and Android physical-device checks remain unverified.

## Current behavior and evidence

- Refresh controls share the same surface/border. The homework refresh control has a 44px extent matching its segmented control. Timetable cells now use ellipsis for clipped text; full room text remains available in course details.
- Place filter has a visible selected fill. Course-place groups collapse room numbers into building/wing, resolve building aliases/fullwidth letters and show associated course names; custom wing coordinates apply to the other rooms in that wing. Room numbers remain in the actual timetable.
- `build/gpa-ui-review/gpa-960.0-false.png` and `gpa-384.0-true.png` were opened for visual inspection, alongside light/dark variants. Fixtures use fictional courses. They confirm app typography, three summary metrics, term selection, local update time, course checkboxes and long-title truncation. Font capture includes the real CJK/Fluent/Material faces; no generated bitmap UI or real grades are embedded.
- GPA is lazy: the campus tool card does not query grades. Opening the calculator reads its identity-specific snapshot, using a one-day cache; explicit refresh is throttled to at least 15 seconds. First/old caches query all grades, otherwise the server's recent-term identifiers determine replacement. Only server grade points and credits are weighted, with unknown points excluded.

## Isolation audit and regressions

- Existing requests, raw course catalogs, academic timetables, homework, history, attendance and automatic submission paths already carry target identity/session checks. Their account and queue regressions still run.
- Fixed global saved locations and schedule-gating preference. Scoped keys and legacy migration now keep them separate; only explicitly configured legacy assist point IDs migrate into that assist's list. Logged-out draft locations use a separate key; switching identity resets the location editor and campus selection so a draft cannot be saved into the next identity.
- Pending GPA response is discarded after selection/owner/session changes, including secure-store owner verification. Local rows exclude student identifiers/session data. Pagination or server error cannot replace a complete cached snapshot.
- Automatic start and explanation use the same selected-identity planner, wait for that identity's settings and do not borrow loading-state data from the previous identity. New widget regression switches from an allowed owner to an assist with an empty known schedule and asserts disabled start plus the no-class explanation.
- Term starts use cached TronClass `start_date` metadata, with a one-time old-catalog schema refresh and a unique most-common teaching Monday in the term's season; manual start remains highest priority. Unknown/ambiguous dates keep the published-calendar fallback.

## Validation

- Full suite: 730 passed, 2 existing network-config tests skipped (`build/gpa-all-final.log`).
- Focused UI/role regressions: 40 passed (`build/gpa-ui-regressions-final.log`).
- Static analysis: no issues (`build/gpa-final-static.log`); final location/grade subset: 12 passed (`build/gpa-delivery-focused.log`).
- Live development process: existing Windows app PID 70280, original `flutter run` session retained. Final library changes are hot-reloaded after restart (2 libraries in 3,004ms). Final grade subset: 8 passed; selected-role UI subset: 35 passed. One hot restart is used for the new provider/cache schema so migrations and identity dependencies initialize together; no release installation or duplicate app instance.
- Source capture `D:/Liu/Desktop/成绩查询.txt` is read-only and is neither committed nor replayed for authentication. Interface contract and audit notes stay in ignored local docs/research/54-grades-and-account-scope.md.

## Remaining checks

Authenticated end-to-end GPA retrieval is left for the first user-opened calculator; the automated suite uses fake records and protocol response shapes. Physical Android execution is not claimed. Device appearance, window/notification settings and imported-account management remain local management state, while business requests and records follow the selected identity.

---

# 2026-10-28 元信息对齐与地点列表微调

- User visual evidence: clipboard-38761503 (icons above text), clipboard-0baa780e (small sidebar dot), clipboard-8c7974a3 (pending link alignment). This is a targeted UI correction, not a new design direction.
- Corrected render evidence: `.tools/desktop-workspace/timeline-single-dark.png`; `build/place-ui-review/map-960.0-false.png` and dark/mobile variants. Viewed actual renders after the change. Map fixture tiles are intercepted by the test harness as documented below.
- Metadata icons now center in the first text line box (12px × 1.5 × text scale), preserving alignment when rooms wrap. Detail metadata uses one Fluent regular family, including clock and dismiss.
- Pending course action has no middle-dot separator, uses a 24px tinted icon anchor at the content edge and a separate open-map arrow. Desktop reminder grows from 5px to 7px and the entire navigation row owns the short actionable tooltip.
- Location list uses dense 56px two-line rows. Equal expanded segments share label/selection geometry; the filter has a permanent 40px slot, so switching tabs changes neither track width nor label centers. Geometry regression covers both selected states at 384/960 in light/dark, plus row height and whole-navigation tooltip bounds.
- Related suite: 30 passed (`build/polish-alignment-tests.log`), plus exact icon/text vertical-center regression passed (`build/polish-icon-center-test.log`); static analysis: no issues (`build/polish-alignment-analyze.log`). No protocol, storage or submit behavior changed. The unchanged all-suite baseline was 715 passed / 2 skipped in the preceding delivery.
- Existing Debug VM needed one hot restart after attaching (first hot reload reported zero libraries); process 27264 remains the same Windows app. No release build/install or Android physical-device verification in this UI-only follow-up.

---

# 2026-10-28 地点管理与工作区反馈修订

Final result: pass for implemented scope; external and physical-device gaps below remain unverified.

## Source and evidence

- Selected visual truth: `.tools/location-design/selected-campus-right.png` (1487×1058), refined from the user's selected first design with campus switching in the top-right header.
- Flutter capture: `build/place-ui-review/map-edit-960.0-false.png` (960×900, DPR 1), plus initial/saved states at 384/960 logical pixels in both themes.
- Combined comparison: `.tools/location-design/comparison-full.png`; focused list comparison: `.tools/location-design/comparison-list.png`. Source navigation cropped for the main-content comparison, aspect ratios retained; the composition sheet fits each image independently and is not a pixel-diff or identical-viewport claim. Fixtures have two rooms rather than the source's six.
- Native Debug window: viewed through Computer Use after hot reload at 1104×772. Real map tiles rendered; right-aligned campus control, room list and pending-room inspector verified. User data was not changed or submitted. The temporary pending selection was cancelled after inspection. Native screenshots were displayed by the tool, not re-exported from screenshot payloads.

## QA iterations and five fidelity surfaces

1. Initial capture exposed square CJK glyphs inside ListTile: the local title/subtitle styles inherited ListTile's independent font defaults. Fixed by using the app's bodyMedium/bodySmall styles. The post-fix combined comparison shows readable room names and metadata.
2. Post-fix review: no remaining P0/P1/P2 differences within the selected layout scope. The list/map split, selected tint, search, pending/located groups, upper-right campus switch and lower-right inspector are present. The mock's underline tabs use the app's existing segmented control; font size, Fluent icons and button geometry follow current product tokens. Zoom/pan use the existing map gestures; no simulated locator button was added. These are intentional component reuse choices, not missing functional controls.

- Typography: app's Chinese/Segoe families; 13px room rows, 11px subordinate status, 14px inspector heading, existing page-title token. Rechecked after font fix. Homework titles use one line with clip and softWrap=false, while detail titles remain complete.
- Spacing/layout: fixed 300px desktop list, 16px split gap, map fills remaining height. No page-level vertical stack of banner/map/form/list. At narrow widths, list and map switch instead of squeezing columns. Inspector and location draft respond to keyboard insets. Shared desktop heading uses a 44px minimum row height; homework filters sit in header actions.
- Colors: existing sea-teal tokens, faint list separators, selected surface, semantic location status. Dark illustrations preserve colors with reduced brightness/saturation and soft edge alpha, without inversion.
- Image quality: actual CampusMap tiles and markers are reused rather than embedding the mock's raster map. Widget tests deliberately intercept HTTP (400), so blank tiles/failure notices in those fixtures are not used as evidence of a live-map visual match; the running native window provided separate live-tile evidence. Existing sidebar/card paintings remain the original assets.
- Copy/content: actual schedule classroom names and custom locations only; building references labeled as approximate, not surveyed classroom coordinates. User selections cannot silently authorize automatic radar submission. Empty campus, pending location and save failure states remain explicit.

## Behavior and validation

- Latest-history footer uses the same currentCourseHistoryProvider and HistorySummary as HistoryPage, includes unsigned records and remains pinned below the independently scrolling task list. Removed the separate local-submit/history-cache scan.
- Course detail uses a compact location row, then one map with one selected point and no campus picker or other preset markers. Opening and returning both have verified intermediate heights during 240ms transitions. Legacy explicit binding retains mounted state across the picker and returns the selected result.
- Desktop notice dots sit at the far right with a reserved slot; mobile badges stay on icons. Settings/history toolbar buttons have outlines. Single-course rail reaches below the card and metadata icons align.
- Static analysis: `flutter analyze --no-pub lib test`, no issues, `build/followup-verified-analyze.log`.
- Full suite: 715 passed, 2 existing network-config tests skipped; `build/followup-verified-all.log`. Focused course/map run: 10 passed, `build/followup-course-final.log`. Prior failures in old UI finders, retained picker state and retap lifecycle were fixed, not ignored.
- Hot reload attached to the existing Debug VM; the original app PID 27264 remains. This turn initially needed one hot restart, then subsequent changes hot-reloaded successfully; final reload updated 16 libraries. No second daily app instance or release installation.

## Remaining limits

No trustworthy comprehensive three-campus classroom coordinate library was found in the checked attendance projects; see local `docs/research/53-classroom-presets-and-dark-artwork.md`. Building references remain approximate. Android physical-device behavior, authenticated attachment downloads and native continuous resize/frame performance are not revalidated by these widget tests.

## Implementation checklist

- [x] User-selected location layout and upper-right campus switching.
- [x] Compact course location, single-point map and two-way animation.
- [x] Header actions and single-line clipped homework titles.
- [x] Canonical latest history footer, timeline/icons and theme treatment.
- [x] Source/implementation combined visual review, font correction and post-fix comparison.
- [x] Running Debug hot reload.

---

# Earlier QA records (historical, superseded where this report differs)

# 地点管理与工作区体验 QA — 2026-10-28

## 地点与界面修订验收（2026-10-28）

- 全量：713 passed、2 skipped（原有网络配置项）；日志build/place-all-final.log。最终缓存时间捕获/内置点授权单元回归13 passed；最终页头及视觉/身份/设置聚焦47 passed；地图流程/说明附件截图5 passed。flutter analyze无问题；Windows Release构建通过。最终交付命令日志build/place-analyze-delivery.log、build/place-windows-delivery.log。
- 实际查看：build/place-ui-review下384/960浅深色的地点管理、保存后与作业详情截图；.tools/desktop-workspace下900浅色、1440深色、字号和DPR场景。检查了最终水彩滤镜和900窗口页头按钮一行排布；这些是隔离Flutter渲染及虚构数据，未接入当前用户账号或提交签到。
- 地点匹配覆盖全半角、空格、中文楼号、别名、跨校区同名歧义、自定义优先；显式内置ID可供后台reader使用，名字匹配本身不授权自动签到。课程详情和地图保持一个Dialog；新增自定义点后待补全立即消失。自定义增改删与旧存储兼容，内置不可改动。
- 未实测：在线高德瓦片（widget测试拦截HTTP返回400，截图仅验证标注/布局和底图失败提示）、真实平台附件下载及浏览器认证、原生双击/悬停/系统tooltip事件与Android真机。已编译不等于这些实机验收通过；无安装、发布或push。
- 官方来源、目录缺项和坐标边界记录在本地docs/research/52-campus-places.md，78个内置点仅代表楼宇参考位置；目录未覆盖西部片区等新地点，允许用户地图补全，不用校区中心猜测。

# Desktop interaction and identity QA — 2026-10-28

final result: passed

This gate covers the requested stable UI states and identity/detection contracts. Continuous native resize flicker remains an explicit acceptance limit, not a claim of complete elimination.

## Sources and comparison

- User references: `codex-clipboard-c313270d-4ddd-4942-bdc4-7af07c301f4a.png` (course menu), `codex-clipboard-b21e8321-11c2-4ddb-803d-ddbd1ea13a5e.png` (sidebar margins), and `codex-clipboard-273667fd-28ed-4061-ad1a-aca3f8cbbd07.png` (text-action padding), plus the written corrections.
- `.tools/identity-menu-comparison.png` puts the source and current course-action cluster together. Fixture course names/counts differ deliberately; comparison concerns arrow, menu width, control alignment and spacing, not a pixel-identical course-data clone.
- Actual widget renders: `build/desktop-ui-review/homework-course-menu-{320,384,960}.png`, `schedule-detection-{320,384,960}.png`, `.tools/monitor-typography/monitor-settings-*.png`, and `.tools/desktop-workspace/*-dpr*.png`.
- Renders load real CJK and bundled icon fonts. An initial capture used default test fonts for homework body text; it was corrected to the production AppTheme and recaptured before comparison.

## Findings fixed and rechecked

1. P2 arrow direction: account uses right-to-up; normal selects and disclosure controls use right-to-down. The half-turn behavior is removed.
2. P2 course menu geometry: fixed menu width follows the filter + gap + refresh group (142 logical pixels on desktop). Tests assert both menu edges equal the corresponding action-group edges, including a real course-page flow.
3. P2 focus residue: background pointer clicks outside the focused control dismiss its focus. Menu selection/Escape still return keyboard focus for reopening. The root-page regression presses Tab, closes the menu, clicks blank content and checks that trigger focus clears across six viewports/scales.
4. P2 layout: text links have 10px horizontal padding; sidebar illustration lives on the full-width background rather than inside control padding; settings group captions align to the card outer edge and row padding is consistent. Requested radar/QR footer is removed.
5. P2 settings behavior: the obsolete daily clock editor is removed. The form displays the selected identity's merged course windows for today, a clear no-range state and the automatic-only policy switch. 320/384/960 widths, light/dark and large text were checked.

## Identity and detection verification

- Academic sync resolves separate owner/assist credentials, IDS jar and JW cache. Sending and publication recheck target membership, management owner and session revision. A removed identity cannot publish a late result. Assist authentication recovery opens assist import rather than owner login.
- Restarted Windows Debug actually authenticated the selected assist and fetched term 20261: **3 courses / 7 schedule rows**. The live timetable was inspected. No attendance submission was performed.
- Student UUIDv5 uses the fixed app URL namespace and normalized student number across platforms/installations. Known identities migrate once; unknown student numbers preserve existing IDs. Migration updates the in-memory owner cache; parallel roster mutations preserve both identities. Durable rules: `test/fixtures/account_identity.md`.
- Automatic discovery uses the union of actual class windows, 30 minutes before/after; no timetable means waiting. Explicit manual list/engine requests bypass the time policy. Android messages distinguish explicit manual requests from automatic rescheduling. Old daily clock preferences no longer constrain the new policy.

## Native resize work and limits

The Windows host now clips the Flutter child surface, avoids full-parent invalidation and suppresses redundant GDI background erasure for the host/view. The clipping behavior follows [Microsoft's window-style documentation](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-styles). This addresses a concrete redraw path; it does not establish a measured native FPS improvement or prove that all flicker is gone.

The rebuilt Debug process was restarted and inspected with the real assist timetable. A shrink attempt produced no reliable size change. A later drag was rejected because user input was detected, so further pointer control stopped. There is no reliable continuous-frame recording of live resizing in this pass. Previous retained-tab layout-count regressions still cover skipped hidden-page layouts.

## Final checks

- `flutter analyze --no-pub`: no issues (`.tools/identity-last-analyze.log`).
- `flutter test --no-pub`: 699 passed; 2 network tests skipped by existing configuration (`.tools/identity-last-tests.log`).
- Final account/route/workspace subset: 55 passed; identity/storage subset: 12 passed; visual/policy subset: 22 passed; final course-menu capture: 3 passed; settings visual subset: 7 passed.
- Final saved-source Windows Release succeeded, exit 0 (`.tools/identity-last-windows.log`). Debug remains running with the final hot reload.
- No installation, publication or push. Android device behavior is not claimed as physically verified.

# 地图视角与浮层修复 — 2026-10-28

- 校区公开瓦片抽样：z18 返回正常图像；z19/z20 虽 HTTP 200，却返回 256×256 单色占位图。因此原生层级限制为18，最高允许本地放大到21；坐标计算精度不因瓦片放大而提升。
- 选点与视角状态分离：平移及缩放后点选只更新草稿和面板；点击列表中已有地点保留倍率并定位，切换校区重新定位。地图来源和 logo 控件在地图手势层外，移至右上角，展开内容也阻止点击穿透。
- 提示左/下与编辑面板右/下统一12px。标题旁显示六位小数的纬度、经度（GCJ-02），可选中复制。实际查看 build/place-ui-review/map-viewport-draft.png，确认坐标同行、右上来源控件和底部面板布局；另生成384/960宽度、浅深色地点流程截图。测试 HTTP 被拦截为400，截图不作为在线底图渲染证据。
- 验证：flutter analyze --no-pub lib test 无问题；地点地图流程、选点、桌面地点工作流和课表布局20项通过。新增真实指针回归断言来源控件不选点、20级选点前后中心/倍率不变、浮层边距及坐标文本。日志 build/map-viewport-analyze-final.log、build/map-viewport-tests-final.log。
- 当前 Windows Debug 已热重载（23 libraries）；未进行Android真机或全校区在线瓦片覆盖验收。

# GPA规则与成绩入口修复 — 2026-10-28

- 运行中的Windows Debug原日志：成绩应用入口页面200、成绩POST查询403。补请求头或仅初始化角色仍403；改用官方成绩appShow入口（4768574631264620），再初始化角色，同身份只读查询返回200及69条成绩。最终数据已按账号缓存；未复用抓包Cookie、未提交签到。短时诊断入口已完全移除，app.dart恢复原样；最终仅保留原有脱敏HTTP日志。
- 规则核查：2022本科生成绩管理办法第九/十一条及表1/2（https://gk.xmu.edu.cn/info/1065/25331.htm）；学分认定和转换办法第五条（https://life.xmu.edu.cn/info/1058/1030.htm）。两级制/P/NP、EX/DF/W/N/A不计入；F/0绩点计入；每次修读成绩均计入，优先于旧2018手册中间重修成绩排除说法。通识课程不一概排除，以有效教务绩点和认定标记为准，提供自选口径。XFJD是课程绩点，不除学分；保留荣誉绩点，字母均分按官方表2换算，指标显示两位小数。
- 范围含总绩点、具体学年、近1—6学年、近1/2/3/4/6/8个有成绩的学期和指定学期，包含夏季及短学期。课程分类/排除原因可见；切换范围不联网。旧版本缓存即使一天内也全量补齐新字段，失败保留缓存；UID、身份修订及会话守卫保留。
- 验证：成绩协议、规则、账号切换、教务课表、GPA界面及桌面工作区40项通过（build/gpa-rules-tests-final.log）；最终界面/缓存升级7项复核通过，含新增旧缓存全量升级回归（build/gpa-rules-visual-final.log）。最终flutter analyze --no-pub lib test无问题（build/gpa-rules-analyze-delivery.log）。桌面工作区回归断言设置按钮在记录右侧。
- 已实际查看build/gpa-ui-review/gpa-960.0-false.png和gpa-384.0-true.png，并生成其余两种主题/宽度组合。修正新增Chip/规则标题在隔离字体中的方框；实际指针回归覆盖学年切换、近学期数量、通识筛选、课程勾选及规则展开。截图用虚构成绩，未导出真实成绩。Android真机及其他身份在线成绩查询仍未验收。

# GPA实际学年与交互审阅 — 2026-10-28

- 本轮先运行隔离GPA界面回归并捕获修改前960浅色/384深色截图，保存在build/gpa-scope-audit/before-desktop.png、before-mobile.png；再查看本轮后的同宽度同主题总览与学年多选截图。原三项等重卡片在手机占用三行、规则说明先于列表；现在GPA为主、均分及计入学分为辅，列表按学期分组，规则说明下置。
- 流程1：总绩点→学年。只列实际存在的学年，支持多选合并；两学年样例中不存在2024选项，不再有“近1—6学年”列表。取消所有学年显示明确空态。流程2：近学期→数量，只列1到现有学期总数，切换在本地重算。流程3：课程勾选→恢复默认选择，门数、总览及通识筛选同步；长课程名通过公用截断组件补充全文悬停。
- 参考仅为固定源码：democard/xmu_assistant@bbcedf701f8b66200a5897767e0d14c7c6cef5fe。采用按学期分组和统计口径分离的思路；没有安装、运行或截取该应用真实界面，没有复制上游代码。它仅统计百分制，模拟换算C-为1.5，不能替代校方2022规则；本地模拟、已修学分和排名/证明作为后续参考，不在本轮新增。
- 检查：21项成绩规则/区域/身份缓存/接口及GPA界面回归通过，静态检查无问题（build/gpa-scope-tests-final.log、build/gpa-scope-analyze-final.log）。320/384/960浅深色六种界面实际指针回归覆盖多选、空选、近学期、通识、恢复默认、规则展开；生成总览与多选截图，并实际查看桌面前后及窄屏深色多选状态。没有发现溢出；未进行系统读屏器或Android真机验收，不能据此宣称完整无障碍合规。

# 教学区域聚合与研究生成绩 — 2026-10-28

- 11个用户提供的翔安区域点已内置（含补充确认的西部4号楼），保存原始6位坐标。主列表按学武/坤銮/文宣/西部2/4号楼聚合，不平铺ABC。地图18级以下聚合，点击楼宇或放大后展示区域；区域标签含楼名以防相邻楼宇ABC混淆。聚合中心是LatLng展示数据，不存在可提交的SavedLocation ID；显式区域选择仍保留精确坐标与身份授权。
- 真实指针回归：主列表没有A/B/C行；楼宇面板可展开子区；放大后出现具体区域；选B区后视角不重置，坐标24.605494/118.313825。后台读取同一ID返回B区原点而不是均值，协助身份不能借用主号配置。旧78楼宇目录及旧显式绑定兼容，没有把匹配结果自动授权为签到。
- 实际查看build/place-ui-review/building-overview.png、building-expanded.png、building-region-selected.png与build/gpa-ui-review/graduate-empty.png；测试环境拦截瓦片返回400，图像只验证标注/布局/面板，不声称本轮在线底图实测。末次扩大区域标签避免楼名省略；已有384/960浅深色流程回归继续覆盖。
- 主账号研究生身份由用户确认。真实只读验证本科入口转向403权限页，研究生成绩应用正常打开，POST xscjcx_by返回HTTP200及0条；用户抓包同样rows=[]/totalSize=0，hqjdxf空值。使用KCMC/KCDM、CJXSZ/CJ、JDZ/XF映射，已发布的真实非空研究生记录尚未出现，非空/重复修读/身份不符/格式错误以虚构样例回归。权限页只分类，不发出HTTP请求或扩大白名单；临时诊断及刷新挂钩已移除。
- GPA education随账号缓存；研究生完整结果不套本科近期合并，空列表可以替换旧数据。第一页缺模型或错误code不能伪装成空成绩；两级制等无效记录规则保留，研究生字母分数不借本科换分。空成绩切换到学年仍为正常状态，不报格式错误。
- 签到页非检测时段增加短说明，今日无课/缺课表保持原文案。候选清单按官方公共教学服务资料整理，学信楼/西二教学楼核实为西部2号楼别名；未提供坐标的候选不内置，漳州旧设施资料明确标记需当前课表核对。
- 验证：全量746 passed、2既有网络项skipped（build/region-graduate-all-tests.log）；最后定向33项（含新增权限页分类）通过，校区前缀/标注复核18项通过，研究生空态及GPA复核7项通过（build/region-graduate-delivery-tests.log、build/region-labels-final-tests.log、build/graduate-empty-delivery-tests.log）。最终flutter analyze --no-pub lib test无问题（build/region-graduate-last-analyze.log）。Android真机和研究生非空正式成绩未实测。

# 地点管理控件与聚合标注微调 — 2026-10-28

- 用户四张参考图：小屏返回按钮对比不足，筛选需要矩形选中底，地图标注数量及留白过多、上下锚点不一，左列表课程长名与状态混排。对应修复为不透明返回表面/边框/阴影、8px圆角筛选、高亮底与边框；聚合标注仅楼名，文字测量宽度，统一Alignment.center；以区域边界中点定位，学武接近B区，提交坐标不变。
- 左列表为28px楼宇图标底、单行标题、简短区域/课程数量、圆角选中态，不再逐行堆长课程名和重复“已定位”；待补全保留课程名，已定位课程全文可悬停查看。选择子区域仍高亮父楼宇。
- 实际查看build/place-ui-review/building-overview.png、building-region-selected.png、map-edit-384.0-false.png，检查紧凑标注、选中父行及不透明返回控件；既有浅深色/384与960工作流截图也已重建。Widget环境拦截瓦片HTTP400，截图只验证界面及交互，不作为在线底图证据。
- 初始相关18项回归通过；最后地图/点位9项复核通过（build/location-polish-delivery-tests.log）。全局静态检查无问题，末次5个变更文件定向静态检查无问题（build/location-polish-analyze.log、build/location-polish-delivery-analyze.log）。回归断言筛选矩形边框、返回按钮不透明及边框、聚合居中/无数量、区域几何中心，原视角保持和区域坐标测试继续通过。Android真机未实测。


# 地点管理课程面板与原楼宇中心 — 2026-10-28

- 根据本轮四张用户截图修订：缩小地图的分区楼宇使用原目录中的楼宇参考中心（含坤銮楼），放大后仍使用用户给出的精确区域点；无分区的西部教学楼保留用户坐标。聚合点仅用于显示，提交ID与坐标不变。
- 删除待补全筛选，切换组件占满原列表宽度。已定位课程地点面板直接展示课程；多分区按有课程的区域分组，省略空分区的状态行、箭头和大行距。无课分区楼宇保留紧凑区域入口；点地图上的具体区域只显示该区课程。已定位课程面板移除“补充区域位置”，自定义编辑及待补全流程仍可用。
- 实际查看 build/place-ui-review/building-region-courses-960.0.png 与 building-courses-384.0.png，确认桌面分组、窄屏直接课程列表及底部紧凑面板。截图使用虚构课程；Widget环境网络被拦截，截图不作为在线底图验证。
- 25项地点/选点/课程区域存储回归通过（build/location-course-panel-delivery-tests.log），覆盖384/960宽度、浅深色原有工作流、课程直列/分区、点击具体区域只显示对应课程、坤銮原中心及西部楼宇精确点。全项目flutter analyze --no-pub lib test无问题（build/location-course-panel-delivery-analyze.log）。Windows Debug成功热重载24个库，保留原开发进程；Android真机未实测。


# 地点列表范围与区域中点纠正 — 2026-10-28

- 本轮用户截图显示旧楼宇参考点偏左上；撤回上一版参考中心选择，使用完整区域经纬度边界中点。侧栏只有部分区域课程时，定位视角仍使用完整楼宇区域集合；区域精确坐标和提交ID不变。缩小标注补上15px定位图标，按图标+文字宽度计算，维持居中锚点。
- 课程地点列表仅列当前课程使用的地点，不再把闲置内置预设混入已定位列表；地图仍显示预设标注。无匹配课程只显示空态，不再显示A/B/C操作按钮；有匹配课程继续紧凑分组。自定义地点列表及补全流程保留。
- 实际查看build/place-ui-review/building-overview.png、building-region-courses-960.0.png、building-region-selected.png，核对定位图标、仅两个实际课程楼宇的列表、空态无按钮。Widget网络被拦截，截图不作为在线底图验收。
- 最终相关25项回归通过（build/location-course-only-tests-final.log），含浅深色384/960流程及课程区域存储；5个变更Dart文件静态检查无问题（build/location-course-only-analyze-final.log）。Windows当前Debug保留原进程并热重载；Android真机未实测。


# 桌面设置审阅、分层返回与待办 — 2026-10-28

1. 设置首页（已调整）：本轮先捕获并查看build/settings-before-desktop.png，看到桌面常用区重复提供侧栏课表、应用组混放外观/窗口/提醒/维护。随后按原组件体系重组，保留账户、地点与协助入口，去掉桌面重复课表入口；手机保留课表入口。修改后实际查看.tools/settings-polish/960-light.png，外观/关闭窗口两选择器仍等宽、右对齐；通知与维护单独成组。
2. 低频维护（可用）：实际查看.tools/settings-polish/960-light-about.png，更新和下载线路继续位于关于二级页，数据诊断保留二级入口；不把低频工具展开到首页，不增加没有需求的开关。设置测试覆盖320/960、浅深色、1.3倍文本、指针与键盘、外观保存和诊断复制。截图使用虚构账号；未验收系统读屏器或Android真机。
3. 分层返回（通过回归）：新增桌面早期Esc处理与鼠标后退键；只关闭菜单、再退页面，根层停留。根Navigator.maybePop与Tab的maybePop保留PopScope内部步骤，课表地图和窄屏地点地图先退内部视图。回归专门断言不可直接关闭的弹窗先回课程步骤、选择菜单与页面分开退、首页不关闭应用；额外鼠标按键不触发菜单外点关闭造成连续退两层。没有操控用户日常窗口验证这些动作，使用隔离测试。
4. 地点与待办（已调整）：取消地点搜索框，标注左右各9px，课程地图默认17级。已知楼宇聚合中心从完整内置区域集合计算，单一A区课程不能使聚合点移到A区；多教室同区字符串含混合括号可匹配B区，跨区/跨楼继续未匹配。实际查看build/todo-ui-review/todo-false.png和todo-true.png，课程名、单行省略标题、截止信息依次显示，48×64图标底与信息块对齐，34px实心文档图形提高辨识；仅从当前身份课程目录补齐待办课程名。

最终验证：地点/桌面工作区/选点25项通过（build/workspace-refinement-flow-tests.log）；设置/返回/待办/课程区域/缓存44项通过（build/workspace-refinement-controls-final.log），合计69项。flutter analyze --no-pub lib test无问题（build/workspace-refinement-analyze-final.log）。图形测试里的地图瓦片被拦截，不作为本轮在线底图验收。Windows当前开发进程热重载102个库成功；没有重启、推送或发布。


# 课表地点提醒热重载一致性 — 2026-10-28

- 检查本机Riverpod 2.6.1源码：debugReassemble只在debugGetCreateSourceHash变化时使Provider失效；本项目手写Provider没有该hash。地点管理直接调用新匹配函数，而未匹配列表可能仍保留旧派生状态。Shell.reassemble现在只使当前本地校园快照失效，连带重算分组和提醒；不清持久数据，不触发课程联网刷新。
- 新增真实reassembleApplication回归：同一Provider容器先保留旧未匹配项，切成“文宣楼(4号楼）B404、B405”后普通重建仍保留，执行热重载后变为空且导航提示消失。14项相关回归通过（build/place-warning-delivery-tests.log）；4种导航主题/尺寸复核通过（build/place-warning-tooltip-visual.log）。静态检查无问题（build/place-warning-delivery-analyze.log）。
- 提示为“有上课地点未定位，请在地图上标记”，课表入口为“X个上课地点未定位 / 打开地图”。已实际查看build/desktop-ui-review/place-tooltip-light.png，确认全文单行可见、指向地图标记操作；已生成深色版本。原始日常窗口没有被自动点击，当前开发进程成功热重载49个库。


# 设置控件统一与课表地点绑定闭环 — 2026-10-28

- 设置部分统一Fluent regular20图标，替换关于、诊断、通知与协助等页混用的Material符号；外观图标改为线性调色板，避免半实心圆造成粗细差异。SettingsSection内操作统一14px/500字重、10px圆角、18px按钮图标及36px桌面/44px触控最小高度，保持主操作填色、次操作描边；退出使用描边。实际查看.tools/settings-polish/960-light.png，确认外观图标、行入口与右侧控件的密度；浅深色设置截图均重建，视觉复核2项通过（build/location-binding-settings-visual.log）。
- 地点管理取消加号、自由空白选点新建及我的地点Tab，只保留课程来源。相同楼宇/区域去重合并，多个区域教室先拆区；全角括号按原输入显示。用户先选择未定位条目，再选坐标；名称只读，说明尽量与教务或导入课表一致。没有把已有个人数据删掉，也不修改全局预设。
- 新增严格的位置拒绝分类，排除网络、401/429、5xx、权限及活动结束等通用失败。桌面与Android自动任务持久化当前owner/user的失败点版本，活动仍只尝试一次；自动读取会拒绝已失败的点。错误优先排在地点管理，明确显示位置校验未通过。具体课次能从当前目录唯一归属时使用该地名，无法定位到教室的旧绑定单独列出；不误标同一门课其他区域。
- 保存校正必须选不同坐标；只更新既有绑定的坐标与地点引用，保留课程、课次及授权标记，既不添加新课程授权，也不打开自动提交。原样保存不能解除错误；旧反馈不覆盖新坐标。失败版本含坐标，避免清除旧记录时误删新错误；账号间、主/协助间独立。
- 隔离真实指针/持久化回归覆盖384/960宽度：错误在待定位之前、只读名称、绑定新坐标、清除错误、旧无地名绑定校正、预设坐标未被改写、已存在授权保留。实际查看build/place-ui-review/binding-errors-960.0.png和binding-correction-384.0.png；这些是虚构课程与模拟服务端失败，地图瓦片在Widget测试中被拦截，不能当成在线地图或真实签到成功证据。
- 本轮全量767 passed、2个既有联网配置项skipped（build/location-binding-final-all-tests.log）。此前完整回归发现全角括号显示回退，修正后全部通过；最后绑定相关18项也通过（build/location-binding-last-flow-tests.log）。全项目静态检查无问题（build/location-binding-final-analyze.log）。末次再收紧时间/权限范围及定位超时排除词，34项分类/自动签到回归通过（build/location-binding-classification-final.log），对应两文件静态检查见build/location-binding-classification-analyze.log。Windows当前开发窗口已热重载；Android后台代码已接入但未做真机签到验收，没有发起真实签到验证。


# 待办层级与Android真机体验构建 — 2026-10-28

- 用户截图三行等重内容难以区分，长课程名和作业名更明显。概览改为课程/截止的次级顶行与作业标题主行，使用独立轻边框卡片、40px方形文档底和加粗标题；日期标签省去重复“截止”字样，完整截止日期保留在提示中。课程和标题只截断时出现全文提示，不删减源文本，不改变作业点击入口。
- 实际查看build/todo-ui-review/todo-false-1.0.png和todo-true-1.3.png；浅深色及1.0/1.3字体四种组合重建。11项待办/桌面工作区回归通过（build/todo-hierarchy-final-tests.log），覆盖同行课程/截止、主标题单行、长按显示全文且不误触跳转、正常点击仍进入作业。静态检查见build/todo-hierarchy-final-analyze.log。
- 连接Android 16/API36真机（2410DPN6CC），已装应用为0.2.0/versionCode5。使用scripts/package-android.ps1 -NoPub构建当前源码release成功，约79.8MB（build/android-ui-review/build-release.log），版本标识沿用0.3.0+6，不是新发布版本。
- 从手机读取旧APK并与新APK比较证书SHA-256，一致；通过adb install -r覆盖安装成功，未卸载或清理数据。安装后查询versionCode6/versionName0.3.0，启动现有包成功，看到原账号及正常签到首页；实际查看build/android-ui-review/phone-home.png。刚启动时的加载中截图phone-current.png未作为验收页面。只观察启动和首页，未代用户点击签到或执行真实提交，也未宣称全部手机页面均已逐项验收。
- APK：dist/xmu-rollcall-0.3.0-android.apk，SHA-256 BC22C10AC2BAF5399C49A3F746381CC4AE496843E7E9F889F42AAD8D54DFFF83。手机使用触控布局，共享设置/作业详情/地图等更新随本次源码构建进入，桌面右侧概览仍为宽屏区域。Windows开发进程另行热重载，设备截图与APK均不入Git；没有推送或发布。


# 移动选择器、学院校区回退与待办详情 — 2026-10-28

- 地点管理窄屏右上校区、学期设置与课程关联移除原生DropdownButton/FormField，使用AppShellSelect，保留标题/字段标签及长文本裁切。384宽度回归验证初始翔安、打开菜单后切到漳州，且无布局异常。桌面继续页头右侧分段切换。
- 默认校区优先实际课堂地点，无可识别地点才参考学生学院名称。学院来源为已有initXsxx身份响应中的明确名称字段，不用开课学院，不新增请求；仅保存学院名称至当前uid课表快照。官方招生目录与漳州校区介绍核对常见学院；未知名称不猜测。旧缓存为空，需正常课表同步后补入；未宣称当前真实账号必然返回学院。回归覆盖教务响应提取、误用教学单位排除、旧快照兼容及账号隔离。
- 三处BottomSheet关闭顶部拖拽条并补齐内容顶距；课程详情及同层地图共用加深加粗的24px关闭图形与44px触控范围，课程标题行向上对齐。使用真实Fluent字体重建并实际查看.tools/timetable-polish/mobile-light-03-detail.png，确认顶部无条、关闭图形与标题同一行；另覆盖深色大字号及桌面布局。Widget地图瓦片请求由测试环境拒绝，不作为在线地图证据。
- 待办预览将单项和查看全部拆成不同回调，单项使用对应HomeworkItem打开HomeworkDetailPage。桌面真实Shell回归验证seed.id=3、详情返回；长按显示全文不误触，正常点击回传指定作业。查看全部继续进入列表。
- 72项聚焦回归通过（build/campus-ui-final-regression.log）；覆盖教务解析/缓存、校区与地点、课表弹层、选择菜单、作业详情和桌面导航。初次视觉运行曾因本地Material字体路径配置错误导致setUpAll失败，修正为D:/Dev/Flutter后重跑通过；最终渲染加入preview_fonts加载Fluent字体。
- Android已构建release并与现有APK核对签名相同，首次覆盖安装成功并观察正常首页（build/android-ui-review/campus-refresh-home.png），数据保留。Windows开发进程热重载110个库成功。最终学院元数据加载保护与联合学院名称补充后再次构建/安装记录见下。未执行真实签到。
- 最终静态检查无问题（build/campus-ui-final-analyze.log）；最终Android release构建成功（build/android-ui-review/campus-final-release.log，79.8MB），证书再次一致，adb install -r成功，versionName0.3.0/versionCode6，启动成功。最终Windows热重载23个库成功。保持现有账号与数据，没有推送、发布或执行真实签到。


# Android工具导航与移动视觉层次 — 2026-10-28

- 设计知识实际命中并阅读Engineering的20-主题/09-深色界面的氛围与信息层级.md和08-界面减法与任务模型.md。采用画布/卡片/控件的颜色角色、重要信息字号与分组，以及实际截图校验；不照搬视频中的紫蓝环境光、不增加占位工具或重复说明。本轮只读知识库，项目选择保存在本仓库。
- 修改前实际查看build/mobile-style-review/settings-before.png：白色页面和白色分组只有很浅的线分隔，账户权重与普通行相近，图标偏小。移动画布改青灰、内容维持白色，深色区分画布/卡片/控件；个人页账户摘要增大，常用入口提供36px图标底座，按钮与选择菜单使用单独底色和边界。实际查看.tools/settings-polish的384-light/dark与320-dark，确认长描述可换行、大字号不挤压操作；最终副本build/mobile-style-review/settings-after-light.png、settings-after-dark.png。
- 安卓底栏为签到/作业/工具/我的，工具复用campusTools身份及独立Navigator；桌面文案统一工具。圆角选中底色和Semantics.selected保留更新点在图标右上，更新状态切换前后导航尺寸和位置一致，返回流程不变。工具页仅GPA真实入口，窄屏卡片填满内容宽度；实际查看build/mobile-style-review/tools-320.0-false.png，320宽1.3字体验证点卡片进入GPA、返回恢复工具页，另覆盖384宽及深色。
- 首次窄屏大字截图发现PageScaffold固定页头高度造成8px底部溢出；改最小高度后重建并复核同一截图。选择菜单回归中的默认颜色断言同步新移动控件角色，悬停、键盘、选择、Esc与边缘定位断言继续执行。辅助文字在新增移动语义表面的对比测试通过，不据此宣称整应用无障碍认证。
- 签到触控工具栏刷新/记录/设置统一44px底色和边界、设置最右，复用Fluent图标；通用Panel与二级页按移动画布显示，桌面宽屏画布与密度沿用原规则。
- 74项相关回归通过（build/mobile-style-final-regression.log），覆盖四Tab懒加载、工具GPA往返、浅深色设置、更新点、选择菜单键盘/悬停、课表、作业详情和桌面工作区。全项目flutter analyze无问题（build/mobile-style-final-analyze.log）。
- Android最终release构建成功（build/android-ui-review/mobile-style-final-release.log，79.8MB），证书SHA-256与原安装一致，adb install -r成功、启动命令成功；沿用0.3.0+6，不是发布新版本，不清数据。随后只读截图显示用户正在打开手机控制中心，已拒绝作为页面验收证据并删除该临时截图，没有操作用户控制中心；页面视觉依据为隔离Flutter渲染，未宣称真机逐页验收。Windows现有开发进程热重载100个库成功。未执行真实签到，没有推送或发布。


# Android地点单顶栏与手势条间距 — 2026-10-28

- 地点管理的单栏列表/地图共用同一顶栏：初始地点管理，选地点后地点列表，地图内浮动列表返回入口隐藏。顶栏返回与系统返回都执行showList，回到列表再按返回才按原路由离开；宽屏两栏不改标题，独立嵌入组件仍可保留自己的返回入口。校区变化后的地图状态用帧后回调同步，不在父组件构建期间setState。
- 校区选择器增加inToolbar呈现，背景32px、外部上下各6px可点击留白，总触控高度44px，48px顶栏内可见上下各8px边距。普通选择器高度与菜单键盘/关闭行为保持原规则。实际查看build/location-header-review/list.png与map.png，确认标题切换、地图内没有第二个返回按钮，校区控件和标题居中；隔离测试不加载真实地图瓦片，空白地图不作为在线地图验收。
- mobileNavBottomTrim由8改为2，有系统手势安全区时增加最多6px留白，仍只计算一次viewPadding，不受键盘viewInsets影响。24px模拟手势区下，底栏总高为56内容+22留白+1边框=79，键盘打开后高度保持一致。更新点位置和菜单关闭回归继续通过。
- 54项聚焦回归通过（build/mobile-location-header-verified-tests.log），含顶栏/系统返回、校区切换、保存坐标、同层地图详情、Esc、表单选择菜单与更新点。首轮旧测试仍查找已移除的原生下拉和地图浮动返回按钮，已同步新契约；新底栏高度断言补计原有1px边框。
- Android release构建成功（build/android-ui-review/location-header-release.log，79.8MB），证书SHA-256与原包一致，adb install -r成功、启动命令成功；保留原0.3.0+6与账户数据。真机未执行签到；页面几何与返回行为为隔离渲染和自动化回归证据。Windows开发窗口另行热重载，最终状态见后附记录。
- 最终flutter analyze无问题（build/mobile-location-header-final-analyze.log），Windows现有开发进程热重载95个库成功；没有重启或清理应用数据，没有推送或发布。


# 安卓刷新入口减法与无背景Tab强调 — 2026-10-28

- 签到触控工具栏移除刷新，仅保留账号、记录及设置，宽屏桌面刷新保持；作业Tab在Android/iOS主题下不显示姓名/刷新行，原下拉刷新与缓存/身份逻辑不变。AppRefreshButton触控状态去掉背景和边框，保留点击范围、旋转反馈及原刷新回调，覆盖GPA和课程作业页。
- 底部Tab移除选中背景块，选中图标采用同语义实心Fluent版本（我的仍为人物）并与文字同用primary；图标下方2px间距，不再有30px底板带来的额外空隙。按压仅轻微透明度反馈，原手势条间距和更新点保留。实际查看build/desktop-ui-review/nav-mobile-light.png，确认图标/文字整体强调、无背景块；图中央是隔离测试占位，不作整个业务页验收。
- 作业列表和课程作业列表全部原clip单行文本改ellipsis；课程信息和摘要已用ellipsis的继续保留，数据不截短。实际查看build/desktop-ui-review/homework-hub-384.png：顶部不再出现账户/刷新行，长历史作业标题出现省略号，详情仍可打开。该隔离测试有debug banner，非发布截图。实际查看build/gpa-ui-review/gpa-384.0-false.png，右上只有刷新图标、无圆角背景。
- 83项相关回归通过（build/mobile-simplify-final-tests.log），覆盖320/384/960布局、作业详情/课程全部入口、账号隔离与刷新节奏、导航更新点、GPA及桌面工作区。首轮测试补漏图标import、恢复未选中我的Tab仍为regular图标的正确断言后重跑通过。全项目flutter analyze无问题（build/mobile-simplify-final-analyze.log）。
- Android release构建成功（build/android-ui-review/mobile-simplify-release.log，79.8MB），新包证书与原包一致，adb install -r及启动成功，沿用0.3.0+6并保留账户数据。Windows现有开发进程热重载100个库成功。视觉证据来自隔离渲染，未声称真机全部页面已逐项验收，未执行真实签到；没有推送或发布。

## 2026-10-28 安卓适配层与交互一致性审查

- 范围：地点管理列表→地图→坐标绑定/校正，校区选择，课表与叠课，GPA、作业课程筛选、签到历史、设置与关于页。先捕获本轮修改前截图，再修改和复核；没有把隔离截图当作真机业务验收。
- 依据：Engineering《界面减法与任务模型》《深色界面的氛围与信息层级》；Flutter adaptive best practices/input、Android touch target指引。采用按任务区分组件角色、语义表面和共享触控尺寸，不另造一套页面主题。
- 实际债务：移动选择器原先复用桌面锚定菜单并叠加inToolbar补丁；页面又重复决定触控/布局；地图外层padding与弹层inset相加造成屏幕边距不等；视图切换混用桌面胶囊；32/36/44尺寸散落；关于页URL换行导致同组行高不齐。并非单独改一个圆角就能解决。
- 统一规则：AppMobileUi集中56顶栏、48触控目标、16内容边距/面板圆角；触控呈现和分栏布局独立。移动顶栏用文字+箭头选择入口，选择从底部展开，有标题/当前勾选/关闭，无拖拽白条；长列表打开定位到当前项。课表、GPA等视图切换改文字和下划线；桌面保留原锚定菜单和分段轨道。
- 地点管理：手机地图铺满可用区域；绑定面板左右下16，内容过高可滚动；320×640、1.3倍文字、键盘260场景保存操作仍可到达。列表去掉全高白色嵌套容器，保留行层级和选中态；单一顶部返回逻辑不变。坐标绑定、地点匹配、提交逻辑未修改。
- 交互：补全选择弹层的返回、关闭全部、调用组件销毁、当前值更新时清理；退出后不调用失效context；清理空闲弹层主动安排帧；打开选择先释放输入焦点。模态弹层遮罩会阻止点击底部Tab，测试改为程序导航验证路由清理，不将遮罩行为误判为Tab缺陷。
- 细节：关于URL仅显示一行但复制完整值；课表叠课切换按钮在手机上改为顶部预留空间，避免标题被挤成逐字竖排；刷新入口保持手机无背景样式；已有底部Tab文字/icon强调、无背景的约定保留。
- 证据：build/android-consistency-review/before/{location-form,gpa,settings}.png；after/{location-form,campus-sheet,gpa,settings,timetable}.png。实际查看前后设置、绑定表单、GPA、课表和校区弹层。早期课表缺字体、弹层截图未覆盖root overlay均被拒收并重新捕获；最终校区图关闭debug banner。测试地图屏蔽网络瓦片，仅验证控件与几何，不据此宣称地图网络已验证。
- 回归：build/android-consistency-complete-tests.log全量780通过、2跳过；build/android-consistency-complete-analyze.log无问题；另有选择弹层生命周期、旧移动断言更新、地图键盘边距回归。最终干净校区截图单项测试再次通过（build/android-consistency-clean-preview.log）。早期Ink不支持constraints的编译问题及旧宽度断言均已修复，最终验证在修复后完成。
- 交付：build/android-ui-review/android-consistency-complete-release.log构建release成功79.8MB，0.3.0+6；证书SHA256与原包一致。设备427b338f执行adb install -r成功并启动，未清数据。Windows已有开发进程热重载49/3261库成功。本轮没有执行真实签到、推送或发布；真机各页的实际观感仍以用户使用反馈为准。
- 维护边界：本轮抽离了移动呈现规则，地点管理仍有较大的业务Widget；未为纯拆文件扩大改动。规格/验收/架构和ANDROID_UI.md已同步本地docs，该目录按仓库策略忽略，不强制提交。

## 2026-10-28 手机校园视觉第一阶段：签到首页与我的

final result: passed（源码实现、隔离视觉与交互回归）；Android真机安装/逐页观察尚未执行：本轮后半程ADB未发现设备。

- Git起点干净，遵照用户“改之前提交”建立c2c4cff检查点（上一稳定实现0c6702e）。本轮以用户认可的图1顶部+中部减法稿和待签到稿为目标；不重新选择图2/3，也不延伸成营销页或桌面改版。
- 目标保留在.tools/mobile-campus-reference/idle-and-settings.png、active.png。前者是双页概念板，不能把整张宽度当单页宽；后者853×1844与390×844手机视口基本同宽高比。对照按单页内容/逻辑宽度看构图和层级，不声称高分辨率生成图与真实字体逐像素相同。真实逻辑视口390×844，窄屏320×844、文字1.3倍；没有画设备状态栏或伪造系统安全区。
- 资产：内置ImageGen生成并实际保存assets/illustrations/campus_header.png（约1.34MB），核心提示为“右侧厦大风格橙瓦教学楼、浅青绿水彩、左上及底部透明留白、无任何文字/UI”，参考选定修订稿。该图为校园氛围插画，非学校官方实景证明。标题、按钮、账号、课程均为真实Flutter组件，图像排除语义和点击；深色复用亮度/饱和度处理。
- 构图：MobileCampusHeader复用同一顶图，主体无重复白卡；手机20水平留白与选定主页方向相符，地点管理等二级页原16规则不变。主卡保留18内边距，课程/待办以16/15标题和13辅助文字组织；保持必要48触控目标，不为强行一屏塞满而缩字。教室长名称分行显示地点/时间，较目标横排有意调整。长页可滚动，上次签到在内容末尾而不遮挡任务；短页靠近导航上方。
- 签到：空闲、待签到、运行中、完成、长标题/错误和身份切换沿原状态源呈现；主卡“去签到”进入原数字/定位/二维码流程。数字码预填回归确认入页repo.calls=0，检查后才提交；完成按钮禁用。手机主卡不常驻人数与课堂参考，参考仍可按需由课程菜单展开。检测启动/停止保留在有活动的顶部账号行；时段外和无课仍由原检测窗禁用，不增HTTP定时器或自动提交授权。
- 课程/待办：CampusContextView.mobile使用原磁盘快照，当前/下一课时间线无卡片和状态徽章；位置/时间icon按行高居中。只展示最近一项待办，课程/标题分别单行省略，点击进入原详情，查看全部进入作业。历史按服务端签到历史最新非占位记录显示，未签到记录不被较早成功记录替代，账号切换沿原Provider隔离。
- 我的：真实账号标题/可用身份信息，未提供校区时不伪造“翔安”；常用、应用两组无重复说明和图标底块，外观整行可点并有键盘焦点，主题持久化及取消正常；账号管理面板保留退出入口，关于保留新版本标记与原二级页面。四个底部Tab仍只强调icon/文字，无选中背景。
- 实际查看并同目标对照：build/mobile-campus-design/{idle,active,running,done}-light.png及dark对应图；long-dark.png是320宽1.3倍文字的长课程，不出现横向溢出，待办/历史滚动后可操作；.tools/settings-polish/mobile-account-light.png和dark.png及384-light.png。修正了早期未等待图片解码的空顶部截图，以precacheImage后的截图为最终证据；最终去签到箭头在文案后。
- 交互与功能：build/mobile-campus-actions-final.log相关45项通过；build/mobile-campus-settings-final.log设置17项通过；build/mobile-campus-delivery-captures.log移动状态10项通过。全量最终build/mobile-campus-verified-all-tests.log为792通过、2跳过；build/mobile-campus-verified-analyze.log无问题。首次全量在编辑数字预填回归期间编译旧版本而失败，最终在源码冻结后完整重跑通过，不将早期结果当完成。
- 构建：build/android-ui-review/mobile-campus-verified-release.log release成功80.9MB，仍0.3.0+6，最终dist/xmu-rollcall-0.3.0-android.apk；签名SHA256为7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5，与前版一致。Windows现有开发进程热重载19/3263库成功。ADB设备列表为空，已向用户询问重连/先交APK，未卸载、未清数据、未在真机提交签到、未推送/发布。
- 残余P3：真实Android字体与系统上下安全区仍需要接机逐页观察；此处已通过布局、隔离渲染及签名构建，不能代替用户真机观感。背景资产对小尺寸解码使用cacheWidth1200；不增加模糊或持续装饰动画。课表/GPA等二级页沿上轮统一组件，未宣称本轮全部手机页面已重新设计。项目规格/验收/架构/功能台账已更新本地docs，沿仓库忽略策略不强制提交。

## 2026-10-29 安卓覆盖安装补验

用户确认手机重连后，ADB识别设备427b338f（2410DPN6CC）。对上一阶段最终APK再次验证签名一致，执行adb install -r成功并am start启动；安装版本0.3.0+6、targetSdk36。未卸载、未清除应用数据。此项解除上一记录中的“设备未连接，尚未安装”限制；不等同于真机各业务页面已逐项视觉验收，未执行真实签到。

## 2026-10-29 状态栏色带与手机内容层级修正

final result: passed（隔离视觉、系统区域像素回归、完整测试和覆盖安装）；未把本轮手机合成截屏作为业务页视觉验收。

- 用户指出状态栏区域与下方颜色不统一、整页缺少层级。源码证据：PageScaffold安全区绘制mobileCanvas，MobileRollcallHome与移动我的页内层却绘制content；根页没有AnnotatedRegion，二级页才设置系统栏样式。该底色分裂和同等权重的裸列表是本次修复范围。
- 根页现在统一声明透明状态栏/手势导航区和匹配背景的图标明暗，关闭系统强制对比色带，继续只避让一次SafeArea。pageBackground按Android/iOS平台或桌面窄屏选移动画布，横屏/大屏不会因为宽度变大切回桌面白底。首页、我的正文使用同一mobileCanvas。
- 内容层级收敛为画布/独立签到操作/课程与待办内容组；课程和待办共用一块surface、组内轻分隔，组标题14辅助色低于课程16主文字。我的常用/应用各一块surface，16圆角/内边距、20外边距，不给每行再加卡。顶图透明度浅色.42、深色.28，降低与文字和控件争抢。历史仍在内容底部，Tab高亮、检测规则、身份隔离、提交确认不变。
- 视觉证据：build/mobile-hierarchy-review/after/{home-light,active-dark,settings-light,settings-dark}.png；实际查看浅色首页、深色活动、浅深色我的，校验分组、对齐、文本层级和边距。第一次设备截图虽在采集前窗口信息指向本应用，实际出现其他界面/浮层，已拒收并删除本地与设备临时图片，未展示为本产品证据。后续以隔离生产Widget渲染和像素测试验收，不再凭焦点元信息抓取用户画面。
- 回归：mobile_page_insets_test对浅深色32px顶部安全区取真实RGBA像素，验证顶部与正文画布像素相同、内容只偏移32px，透明系统栏/图标明暗正确。首轮截图Future处于测试假时钟导致等待，终止该任务并将toImage包在runAsync后重跑通过；不把卡住的首轮当完成。
- build/mobile-hierarchy-review/focused.log相关27项通过，insets-fixed.log新增2项通过；all-tests.log最终全量794通过、2跳过，analyze.log无问题。规格、安卓视觉契约和功能台账已同步本地忽略docs目录；CHANGELOG记录用户可见效果。
- android-release.log release构建成功80.9MB，最终dist/xmu-rollcall-0.3.0-android.apk仍0.3.0+6。核对SHA256证书与前版一致后，对427b338f执行adb install -r成功，保留数据；没有启动/切换用户正在使用的其他界面，没有执行真实签到。Windows原开发进程热重载97/3263库成功。Android系统栏最终实机观感仍待重新打开应用观察，不用隔离测试代称真机逐页验收；未推送/发布。

## 2026-10-29 手机等高顶区、日期与摘要条目修订

final result: passed（隔离渲染、几何和交互回归、构建/覆盖安装）；未声称真机每页视觉已逐项确认。

- 用户要求签到/我的顶部同高、背景同大小/位置、日期在标题右侧，并改善课程/待办。原图随child撑开，两页不同Padding和内容高度导致画幅不一致。本轮让MobileCampusHeader按相同宽度/字号规则提供184基本高度、窄屏加40、大字每1倍加72（scale限制1–2），图片统一fill/cover/bottomRight，与活动状态或账号说明无关；我的去掉额外垂直16，内容20内边距居中。
- 首页日期紧随签到标题并共享文字基线，普通宽度显示完整月日，窄屏/大字号简写月/日而保留完整语义。两页背景区到主体20、主体组间20，课程底8，使空白按共同节奏分配，不靠图片拉伸填空。系统栏与正文底色的上一轮修复保持。
- 当前课程为无边框轻底色选中区，下一课程透明；时间/节点/课程首行对齐，位置/时间icon保持居中。初次渲染发现320宽1.3字号的10:10换行，已让时间列随字号增宽并强制单行；最终截图已复查修正，非忽略视觉缺陷只保留通过断言。
- 待办为44蓝色文档标识、左侧两行课程/作业名称、右侧两行截止日期/时间；各名称单行省略，日期完整提示保留。点击仍进入该条详情，未改作业/缓存/账号/提交协议；桌面摘要原布局保留。
- 实际查看build/mobile-header-rhythm/after/home-light.png、settings-light.png及long-dark.png，另有生产状态浅深色截图在build/mobile-campus-design。两页正常顶图在相同390视口呈现一致；长内容页面可滚动看后续待办/历史，不压缩大字体到一屏内。几何回归对不同内容的顶区和图片尺寸/相对偏移作直接比较，覆盖320/390宽和1/1.3/2倍字号6种组合；生产首页验证日期在标题右方、时间单行。
- focused-final.log相关39项通过；all-tests.log源码冻结后全量800通过、2跳过；analyze.log无问题。android-release.log release构建成功81.0MB，仍0.3.0+6，核对原签名后对427b338f执行adb install -r成功，保留数据；没有执行真实签到或切换用户其他应用，没有推送/发布。桌面现有开发进程热重载4/3263库成功。
- CHANGELOG与本地规格/验收/安卓契约/台账已同步，docs继续遵循仓库忽略规则。该轮没有新增图片资产，仅统一已有图片的布局边界。

## 2026-10-29 Android顶图上移与浮动导航/校园助手/课程收纳调研

final result: passed（本轮已实现的Android顶图修复）；浮动导航、全局搜索、全天课程合并与收纳仍为调研方案，未宣称已实现。

- 用户提供浮动四Tab+独立搜索截图及Sticky Stack参考，并强调只改Android。顶图由于素材透明天空而偏低，本轮仅在Theme.platform为Android时将绘图区top延伸至-60、bottom仍为0，原顶区裁剪；文字/按钮/顶区等高规则保持。Windows分支仍top=0，几何回归明确断言，不改变桌面样式。
- 实际查看重新捕获的build/mobile-campus-design/idle-light.png：建筑上沿提高到标题区域附近，下沿继续贴顶区底部，两页共用同样规则。tests.log相关39项通过，其中Android/Windows×320/390×1/1.3/2几何组合12项；analyze.log无问题；android-release.log release构建成功81.0MB，签名与前版一致。验证后的APK已对427b338f覆盖安装成功并保留数据；未执行真实签到或切换用户其他应用。
- 调研复用了Engineering《界面减法与任务模型》《界面动效自然度调整与回放检查》，知识库没有可直接采用的该款导航/课程收纳实现，公开参考区sliver检索无命中。联网补读Apple浮动Tab与search role、Flutter SliverPersistentHeader/BackdropFilter、sliver_tools README及liquid_glass_renderer要求。本机Flutter3.44，所读玻璃库最新预发布要求3.47和预览GPU API，建议先轻磨砂且不升级SDK。没有添加依赖。
- 校园内容查到信息与网络中心的2026新生服务指南及信息学院分本科/研究生的问答手册；建议搜索结果以应用功能/帮助、当前账号缓存、带来源与适用范围的官方指南分组，后续自然语言问答另定来源更新与模型边界。未抓取/复制个人凭据，不调用外部模型问答。
- 课程方案建议上方不变，下方合并课程和签到以避免同一课程重复；需扩展现有仅current/next的摘要为全天课次。下课与签到完成独立，待处理活动不得因动画而隐藏，不明确匹配的活动单列。两种收纳已用英语10:10–11:50例子向用户解释：时间/状态触发默认收起，与滚动距离触发视觉压叠是不同维度；用户尚未选定，不实施相关主页面改写。
- 具体参考：https://github.com/Kavantix/sliver_tools 、 https://github.com/Fayis2021/collapsible_cards 、 https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html 、 https://inc.xmu.edu.cn/info/1431/9562.htm 、 https://informatics.xmu.edu.cn/welcome/index.html 。collapsible_cards只读README，目录访问/API限额/raw404导致内部源码未核；不声称它是成熟生产方案。完整调研在本地忽略目录docs/research/android-navigation-search-timeline.md，未回写Engineering或强制提交docs。

## 2026-10-29 Android检测融入顶部、内容上移

final result: passed（源码、隔离视觉、相关回归及签名构建）；未声称本轮真机各页已逐项视觉验收。

- 用户确认背景位置可用，只要求签到/我的顶区内容向上、检测状态/开始操作融顶。MobileCampusHeader仅Android将child从centerLeft改topLeft，20内边距、184与字号/宽度增高规则不动，图片top=-60/bottom=0完全不变；Windows仍centerLeft且图片top=0。
- Android首页账号选择与检测操作同一Wrap行，账号宽144保证常用姓名清晰；下方灰点/单行状态处理尚未检测、时段外/无课、切换加载与失败。未登录和切换重试也融入顶区。运行时由既有检测控件呈现倒计时/停止，避免重复状态行；运行优先于列表加载，即使刷新列表为空且isLoading，停止检测仍可使用。原监控权限、时段、退避、身份守卫和提交确认逻辑未修改。
- 正文移除Android空闲/加载/未登录的重复状态卡，课程/待办前移；实际签到任务卡与获取失败重试保留。非Android继续原白色状态卡与原顶部控件，桌面页面不调整。
- 实际查看build/android-header-controls/after/{home-light,running-light,settings-light,long-dark}.png及生产状态浅深色截图。顶部文字较上一轮前移，画幅和建筑位置保持；小屏/1.3字号不横向溢出，图像不是静态UI截图替代真实按钮。
- delivery-tests.log相关76项通过，包括Android/Windows顶图几何与顶部锚点、日期与检测入口位置、主题/登录/账户管理、无课时段限制、QR路由/账号隔离，以及运行中AsyncLoading不挤走停止操作的新增断言。20.00000000000003与20的浮点误差改为.01容差；一次补丁误命中状态字符串分支造成的编译失败已修正，最终测试在修复后的冻结源码上重跑通过。
- delivery-analyze.log无问题；delivery-release.log构建release成功81.0MB，仍0.3.0+6。最终包签名与前版一致，已对427b338f覆盖安装成功；未卸载或清数据、未执行真实签到、未切换用户其他应用、未推送发布。只做Android呈现，不对桌面运行实例作热重载。
- CHANGELOG和本地忽略docs的规格/验收/台账/Android契约已同步。浮动导航/全局搜索/全天课程收纳仍为上一轮调研，不混入本次修改。

## 2026-10-29 Android顶区、首页减法与浮动导航

- 范围仅Android，Desktop延续现有布局；我的/签到共用168基础顶区，窄屏及大字适配增高，图像top=-76/left=18/right=-18，主体随顶区上移16。我的为整行账户摘要；账号切换去外框，检测主操作靠右，运行倒计时/停止同组。运行中列表AsyncLoading仍可停止。
- 首页取消待办及上次签到，仅Android不订阅历史摘要；桌面待办及记录布局保留。四个首页显示浮动四Tab和独立搜索，二级及更深页面隐藏；搜索根路由不重复底栏，返回恢复原Tab。公共嵌套路由观察器驱动底栏，新增数据诊断/返回及搜索/返回回归。
- 作业角标读取当前身份本地待办镜像及已知提交状态，排除关闭/到期/已完成，按课程活动去重；无缓存不显示数字，不额外挂载联网扫描。已知提交状态刷新后修订信号联动，身份切换加载阶段隐藏旧数字。新增Provider隔离、去重、到期及提交回归。
- 搜索提供本地功能/使用帮助、当前身份缓存课程与作业和4个官方指南入口；不访问外部AI、不发送搜索词，作业结果进入该条详情，课程结果标明在课表中查看。身份变化清空查询，个人结果点击有身份守卫。
- 实际查看build/mobile-campus-design/idle-light.png、running-light.png、long-dark.png以及.tools/settings-polish/mobile-account-{light,dark}.png：中文字体、浅深色、窄屏大字和新底栏已复核；搜索截图build/android-masthead-polish/search.png字体最初缺失，补测试专用ListTile字体映射后重新生成并实看中文结果。截图使用生产控件和隔离数据，未声称真机所有页面均已目视验收。
- final-analyze.log无问题；导航聚焦回归nav-regression.log 12项通过，home-only-nav.log 7项通过，搜索字体重渲染1项通过。先前全量807通过/4失败源于旧导航尺寸断言与零数字仍构建Badge，已修正并重新运行完整套件，不隐藏失败。
- final-release.log构建Android release成功81.1MB，仍0.3.0+6；校验既有证书SHA256一致后对427b338f执行install -r成功。未卸载或清数据、未执行真实签到、不接管用户其他应用，未push或发布。构建中的既有Kotlin插件迁移提示不阻止当前构建。
- CHANGELOG及本地忽略docs的规格/验收/台账已同步；不强制添加docs。全天课程收纳仍留待后续，未在本次擅自改写。
- 最终delivery-tests.log完整套件812项通过、2项既有跳过，无失败；delivery-analyze.log无问题。按新要求，原先3项Android二级页点击Tab的旧回归改为通过平台导航入口验证同样的草稿/忙碌守卫，identity-final.log 35项通过后又重跑完整套件。新增首页/二级页底栏显隐回归同时通过。

## 2026-10-29 维护阶段1
规则与四阶段计划已写入本地忽略的AGENTS.md和docs/spec/ROADMAP.md，未修改忽略策略。新增共享作业缓存读取/合并，角标/摘要/搜索能读取课程接口独有作业；Overview写入课程镜像同步修订。新增远端课程缓存清理服务，覆盖教务/成绩与刷新标记并失效内存；用户手工安排/日期/地点保留。
stage1-tests.log相关31项通过，含真实缓存/Provider的课程独有任务与所选身份切换；stage1-focused-analyze.log对9个修改项检查无问题，CHANGELOG结构检查通过。全库分析仍在运行，最终阶段再执行完整检查。本阶段无协议或外观变更，未构建安装。

## 2026-10-29 维护阶段2：检测范围边界
DetectionWindow仅保留区间模型/运算与异常；DetectionWindowStore负责原键名的读取/保存/旧偏好归属，detectionWindowProvider单独接入账号状态。所有使用点改显式导入，不通过模型重新导出Provider。依赖遍历确认MonitorEngine只传递依赖4个Dart文件、不再到达认证或platform，区间模型无项目依赖。stage2-tests.log 80项通过（含身份隔离、旧偏好、时段、忙碌/草稿及QR），stage2-verified-analyze.log无问题。全库分析曾扫到上轮build内的临时审查探针并报测试专用API位置警告，已删除该自有临时文件，未通过修改分析配置屏蔽警告。

## 2026-10-29 维护阶段3：刷新职责与明确状态
作业页取消_lastCheckAt/_lastCheckIdentity/_checking，Overview统一负责有效期和在途合并，ensureFresh返回本调用是否完成检查，避免页面重复刷新提交状态/助教任务。页面仍负责可见性、前后台和计时触发。可见性回归现在调用真实Overview刷新算法，仅替换数据边界并记录实际检查次数。签到顶区通过outsideDetectionWindow接收明确状态，取消根据中文文案contains反推。
stage3-verified-tests.log 65项通过，新增结果契约断言后stage3-unit-final.log 9项通过；stage3-analyze.log对相关7项无问题。保留现有界面与提交/身份约束。

## 2026-10-29 维护阶段4：呈现方式与读取入口
检测按钮从4个可任意组合的布尔开关改为实际使用的MonitorControlStyle，动作流程/布局不变。搜索功能与官方指南目录移到campus_search_index.dart，个人结果导航复用同一身份边界，删除无效图标条件。GradeRecord构造时解析学分、绩点和数值成绩并固定原始快照；计算使用typed fields，保留本科字母分数、研究生、合格制、N/A与荣誉绩点规则，缓存格式不变。
final-tests.log全套815项通过/2项既有跳过（最后补充的清理页回归随后单独验证）；final-analyze.log无问题，stage4-grade-tests.log 20项通过，final-captures.log生产组件11项通过。已实看浅色首页及窄屏深色长内容；idle-light/idle-dark与改动前SHA256分别相同，证明样式参数整理保持这两种画面逐字节一致。未执行真实签到/联网成绩查询，未操作日常窗口或重建安装包。

## 2026-10-29 沿途修复：清缓存覆盖协助账号内存
显式清理远端缓存改为invalidateRemoteCourseMemoryFromWidget，覆盖各账号的活动列表、目录、历史与先验；登出仍沿用原主号失效范围，不删磁盘。移除仅用于转发invalidate/clearSeen的一次性包装，两个入口直接表达各自清理范围。新增SettingsDataPage实际点击/确认回归，验证教务磁盘删除及协助活动Provider重新读取；首次测试遗漏Toast计时器清理，已按现有AppToast.dismiss收尾，未修改产品代码规避测试。
clear-flow-verified.log 11项通过；冻结源码后delivery-tests.log完整816项通过/2项既有跳过，delivery-analyze.log无问题，delivery-ci-tests.log交付21项通过，CHANGELOG结构检查通过。所有四个维护阶段完成。全量教务行DTO迁移、其余页面间循环依赖与本地规范公开化不在本轮迁移范围，后续在对应功能触及时处理；未新增框架/依赖或生成代码修改。
- 最终Android Release构建成功81.1MB（android-release.log），仍0.3.0+6，证书SHA256与既有包一致。ADB当前无设备，因此没有安装或清理真机数据；未push/发布。安装包保留dist/xmu-rollcall-0.3.0-android.apk供后续覆盖安装。

## 2026-10-29 课表类型化阶段1
AcademicCourseRow作为教务课次的内部类型，academic_parsing保留网络/缓存入口的外部转换；AcademicSchedule、关联、今日课程、地点与搜索使用明确字段。原JSON字段名保持兼容，周次写回规范化掩码（保留实际周次），原空BJDM关联键course/null保持。新增旧缓存读取、输入快照、隐私字段排除、读写往返、错误周次在缓存入口处理的回归；测试夹具直接使用生产解析器，没有复制业务算法。
stage1-verified-tests.log 71项通过，stage1-analyze.log对lib/test检查无问题；包括真实课表样本、单双周、多教室、账号缓存与桌面/Android组件。当前未声称真机或线上接口验收，最终阶段再做完整回归与图像对照。


## 2026-10-29 依赖维护阶段2
认证默认Provider只创建AuthController，跨模块生命周期动作由main的ProviderScope使用app/auth_session.dart接线；协助分享移除目录Provider反向读取，保留先落盘后发布的同一目录。生产接线回归发现原回调读取自身Provider触发Riverpod断言且错误被吞掉，改为检查当前控制器登录身份，保留异步身份边界。stage2-verified-tests.log相关39项通过，stage2-analyze.log对lib/test无问题；新增失效会话完成同步回归后stage2-wiring-final.log 3项通过。无布局或协议改动。


## 2026-10-29 依赖维护阶段3：页面组合与地图配置

协助名单页独立于导入/导出弹窗；课程作业页接收详情构建回调，详情页负责组合导航；地图常量单独存放，签到位置预览直接读取配置。保持全部布局参数。拆分初次检查暴露签到预览依赖选点页重导出的常量，已改显式导入；新导航测试使用应用自己的返回控件，补齐提交状态边界替身后最终回归通过。

- stage3-final-tests.log相关35项通过，含详情→课程列表→另一条详情→返回与课程上下文补齐、协助名单/导入和各尺寸地图交互。
- final-tests.log完整821项通过、2项既有跳过；delivery-analyze.log全库无问题，ci-tests.log交付21项通过，CHANGELOG结构有效。
- import-graph.txt对221个Dart文件及条件导入/导出执行Tarjan扫描，循环分量为0。未增加依赖或通用路由框架。
- final-captures.log生产组件11项通过；实看浅色首页和窄屏深色长内容。idle-light/idle-dark与改动前PNG逐字节相同，SHA256分别为9bdbdec408cd12e7d6bbda4d15e2d55447d2ded9bc983b07776303e59d743425、ffac8814d8a20968f4c81ce9e26529059888c7efad34582cd236950675c5211f。桌面由既有工作区/课表/设置多尺寸组件测试验证，未声称全页面真机验收。
- Android Release编译成功（android-release.log，81.1MB，仍0.3.0+6），APK固定证书SHA256与既有值7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5一致。保留既有Kotlin插件迁移提示，本轮未改依赖；未安装真机、执行真实签到、push或发布。


## 2026-10-29 二轮全项目审查阶段1

项目盘点覆盖221个Dart文件、Android原生入口、Windows runner及交付脚本；按数据/生命周期热点定向检查，不把文件长度或可再抽象列为缺陷。目录在途复用已由catalog-repro.log复现：切到账号2仍得到owner-one。目录增加与Provider有效期一致的请求修订号、重建释放旧在途引用，旧请求不可发布/落盘；延迟教务同步同样检查有效期。

stage1-tests.log相关49项通过，stage1-lifetime-tests.log两项生产Provider回归通过（实际会话切换和同账号invalidate），stage1-analyze.log对lib/test无问题。未变更样式或协议。下一阶段处理显式协助课表读取全局地点数据的范围错误。


## 2026-10-29 二轮全项目审查阶段2

显式账号的地点数据贯穿课表提示、详情地图、管理/选点与保存；不修改全局选择或停止该账号之外的检测。新增按用户读取的Provider，当前身份复用原地点控制器，保留现有默认入口与测试覆盖；全局切号后显式控制器重载，避免再次看到旧地点。现有列表分组、间距、地图参数全部保留。

stage2-verified-tests.log相关68项通过，stage2-explicit.log真实课表→地点管理→地图选点→保存通过，stage2-scope-final.log额外验证全局切换期间编辑和返回重读；stage2-final-analyze.log对lib/test无问题。初次测试使用带A区的楼宇名称查找独立行，实际界面按楼宇聚合，改用无分区的测试楼完成同一范围回归；未更改UI适配测试。


## 2026-10-29 二轮全项目审查阶段3及范围结论

P1历史缓存失效由history-before.log真实回归复现：同账号删去课程历史并invalidate后，挂起的请求写回CourseRollcallsSnapshot。加载/迁移/刷新/逐条发布现统一使用Provider有效期，替代只比较用户ID的判断；旧成功和失败响应均停止落盘及发布，保留现有候选/限流/逐课发布。stage3-tests.log相关48项通过；最终完整套件另含成功与失败两条失效回归。

本轮覆盖的模块及处理：

| 范围 | 重点与结论 |
| --- | --- |
| 认证/会话/协助 | 检查安全存储、Cookie替换/请求撤销、主号与导入身份路由；修复课程目录切号复用，未修改协议和稳定deviceId |
| 课程/历史/作业/成绩 | 检查缓存键、失效、在途合并、增量与失败保留；修复目录及历史有效期，作业/成绩已有修订号和身份边界继续保留 |
| 地点/地图/课表呈现 | 修复显式账号误用全局地点；同一账号当前/显式入口复用控制器，手动安排与手动雷达也传递正在操作的身份 |
| 检测/自动应答/Android后台 | 检查任务当前性、提交前重读位置、终止与有限重试、独立会话及SharedPreferences重新加载；未发现本轮可复现的新缺陷，不改默认确认/频率 |
| 网络/日志/更新 | 检查安全方法退避、取消/限流、日志脱敏、下载大小/SHA256、分片清理、Android签名及构建号检查；未发现需扩展策略的具体证据 |
| 平台/交付 | 盘点5个Kotlin入口、12个Windows runner文件、14个交付/辅助脚本；定向检查平台通道/更新/通知入口与CI产物校验，协议适配和原生改造未扩张 |

不因49k行源码或单文件体积继续拆层；保留现有布局/导航、依赖、CI流程及前次已消除的导入环。真实校园接口、安卓后台长驻/通知/安装和Windows通知激活仍须设备/环境验收，本轮测试不替代这些验收。没有声称已证明所有代码无缺陷。


最终证据：final-tests.log完整827项通过/2项既有跳过，final-analyze.log全库无问题；ci-tests.log 21项通过，CHANGELOG校验通过。import-graph.txt对221个Dart文件（含条件import/export）扫描循环0。captures.log生产控件11项通过；实看浅色首页与深色窄屏长内容，pixel-comparison.txt确认idle-light/idle-dark与改动前逐字节一致。桌面工作区、课表、地图、设置和返回行为由原有多尺寸组件回归验证，本轮未改布局参数。

android-release.log编译成功81.2MB（本地验证仍0.3.0+6），apk-signature.log核对固定证书SHA256与既有7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5一致。未安装真机或执行真实签到、未push/发布。全部已复现问题均已处理；未通过猜测继续扩张技术债清理。


## 2026-10-29 教务访问阶段1

客户端创建和主号/协助身份解析移到academic_access；课表和成绩从同一工厂得到独立客户端，并共用一个RateLimiter。AcademicIdentity独立定义，直接构造的同步器复用同一主号凭据解析函数；业务有效期由各自Provider/同步器保留。stage1-verified-tests.log相关30项通过，包括真实HTTP适配器/队列的跨业务阻塞与释放、身份凭据分离/撤销及已有课表/成绩协议回归。未新增依赖或改UI/数据格式；最终分析结果在stage1-final-analyze.log。


## 2026-10-29 教务访问阶段2

旧academic_client拆为公共AcademicSession、AcademicTimetableReader、AcademicGradeReader和AcademicSync；共享外部解析函数移到academic/。成绩专用Referer/Origin/XHR头留在GradeReader，Session按业务传入的应用ID建立会话，构造时仅装一次CookieManager；成功读取统一保存原键同格式安全快照，finally关闭本次HTTP。移除旧混合文件和转发兼容层，生产和协议测试均改显式依赖。

stage2-final-tests.log相关46项通过；新增成绩快照→新会话恢复及请求头不泄漏、错误成绩不覆盖旧快照。原成绩上下文断言现通过完整生产GradeReader/HTTP适配器执行，未为测试保留专用生产方法；测试辅助readGrades只调用真实Reader。stage2-final-analyze.log对lib/test无问题。初次拆分的测试构造/清理和导入迁移编译错误已修正，最终结果无失败。UI、账号数据/缓存格式和计算规则未改。


## 2026-10-29 教务访问阶段3：完整交付验证

- final-tests.log完整831项通过、2项既有跳过；final-analyze.log全库无问题，ci-tests.log交付21项通过，CHANGELOG结构有效。
- import-graph.txt扫描226个Dart文件（含条件导入/导出）循环0；AcademicSession的传递依赖不再包含课表/成绩业务文件。
- captures.log生产控件11项通过，实看浅色首页与窄屏深色长内容；pixel-comparison.txt确认idle-light/idle-dark与改动前PNG逐字节相同。桌面现有工作区/课表/设置/地图多尺寸回归包含在完整套件中；未修改任何布局源文件。
- android-release.log编译成功81.2MB（本地验证仍0.3.0+6），apk-signature.log固定签名SHA256为7c64edfa4cf30722aaa0ec57f05d0ab026f50678243d4821d09de3e26cbe62e5，与既有包一致。既有Kotlin插件迁移提示未扩展为依赖升级。
- 本轮未读取真实账号凭据/查询校园接口，未重新安装手机、未push或发布。教学/成绩缓存、SecureStore键、默认提交确认与畅课会话机制未改；今后新教务数据的接入约定已写入本地docs/ARCHITECTURE.md“教务数据扩展入口”。
