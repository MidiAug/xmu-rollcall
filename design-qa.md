# Desktop design QA — 2026-10-28

final result: passed

This pass implements the user's latest corrections to the selected sea-salt teal Flutter desktop design. Subjective acceptance and native drag-resize frame rate remain separate from these checks.

## Sources and visual evidence

- Original selected layout: `codex-clipboard-ac00b792-f086-4f72-a61c-8a02976c32ba.png` (892×635). Later user instructions remove duplicate branding and request the supplied sidebar illustration.
- Latest timetable source: `codex-clipboard-e94a9329-dccf-4647-ae24-47fa29608f53.png`; latest sidebar asset: `codex-clipboard-efcdfb68-a654-4600-a66e-2377b518e262.png`. The latter is copied unchanged into `assets/illustrations/campus_sidebar.png`.
- `.tools/refine-comparison.png` puts the original layout and current Flutter render together at 900×640. Differences required by subsequent corrections (branding, icon style, controls, dates/content) are intentional; this is not a pixel-identical clone claim.
- `.tools/desktop-workspace/*-dpr*.png`: five root pages plus open attendance menu and history at six viewport/density/scale combinations (42 views). Includes 900×640 DPR1/2, 960×720, 1120×780, dark 1440×1024 DPR2, and 1120×820 at 1.3 text scale.
- `.tools/academic-stacks/*`: even/odd front variants and full rooms at DPR1/2. `.tools/polish-interactions/*`: an intermediate slider frame and the shared end-aligned menu.
- Renders load real local CJK/Segoe fonts and package Fluent icon fonts. All account/course/person values in fixtures are synthetic; production account data is not injected or modified.

## Findings, corrections and recheck

1. P2 segmented feedback: transitioning semi-transparent fills could pass through a dark color. A single opaque mint selection plate now slides under stable button labels; intermediate position, luminance, final position and keyboard selection are tested. Reduced-motion settings are respected.
2. P2 popup inconsistency: attendance actions used a different popup route and invisible tap padding. They now use the same anchored overlay, gap, animation, close registry and keyboard handling as account/filter menus. End/right alignment and Escape/action dismissal are checked.
3. P2 alignment: narrow content columns are centered below an independent page title; wide homework stays explicitly left-aligned. Settings/history large-window renders and history center-coordinate assertions verify this. Date text is bottom-aligned to the attendance title.
4. P2 course presentation: full room text replaces suffix-only captions; overlong tails clip on one line, and detail preserves the full value. Compact single-period cards reserve room space. Header metadata no longer uses dot separators.
5. P2 teaching consistency: instructor/assistant assignments reuse the student inbox row's icon, padding, bounded title and responsive metadata layout. Long teaching-course headings remain one bounded line. Student submission semantics are not applied to teaching rows.
6. P2 navigation: the requested supplied transparent illustration fills the lower sidebar without covering controls. Selected icons use fuller variants at 24px, with a continuous brighter teal rail. Sidebar branding stays omitted.
7. P2 retained-page lifecycle: freezing hidden tickers initially prevented nested exit animations from disposing. After the existing draft/busy guard succeeds, tab route observers remove nested routes immediately. Ordinary in-page back transitions remain unchanged. Route reset, cancelled/confirmed drafts and busy editors pass regression again.

The original generated attendance illustration remains `campus_mist.png`. No new illustration was generated.

## Resize evidence and limits

The old IndexedStack lays out every visited child during resizing. The retained viewport freezes hidden layout constraints and MediaQuery geometry, isolates painting and disables hidden tickers/focus while preserving route/root state. A five-page, 60-resize comparison records 300 baseline layouts versus 60 active layouts and zero hidden layouts; switching back verifies retained state and updated geometry. Widget-test elapsed time is not native FPS or a claim that all desktop resize latency is eliminated. Debug overhead and native compositor behavior remain outside that measurement.

## Durable course evidence

`test/fixtures/academic_complex.md` records sanitized field meanings, same-course odd/even room variants, parallel-room merging, continuous-period boundaries, date-exclusive stacks and current published-row authority. Neither the supplied example nor the existing cache showed a different-course date-exclusive overlapping pair; a separate synthetic regression covers it. Raw requests, credentials and personal fields are not retained.

## Verification

- Full regression: 691 passed; 2 network tests skipped by existing configuration (`.tools/refine-verified-tests.log`).
- Final timetable/workspace/route regression after layout refinements: 47 passed (`.tools/refine-last-layout.log`).
- Single-period full-room/clip regression in desktop/touch/large-text scenarios: 5 passed (`.tools/refine-room-clip.log`).
- Six viewport menu/history captures and centering assertions: 6 passed (`.tools/refine-history-visual.log`).
- Analyze: no issues. Final saved-source logs: `.tools/refine-delivery-analyze.log`, `.tools/refine-delivery-windows2.log` (a serial verbose retry after a custom-build-step failure).
- Final Windows Release build succeeded (serial retry, exit 0); no install/publish. Live Debug remains running with hot reload.
- Android device behavior and complete native window/notification interactions are not claimed as manually verified in this pass.
