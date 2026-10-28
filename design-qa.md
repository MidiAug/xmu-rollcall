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
