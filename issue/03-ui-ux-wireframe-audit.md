# UI/UX Audit — App vs. `/frontend-integration/wireframe-design/`

## Important correction on the design target

The request was to check the UI against a "black and white" theme. **That is not what the wireframes actually specify.** Every wireframe HTML file (`iam_login_page.html`, `hr-dashboard.html`, `crm-lead-details.html`, `hr-attendance.html`, `field-dispatch.html`, `client-signoff.html`, `crm-qoutation.html`, and the `new-*.md` specs) share one identical Material 3 / Tailwind config with a **deep emerald-green primary (`#0f5238`)**, a cool blue-white surface (`#f9f9ff`/`#ffffff`), muted semantic status colors (success `#137333`/`#E6F4EA`, warning `#B06000`/`#FEF7E0`, error `#ba1a1a`/`#ffdad6`), IBM Plex Sans (headlines) + Inter (body) typography, and Material Symbols Outlined icons. No design doc anywhere calls for monochrome.

So there are actually **two separate gaps** to report: (1) the app's own theme file *is* black/white/gray, which is a defensible "clean minimalist" choice on its own — but (2) most actual screens don't even follow that theme file; they hardcode a third, different palette. Neither of these matches the wireframes' green design system. Both are documented below.

**Note on the wireframe source files themselves:** several "distinct" HTML files in `Designs/` are byte-identical duplicates of unrelated pages (`crm-leads-board.html`, `logistics-orders-dashboard.html`, `execution-jobs-dashboard.html` are all literally copies of `iam_login_page.html`; `iam-pin-setting.html`/`logistics-vendor.html`/`execution-site-details.html` are all the same file; `iam-pin-verification.html` is a copy of `hr-attendance.html`). This is a defect in the design source files, not the app — the audit relied on the markdown specs (`new_crm_leads_board.md`, `new_logistics_orders.md`, `new_main_layout.md`, `iam_feature_page.md`, etc.) as ground truth wherever the HTML was corrupted. **Worth fixing on the design side** so future comparisons aren't hampered by this.

---

## Resolution (2026-07-10)

The direction chosen was to match the wireframes (their emerald-green Material 3 system, not the app's old black/white theme). What was rebuilt:

- **Design system:** `AppColors`/`AppTheme` rewritten from the wireframes' actual Tailwind tokens (primary `#0F5238`, full surface/container/outline role set, IBM Plex Sans for headlines + Inter for body via `google_fonts`). All ~170 hardcoded `Color(0x…)` literals across ~25 screens replaced with theme references, so the ad hoc third palette (Material blue + rainbow status colors) is gone.
- **Navigation:** rebuilt as the wireframe's 5-tab shell (Home / CRM / Logistics / Execution / HR) with Profile reachable via an AppBar icon per top-level screen, replacing the old 3-tab (then 4-tab) structure.
- **CRM Leads Board:** rebuilt as a real horizontal Kanban board (`crm_leads_screen.dart`) with drag-and-drop `DragTarget`/`Draggable` columns, matching the wireframe's *pattern* — using the backend's actual 8-status enum (`new`/`first_call`/`pdf_sent`/`sample_sent`/`site_visit`/`negotiation`/`finalized`/`lost`) rather than the wireframe spec's 5 invented column names, since those don't correspond to any real backend status. The wireframe's Hot/Warm/Cold priority badge was **deliberately omitted** rather than faked — the Lead model has no priority field (only Complaints do) — cards show real fields (source badge) instead.
- **CRM Quotation:** rebuilt as a dedicated full-page screen (`quotation_builder_screen.dart`) with per-item rows, tax rate field, running subtotal, a primary-colored total band, a PDF-upload dropzone, and Preview/Generate & Save actions — closing what was previously the single largest fidelity gap (a whole missing screen).
- **PIN Verify:** rebuilt as a numpad lock screen (`pin_entry_screen.dart`) with PIN dots and auto-submit (immediate at 6 digits, debounced at 4, since normal PINs are 4 digits and Ghost Mode PINs are 6).
- **PIN Setup:** added the wireframe-specified red warning when the two PINs match, re-themed.
- **Execution Jobs Dashboard:** rebuilt as bento-style cards (`execution_jobs_screen.dart`) with a colored left status bar, a 3-stage progress bar, and a colored status pill — using the job's real `installations.status` lifecycle (`assigned`/`in_progress`/`client_approved`/`redo_required`) rather than the wireframe's 4-stage procurement pipeline, which isn't tracked at this granularity by the Execution module.
- **Login:** rebuilt to match `iam_login_page.html` closely (icon-in-surface-container logo box, "Enterprise Suite" branding and copy, mail/lock icons, "Forgot Password?" link).

### What was re-themed but not restructured

These screens now use the correct color system and no longer look off-brand, but their layout still doesn't match the wireframe's specific bento/tabbed/table patterns — rebuilding each would be a much larger effort than a color pass:
- **CRM Lead Details** (`crm_lead_detail_screen.dart`) — still a flat card list; the wireframe's avatar, priority badge, quick-contact buttons, assignee control, tabs, and timeline were not built.
- **Logistics Orders / Vendors** — structurally reasonable (matches the wireframe's expandable-list pattern for Orders) but still default `Card`/`ListTile` styling, no colored status badges.
- **Client Sign-off** (`client_signoff_screen.dart`) — still a standard scrolling form, not the wireframe's immersive landscape-locked full-bleed signature canvas.
- **HR home check-in** — HR hub (`hr_hub_screen.dart`) has a two-button Check In/Check Out row rather than the wireframe's single giant circular fingerprint button, though it's now correctly primary-colored.

### Known limitation carried over from the upload revert

The quotation builder's PDF upload and the client sign-off signature capture both go through `MockUploadService` (fake URLs) rather than a real upload, because the backend endpoint needed to support this was reverted per an explicit "no backend changes" instruction mid-session — see [01-backend-issues.md](01-backend-issues.md). The UI/UX for these flows is real; the file storage behind them is not.

Verified with `flutter analyze` (0 issues) and `flutter test` (passing) after this rebuild.

---

## Theme / design system comparison

| Aspect | Wireframe spec | App's theme file (`app_theme.dart`/`app_colors.dart`) | What screens actually do |
|---|---|---|---|
| Primary color | `#0f5238` (emerald green) | `Colors.black` | `Color(0xFF0061a4)` (Material blue) hardcoded in ~15 screens |
| Background | `#f9f9ff` | `Colors.white` | `Color(0xFFFEF9F2)` (cream) in auth/staff/admin screens |
| Status colors | Distinct green/amber/red tints per state | All four semantic roles collapsed to the **same** grey `#424242` | A full rainbow: `Colors.lightBlue/orange/purple/teal/amber/green/red/grey`, plus `#4CAF50`, `#FF9800`, `#006e1c`, `#904d00`, `#ba1a1a`, `#2196f3`, and more |
| Typography | IBM Plex Sans + Inter, defined type scale | No `fontFamily` set at all → falls back to system default (Roboto) | Ad hoc inline `TextStyle(fontSize: …)` everywhere, no shared type scale |
| Corner radius | Consistent 8px/12px tokens | Buttons 8px, cards 12px (matches the spec's numbers) | Overridden per-screen: 4/8/12/16/20/24px all appear across different screens |
| Shared component layer | Implied by consistent token reuse | `lib/shared/widgets/buttons.dart` correctly consumes `AppColors` | Bypassed almost everywhere — screens instantiate raw `ElevatedButton` with local hex colors instead of the shared `PrimaryButton`/`SecondaryButton` |

**Breadth confirmation:** hardcoded `Color(0x…)` literals appear **169 times across 32 files** in `frontend/lib`; named `Colors.blue/green/red/orange/purple/teal/amber` appear in 12 more files. Hardcoded/ad hoc coloring is the dominant pattern in this codebase, not the exception.

The theme file itself, where it's actually consumed (elevation 0, 8px inputs/buttons, 12px cards with a hairline border), is genuinely well-built. The gap is adoption, not design quality.

---

## Per-module comparison

| Module | Design source | Flutter implementation | Mismatch | Severity |
|---|---|---|---|---|
| IAM Login | `iam_login_page.html` | `frontend/lib/screens/auth/login_screen.dart:172,186,194,235,257,291,321` | Hardcoded cream bg, blue icon box, blue button, green status text — none of which exist in `AppColors` or the wireframe's green. Copy says "Studio CRM" / "Secure operational portal" instead of the spec's "Enterprise Suite" / "Secure access to your workspace". | Critical |
| IAM PIN Verify | `iam_feature_page.md` §3 (numpad lock screen, PIN dots, biometric icon, auto-submit) | `frontend/lib/features/auth/screens/pin_entry_screen.dart:63-76` | Spec calls for a minimalist numpad with PIN dots and biometric affordance with auto-submit. Actual implementation is a plain obscured `TextField` with a manual "Unlock" button — none of that exists. Same off-theme colors as login. | Critical |
| IAM PIN Setup | `iam_feature_page.md` §2 (dual-PIN flow with red mismatch warning) | `frontend/lib/features/auth/screens/pin_setup_screen.dart:40,73-92,100` | Two-PIN fields work functionally, but there's no warning if Normal PIN equals Ghost PIN, which the spec explicitly requires. Same off-theme colors. | High |
| Main Shell / Nav | `new_main_layout.md` (5-module nav: Home/CRM/Logistics/Execution/HR, + desktop nav rail) | `frontend/lib/core/widgets/main_shell_screen.dart:21-33` | Only 3 generic tabs ("Workspace"/"Pipeline"/"Profile") via a bare, unstyled `NavigationBar`. The spec's 5-module IA is entirely collapsed away, and there's no responsive desktop nav-rail variant as required. This is also the direct cause of the Critical "most of the app is unreachable" finding in [02-frontend-issues.md](02-frontend-issues.md). | Critical |
| HR Home / Attendance | `hr-dashboard.html` (large circular fingerprint check-in + 4-tile quick actions) | `frontend/lib/screens/staff/staff_home_screen.dart:250-338`, `frontend/lib/features/hr/screens/my_attendance_screen.dart:90-244` | No circular check-in button anywhere. Replaced by a digital-clock card + rectangular Check-In/Check-Out buttons — and the **same action uses two different color pairs on two different screens** of the same app (`0xFF006e1c`/`0xFFba1a1a` on one screen, `0xFF4CAF50`/`0xFFFF9800` on the other). | High |
| HR Admin Dashboard | `hr_feature_page.md`/`hr-attendance.html` | `frontend/lib/screens/admin/admin_dashboard_screen.dart:186-417` | Bespoke color set unrelated to `AppColors`; card/list structure is a reasonable structural echo of the wireframe's table, better than most screens, but still fully off-theme. Also orphaned from navigation per [02-frontend-issues.md](02-frontend-issues.md). | Medium-High |
| CRM Leads Board | `new_crm_leads_board.md` (Kanban, 5 columns, drag-to-move, priority badges) | `frontend/lib/features/crm/screens/crm_leads_screen.dart:120-306` | **Not a Kanban board at all** — a single vertical scrolling list with horizontally-scrolling filter chips using a 9-value status taxonomy instead of the spec's 5 columns. No drag-and-drop, no columns, no priority badge. Status colors are a literal rainbow (`Colors.lightBlue/orange/blue/purple/teal/amber/green/red/grey`) — the single worst example of "every status gets a different named color" in the codebase. Also orphaned from navigation. | Critical |
| CRM Lead Details | `crm-lead-details.html` (avatar + priority badge, Call/WhatsApp/Email actions, assignee dropdown, 4 tabs with timeline) | `frontend/lib/features/crm/screens/crm_lead_detail_screen.dart:265-353` | Reduced to a flat list of generic cards. No avatar, no priority badge, no quick-contact actions, no assignee control, no tabs, no timeline. | Critical |
| CRM Quotation | `crm-qoutation.html` (dedicated full-page builder: tax rate, payment-terms dropdown, running subtotal, total band, PDF upload, Preview + Generate&Save) | `frontend/lib/features/crm/screens/crm_lead_detail_screen.dart:96-238` | The entire dedicated quotation page is collapsed into a small `AlertDialog`: item name/qty/price only. **Tax rate isn't even user-visible — it's hardcoded to `18.0` or `0.0` in code** (`crm_lead_detail_screen.dart:224`). No running subtotal/total, no PDF upload, no Preview. This is the single largest fidelity loss in the whole audit — a whole intended screen was never built. | Critical |
| Logistics Orders | `new_logistics_orders.md` (expandable list, colored status badges, Create PO / Schedule Dispatch actions) | `frontend/lib/features/logistics/screens/logistics_orders_screen.dart:250-320` | The information architecture is actually reasonably faithful (`ExpansionTile` per order with the right actions), but it's rendered with zero custom styling — default icon, plain text status instead of colored badges, off-theme AppBar. Structure is right; presentation is undressed. | High (visual), Low (IA) |
| Logistics Vendors | (wireframe file corrupted — inferred from `logistics_feature_page.md`) | `frontend/lib/features/logistics/screens/vendors_list_screen.dart:143-256` | Plain list, ad hoc blue coloring, no relation to `AppColors` or wireframe green. | Medium |
| Execution Jobs Dashboard | `new_execution_jobs.md` (colored status bar, stage progress bar Procurement→Site Prep→Installation→Signoff, colored status pill) | `frontend/lib/features/execution/screens/execution_jobs_screen.dart:22-80` | Reduced to a bare list of `Card`+`ListTile`. No progress bar, no colored status pill, no bento layout. | Critical |
| Client Sign-off | `client-signoff.html` (landscape-locked, full-bleed signature canvas with watermark, hero approval text, Erase overlay) | `frontend/lib/features/execution/screens/client_signoff_screen.dart:79-149` | Rebuilt as a standard scrolling form instead of an immersive full-screen signing experience. No landscape lock, no hero text. (Also see [02-frontend-issues.md](02-frontend-issues.md) — the signature this screen collects is discarded by the mock upload service anyway.) | High |

---

## Overall verdict

**The app achieves neither the wireframes' design bar nor its own theme file's design bar.** There are effectively three competing, unreconciled color systems in this codebase: (1) `AppColors`/`AppTheme` — a genuinely clean black/white/grey Material 3 theme wired at the app root; (2) the wireframe spec — an emerald-green Material 3 system with muted semantic status tints and IBM Plex Sans/Inter type; and (3) an undocumented ad hoc blue-and-rainbow palette hardcoded directly into the majority of screen files, which is what a user actually sees on login, PIN, staff home, admin dashboard, CRM, logistics, and execution screens. Beyond color, several flagship interaction patterns the wireframes specifically designed in detail — the Kanban leads board, the full-page quotation builder, the numpad PIN lock screen, the progress-tracked job cards, the tabbed lead-detail timeline, and the 5-module bottom navigation — were not built at all; they were replaced with generic filtered lists, dialogs, and default `Card`/`ListTile` widgets. The result reads as an unstyled internal admin tool with inconsistent per-screen coloring, not the "clean, minimalist, modern, professional" product either design language calls for.

## Recommended remediation path

1. **Pick one palette and enforce it.** Either adopt the wireframes' green Material 3 system (if the design docs are the source of truth going forward) or formally decide the black/white `AppColors` theme is the product's direction and update the wireframes to match. Don't leave both plus a third ad hoc palette in play.
2. **Route every screen through the shared theme/components.** `lib/shared/widgets/buttons.dart` already does this correctly — extend that pattern (shared card, chip, status-badge widgets) and delete the ~169 hardcoded `Color(0x…)` literals in favor of it.
3. **Rebuild the flagship screens that were skipped**, prioritized by the navigation fix in [02-frontend-issues.md](02-frontend-issues.md) that would make them reachable in the first place: the quotation builder (currently missing a visible tax field entirely — a functional gap, not just cosmetic) and the CRM leads Kanban board are the highest-value targets.
4. **Fix the design source files** (`Designs/*.html` duplicates) so future comparisons against them are reliable.
