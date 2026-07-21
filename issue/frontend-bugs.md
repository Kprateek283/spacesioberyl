# Frontend — Problems & Bugs

Audit date: 2026-07-20 · Branch `dev` @ `a71d86f` · Flutter 3.5 / Riverpod / go_router / Dio / sqflite

`flutter analyze` reports **15 issues: 7 errors, 8 info**. The 7 errors are all in
`integration_test/qa_unified_ux_test.dart` (item #4). Everything else below
compiles and analyses clean.

---

## P0 — Critical

### 1. Every non-super-admin user is locked out of the app

`lib/core/routes/router.dart:40` + `lib/features/auth/providers/auth_provider.dart:77,132`

The router forces PIN entry for everyone:

```dart
if (!auth.sessionUnlocked) return '/pin-entry';
```

and both `login()` and `checkAuthStatus()` hardcode:

```dart
sessionUnlocked: false, // PIN verification is required for every role
```

`sessionUnlocked` is only ever set true by a successful `verifyPin()`. But the
backend can never succeed for a non-super-admin:

- `IAMService.SetupPins` rejects anyone who is not `super_admin`
  (`backend/internal/iam/service/iam_service.go:94-96`), and `/iam/setup-pins`
  is additionally gated by `RequireRole("super_admin")`.
- `IAMService.VerifyPin` returns `"PINs have not been set up"` whenever
  `user.PinHash == nil` (`iam_service.go:146-148`), which is the permanent
  state for every non-super-admin account.

So a sales or HR user logs in successfully, is redirected to `/pin-entry`, and
every PIN they type returns 401. There is no skip path and no other route
reachable. **The app is usable only by super_admin.**

**Fix:** decide the intended contract. Either the backend allows all roles to
set up a normal PIN, or the client only gates on PIN when the role requires it
(gate `sessionUnlocked` on `userRole == 'super_admin'`). The current split
satisfies neither side.

### 2. Ghost Mode is implemented backwards

`lib/core/widgets/ghost_mode_aware.dart:8,26,50,79`

```dart
/// Ghost mode = HIGH-SECURITY PIN used → cash data and sensitive financial fields hidden.
if (authState.isGhostMode && hideInGhostMode) {
  return fallback ?? const SizedBox.shrink();
}
```

The backend contract is the exact opposite — `ghost_mode == true` means cash is
**visible**:

```go
// backend/internal/crm/repository/quotation_repo.go:89
if !ghostMode { query += " AND payment_term_type != 'cash'" }

// backend/internal/crm/service/quotation_svc.go:31
if req.PaymentTermType == "cash" && !middleware.GetGhostMode(ctx) {
	return nil, errors.New("cash payment terms require ghost mode to be enabled")
}
```

Two concrete failures:

- **High-security PIN** → server returns cash quotations, `GhostModeAware` hides
  them. The feature's entire purpose is defeated.
- **Normal PIN** → `GhostAwareCashField` renders cash inputs, user fills them in,
  `POST /crm/leads/{id}/quotations` rejects with *"cash payment terms require
  ghost mode to be enabled"*. Unexplainable error for the user.

All three widgets (`GhostModeAware`, `GhostAwareCashText`, `GhostAwareCashField`)
have the condition inverted. Fixing is a one-line flip in each, plus the doc
comment — but confirm the intended product semantics first, because the naming
("ghost" = hidden) is what misled the implementation.

### 3. File uploads are faked — photos and signatures are silently discarded

`lib/core/network/mock_upload_service.dart`, used by
`lib/core/network/sync_service.dart:92` and
`lib/features/execution/services/execution_service.dart:170`

```dart
static String toMockUrl(String localPath, {String bucket = 'mock-uploads'}) {
  final fileName = p.basename(localPath).replaceAll(' ', '_');
  return 'https://mock.local/$bucket/$safeName';
}
```

Every file the user captures — site update photos, contractor check-in proof
photos, client sign-off signatures, expense receipts — is replaced with a
fabricated `https://mock.local/...` URL and never transmitted. The local file is
not uploaded anywhere. The API call succeeds, the record persists, and the URL
points at a domain that does not exist.

This is wired into the production sync path, not behind a debug flag. Users
believe their evidence is captured; it is gone the moment the device cache is
cleared. For contractor sign-off in particular this destroys the financial audit
trail.

The backend has a working MinIO uploader (`internal/storage/minio.go`) but
exposes it only through `POST /api/v1/projects/{id}/docs`. A generic upload
endpoint is needed, then delete `MockUploadService` entirely.

---

## P1 — High

### 4. The newest integration test does not compile

`integration_test/qa_unified_ux_test.dart` — 7 analyzer errors, all
`undefined_identifier` for `TextFormField`, `TextField`, `ElevatedButton`, `Text`.
The file is missing `import 'package:flutter/material.dart';`.

This is the test added in the most recent commit (`a71d86f`, *"deep functional
UI test for interactive components and PageView gestures"*). It has never run.

**Fix:** add the import. One line.

### 5. Users are logged out after 1 hour despite a 30-day refresh token

`lib/features/auth/providers/auth_provider.dart:65`

```dart
if (token != null && !JwtDecoder.isExpired(token) && userString != null) {
```

On cold start this checks only the *access* token, which the backend issues with
a 1-hour TTL (`backend/internal/iam/service/jwt.go:42`). If it has expired the
else-branch resets to a signed-out `AuthState` and the router sends the user to
`/login` — even though a valid 30-day refresh token is sitting in secure storage
and the Dio interceptor is fully capable of using it.

The refresh machinery only ever fires on a 401 from a live request, which never
happens because the app never gets past the login gate. The 30-day session
exists in the backend and is unreachable from the client.

**Fix:** if the access token is expired but a refresh token exists, attempt
`/refresh` in `checkAuthStatus` before falling back to signed-out.

### 6. Requests can hang forever — no receive or send timeout

`lib/core/network/api_client.dart:14-17`

```dart
final Dio _dio = Dio(BaseOptions(
  baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8080/api/v1',
  connectTimeout: const Duration(seconds: 15),
));
```

Only `connectTimeout` is set. A server that accepts the connection then stalls
(the backend has no write timeout either — see backend report #17) leaves the
request pending indefinitely, with the UI stuck on its loading spinner and no
way out but killing the app.

The two throwaway `Dio` instances in `_handle401Error` (`:67`) and
`_retryOriginalRequest` (`:140`) set *no* timeouts at all, so a stalled refresh
hangs every queued request behind it.

**Fix:** set `receiveTimeout` and `sendTimeout` on all three.

### 7. Race in the 401 refresh queue can strand requests permanently

`lib/core/network/api_client.dart:85-120`

```dart
final queued = List.of(_retryQueue);
_retryQueue.clear();
for (final item in queued) { ... await ... }
// ... later
} finally {
  _isRefreshing = false;
}
```

`_isRefreshing` is a plain bool, and the drain loop `await`s. A request that
401s after `_retryQueue.clear()` but before `_isRefreshing = false` takes the
`else` branch at `:116`, is appended to a queue nobody will ever drain, and its
`ErrorInterceptorHandler` is never resolved or rejected. The caller's `Future`
never completes — a permanently hung request and a leaked handler.

The comment at `:21-23` shows the author knew about the hang risk and fixed the
common case; this narrow window survives.

**Fix:** hold a single `Completer<void>` for the in-flight refresh and have
latecomers `await` it, rather than gating on a mutable bool.

### 8. One bad mutation blocks the entire offline outbox

`lib/core/network/sync_service.dart:102-105`

```dart
} catch (_) {
  await dbHelper.incrementRetryCount(id);
  break;          // <-- stops the whole queue
}
```

`break` exits the loop on the first failure, so a single permanently-failing
mutation (a 400 from a validation error, say) blocks every later queued
mutation — head-of-line blocking. Those later items are perfectly valid and
would succeed.

It takes 5 sync cycles for the poison item to be dropped, and cycles only occur
on a connectivity transition (`:42-50`) or a manual trigger. A device that stays
online never transitions, so the queue can sit stuck indefinitely.

**Fix:** `continue` instead of `break`, and add a periodic retry timer rather
than relying solely on connectivity events.

### 9. Failed mutations are deleted after 5 attempts

`lib/core/network/sync_service.dart:80-84`

```dart
if (retryCount >= 5) {
  await dbHelper.removeMutation(id);
  onMutationDropped?.call(endpoint);
  continue;
}
```

The user's data is destroyed. `droppedMutationsProvider` surfaces the endpoint
string in the UI, which is better than nothing, but the payload itself is
unrecoverable — the user cannot see what was lost or retry it. For an offline-
first field app (site updates, expenses) this is a real data-loss path.

**Fix:** move exhausted mutations to a `failed` state instead of deleting, and
give the user a screen to inspect and retry them.

---

## P2 — Medium

### 10. Cleartext HTTP by default, no certificate pinning

`.env` ships `API_URL=http://localhost:8080/api/v1` and it is bundled as a
Flutter **asset** (`pubspec.yaml:` `assets: - .env`), so it is extractable from
any built APK. Today it holds only the URL, which is harmless — but the pattern
invites putting a secret there later, where it would be trivially recoverable.

The `http://` fallback is hardcoded twice in `api_client.dart` (`:12`, `:15`).
Any build that ships without a correct `.env` sends JWTs and passwords in the
clear.

**Fix:** use `--dart-define` for the API URL rather than a bundled asset; assert
`https://` in release builds; consider pinning given the financial data.

### 11. 17 files blanket-suppress `use_build_context_synchronously`

```
// ignore_for_file: use_build_context_synchronously
```

at line 1 of `iam_users_screen.dart`, `admin_leaves_screen.dart`,
`my_expenses_screen.dart`, `profile_screen.dart`, `my_attendance_screen.dart`,
`my_leaves_screen.dart`, `vendors_list_screen.dart`,
`dispatch_recording_screen.dart`, `client_signoff_screen.dart`,
`installers_list_screen.dart` and 7 more (28 `// ignore` directives total across
`lib/`).

File-level suppression turns off the lint for every async gap in the file, not
just the reviewed one. This lint catches a genuine crash class — using
`context` after an `await` when the widget has been disposed. Suppressing it
wholesale across the entire screen layer means those crashes will surface in
production instead of in analysis.

**Fix:** delete the directives and add `if (!mounted) return;` after each await
that precedes a `context` use. Mechanical, and it restores the safety net.

### 12. No role-based route guards

`lib/core/routes/router.dart:33-46` — the `redirect` callback checks auth state
only. `/logistics`, `/execution`, `/crm` and `/hr` are reachable by any
authenticated role; the role is passed to the widget as a bare `isAdmin` bool
(`:77`, `:89`, `:97`) for cosmetic hiding.

That is acceptable *if* the backend enforces authorization — mostly it does, but
the BFF module does not (backend report #1), so `/home` genuinely leaks data it
should not.

### 13. Silent no-op when a mutation returns non-200

`lib/features/auth/providers/auth_provider.dart:156-159`, `:173-188`

```dart
if (response.statusCode == 200) {
  ...
}
// no else — isLoading stays true
```

Both `setupPins` and `verifyPin` leave `isLoading: true` forever on any non-200
that Dio does not throw for (a 2xx-but-not-200, or a custom `validateStatus`).
The UI spins with no error and no recovery. Add an `else` that resets loading
and surfaces the failure.

### 14. `logout()` clears local state before the network call

`lib/features/auth/providers/auth_provider.dart:195-206`

```dart
state = AuthState(isLoading: false);   // UI flips to signed-out
try { await _apiClient.post('/logout'); } catch (_) {}
await _storage.delete(key: 'jwt');
```

The optimistic UI update is deliberate and reasonable, but the `catch (_) {}`
means a failed server-side logout is invisible. Given the backend does not
revoke refresh tokens on logout at all (backend report #7), the user's session
remains live server-side while the UI claims they are signed out.

### 15. Inconsistent project structure

`lib/screens/auth/login_screen.dart` sits outside the feature-first layout used
everywhere else (`lib/features/auth/screens/pin_entry_screen.dart`,
`pin_setup_screen.dart`). `lib/screens/` exists solely for that one file. Move it
into `lib/features/auth/screens/` and delete the directory.

### 16. Dead dependencies

`pubspec.yaml` declares `riverpod_annotation` + `riverpod_generator` +
`build_runner`, but no `@riverpod` annotations or `.g.dart` files exist —
everything uses manual `Provider`/`StateNotifierProvider` declarations. Also
`jwt_decoder` is used in exactly one place. Drop the codegen trio, or adopt it;
carrying both styles is the worst of the two.

### 17. Dependencies are far behind

`flutter pub outdated` reports **83 packages with newer versions blocked by
current constraints**, including `riverpod` 2.6.1 → 3.3.2 and
`riverpod_annotation` 2.6.1 → 4.0.3 (two major versions). The longer this sits,
the more painful the eventual upgrade.

---

## P3 — Low / hygiene

### 18. `print` in checked-in test code
8 analyzer `avoid_print` infos in `test/check_db.dart` (`:16,18,26,28,31,36,38`)
and `integration_test/qa_unified_ux_test.dart:57`.

### 19. `baseUrl` read twice from dotenv
`api_client.dart:12` (static getter) and `:15` (instance field) read
`dotenv.env['API_URL']` independently with duplicated fallbacks. Collapse to
the single getter.

### 20. No unit or widget tests for business logic
`test/` contains only `check_db.dart` (a manual sqflite inspection script). The
sync outbox retry logic, the 401 refresh queue and the ghost-mode widgets — the
three most defect-prone areas in this report — have zero coverage. Items #2, #7
and #8 would all have been caught by one small test each.

---

## What is done well

- Tokens are stored in `flutter_secure_storage` (Keychain / EncryptedSharedPreferences),
  not `SharedPreferences`.
- The Dio interceptor correctly excludes `/login`, `/refresh` and `/verify-pin`
  from both token injection and 401-retry, avoiding an infinite refresh loop.
- The offline outbox pattern (`sqflite` queue + connectivity listener + retry
  counter) is the right architecture for a field app, and `droppedMutationsProvider`
  shows real thought about not losing user data silently — the bugs in it (#8, #9)
  are refinements to a sound design, not a rewrite.
- `_setNestedField` (`sync_service.dart:115-137`) correctly handles both map keys
  and list indices in dotted paths, and bails safely on unresolvable paths.
- Auth state is centralised in one `StateNotifier` and the router reacts to it via
  `refreshListenable` — no scattered navigation logic.
