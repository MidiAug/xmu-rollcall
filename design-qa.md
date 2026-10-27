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
