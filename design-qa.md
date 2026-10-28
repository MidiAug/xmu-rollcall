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
