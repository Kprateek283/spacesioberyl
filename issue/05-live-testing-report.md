# Live Testing Report — Method, Results So Far, Remaining Checklist

This documents how the app was actually launched and driven (not just `flutter analyze`/`flutter test`), what's been confirmed working against the real running backend, and what's still untested.

## Method

**Why this method:** Flutter web renders the entire UI to a `<canvas>` (CanvasKit renderer) — there is no accessible DOM tree of buttons/inputs for a browser automation tool to query by text or CSS selector like a normal web app. So the approach is:

1. **Launch the real app** against the real backend: `flutter run -d chrome --web-port=53421` from `frontend/`, with `frontend/.env`'s `API_URL` temporarily pointed at `http://localhost:8080/api/v1` (the checked-in default is `http://10.0.2.2:8080/api/v1`, which is an Android-emulator-only alias and doesn't resolve from a desktop browser — **this needs reverting to `10.0.2.2` before Android emulator testing, or set per-target**).
2. **Confirm the backend is actually up**: `docker ps` (all 6 containers — `system_api`, `system_worker`, `system_db`, `system_mq`, `system_cache`, `system_storage` — were already running) and `curl http://localhost:8080/ping`.
3. **Drive it with a headless Playwright browser** (installed on-demand via `npx playwright install chromium`, ~114MB, not a project dependency) pointed at the same URL the real Chrome window is serving (`http://localhost:53421`). This is a *second*, independent browser instance hitting the same dev server — not remote-controlling the window `flutter run` opened.
4. **Interact via coordinate-based mouse clicks** (`page.mouse.click(x, y)`) and `page.keyboard.type(...)`, since there's no DOM to target by selector. Coordinates were read off each screenshot before the next action.
5. **Verify two independent signals after every action:**
   - A **screenshot**, visually inspected (not just "no exception thrown" — an actual look at the rendered pixels).
   - The **real network traffic** to `localhost:8080` (`page.on('response', ...)`), logging status codes and URLs, plus `page.on('console')`/`page.on('pageerror')` for JS exceptions.

This is a real end-to-end test: real Flutter web build → real HTTP calls → real Go backend → real Postgres, not mocked at any layer.

## Confirmed working (screenshots + network logs captured)

| Flow | Result |
|---|---|
| App boot / login screen render | ✅ Matches wireframe closely (Enterprise Suite branding, icon, colors, fields) |
| Login form (`admin@gmail.com` / `admin123`) | ✅ Real `POST /login` succeeds, navigates to PIN screen |
| PIN numpad screen render | ✅ Avatar, "Session Locked", 6 PIN dots, 3×3+1 numpad, Clear/Logout links |
| PIN entry (`1234`) → unlock | ✅ Real `POST /iam/verify-pin` succeeds, auto-submits at 4 digits, navigates to Home |
| 5-tab bottom nav (Home/CRM/Logistics/Execution/HR) | ✅ Renders, correct icons, selection highlight follows active tab |
| Home screen AppBar (Pipeline icon + Profile icon) | ✅ Renders |
| **Home screen data load** | ❌ **404 on `GET /api/v1/workspace/action-items`** — see Finding below |
| CRM tab → Kanban board | ✅ Renders with **real lead data** from Postgres (2 leads in "New", 1 in "PDF Sent", correct source badges "WALK IN"/"REFERRAL", column counts correct) |
| Logistics tab → hub grid | ✅ Renders (Orders/Vendors/My Dispatches/Log Dispatch tiles) |
| Execution tab → hub grid | ✅ Renders (All Jobs/Installers/Site Updates/Client Sign-off tiles) |
| HR tab → hub screen | ✅ Renders (Check In/Check Out buttons, Quick Actions grid: My Attendance/My Leaves/...) |
| Console errors during the whole flow above | **Zero**, other than the one 404 below |

## Finding: Home screen data load 404s — confirms a suspicion from the static audit

`GET http://localhost:8080/api/v1/workspace/action-items` returns **404** against the currently-running backend container. This is the exact BFF endpoint flagged in [01-backend-issues.md](01-backend-issues.md) as suspected to be missing from a stale Docker image — **now confirmed live**, not just inferred from source reading.

- `docker ps` shows `spacesioberyl-api` was built **13 days ago**. The BFF module (`internal/bff`, registering `/api/v1/workspace/action-items` and `/api/v1/workspace/personal-timeline`) exists in the current source but the running container predates it.
- **This is not a frontend bug.** The frontend correctly calls the endpoint; `workspace_provider.dart` correctly surfaces the resulting `DioException` as an error message instead of crashing (the error card render is itself working as designed).
- **Fix:** rebuild and restart the `system_api` container from current source (`docker-compose build api && docker-compose up -d api`, or equivalent) so it includes the BFF module. This is a deployment/ops action, not a code change, so it's flagged here rather than silently done — confirm before running it since restarting a container is exactly the kind of action that should be checked first.
- Every other tab/screen tested loaded with **zero backend errors**, confirming this 404 is isolated to the one stale BFF route, not a wider backend connectivity problem.

## Not yet tested (stopped here at the user's request to document instead of continuing ad hoc)

Deeper mutation/round-trip flows not yet exercised live:

- CRM: tapping a lead card → Lead Detail screen render; status update; Create Quotation (full builder screen) → submit; Follow-ups/Complaints icons → their screens
- HR: Check In / Check Out button → real attendance mutation + UI feedback; My Leaves → request a leave; My Expenses → claim an expense (mock upload path); admin-only tiles (Leave Admin/Expense Ledger/User Management) for the `admin@gmail.com` (super_admin) session
- Logistics: Orders list (admin-only) → assign manager / create PO / schedule dispatch; Vendors list; My Dispatches; Log Dispatch form
- Execution: Jobs list (bento cards, progress bar) → Job Detail → assign installer / check in-out / record payment; Installers list → create installer; Site Updates → create update with photo; Client Sign-off → draw signature → submit
- CRM Kanban drag-and-drop (moving a card between columns, including the "Lost" reason-required dialog)
- Logout flow, and re-login as `staff@gmail.com` / `staff123` to confirm role-gated tiles are correctly hidden (Leave Admin/Expense Ledger/User Management should not appear)
- Offline-sync banner behavior (would need throttling/offline simulation, not attempted)

## How to continue this testing yourself (or ask me to)

```bash
# 1. Confirm backend is up
docker ps
curl http://localhost:8080/ping

# 2. Point the frontend at localhost for desktop/web testing (revert to 10.0.2.2 for Android emulator)
#    Edit frontend/.env: API_URL=http://localhost:8080/api/v1

# 3. Launch
cd frontend
flutter run -d chrome --web-port=53421
# leave this running — it hot-reloads on save, and the Chrome window it opens is directly usable by hand

# 4. Click through by hand in the opened Chrome window, or drive it headlessly:
npx --yes playwright@latest install chromium   # one-time, ~114MB
# then a small Node script using `require('playwright')`, `chromium.launch()`,
# `page.goto('http://localhost:53421')`, coordinate-based `page.mouse.click(x, y)`,
# and `page.on('response'/'console'/'pageerror')` to catch real backend errors —
# same approach used for the results above.
```

See [04-testing-strategy.md](04-testing-strategy.md) for the broader recommendation (CI, unit tests, contract testing) beyond this one-off live pass.


## Unblocked Testing Attempt (Automated Headless Blocker)

I attempted to execute the remainder of the checklist (CRM, HR, Logistics, Execution, Kanban) via the headless Playwright method with coordinate-based interaction. However, this testing is **BLOCKED** due to the following critical limitations:

1. **Flutter Canvas Input Blocking:** Keystrokes sent via headless Playwright (page.keyboard.type) or clipboard injections fail to reliably register into Flutter Canvas Web TextFormField elements when interacting via raw coordinates. The email/password fields reject or clear the automated inputs, completely blocking automated E2E login progression.
2. **Visual Studio Toolchain Missing:** Attempted to fallback to native Flutter Integration Tests (lutter test integration_test/... -d windows) to bypass the Web Canvas limitation, but this failed as the Windows native build toolchain (Visual Studio MSVC) is missing from the environment.
3. **API Crash Blocking UI:** Additionally, the Redis connection timeouts identified in the backend cause the backend server (system_api) to crash entirely on startup in this environment, which means the real POST /login and all subsequent API calls return HTTP 404/Connection Refused.

Due to these strict environment constraints (no manual intervention, UI canvas keystroke rejection, missing native toolchain, and crashing API container), the remaining steps in the checklist cannot be executed autonomously at this time. The backend Redis dependency must be resolved or mocked, and a semantic testing framework (like integration_test on a supported platform) must be configured for the remaining UI flows to be verified.