# Ghost Mode — the cash-visibility contract

This is the single source of truth for Ghost Mode. The backend is **canonical**.
If a client ever appears to disagree with this document, the client is wrong and
must be changed — never invert the backend to match it.

## The direction (do not get this backwards)

```
ghost_mode == true   →  cash transactions ARE visible
ghost_mode == false  →  cash transactions are HIDDEN (the safe default)
```

`ghost_mode` is a claim on the access token, set when a user unlocks with the
high-security PIN (`GenerateGhostModeTokens`). Absence of the claim, an
unauthenticated request, or any error resolves to `false` — cash stays hidden.
The filter **fails closed**.

Cash is the only role-restricted financial data: only a `super_admin` who has
unlocked ghost mode sees cash quotations. Everything else is visible to any
authenticated user.

## Where it is enforced

The filter is applied as a SQL predicate (`middleware.GetGhostMode` →
`cashFilter`) at every surface that can surface a cash amount:

| Surface | File |
|---|---|
| Quotation creation (a cash quote requires ghost mode) | `internal/crm/service/quotation_svc.go` |
| Quotation listing / fetch | `internal/crm/repository/quotation_repo.go` |
| Logistics order value | `internal/logistics/repository/logistics_repo.go` |
| BFF pipeline card value and personal timeline | `internal/bff/service.go` |

When ghost mode is off, a project whose only approved quotation is cash reports a
value of `0` — the row is not hidden, its cash amount is.

## The invariant, in tests

`internal/bff/ghost_mode_test.go` and `ghost_mode_integration_test.go` pin the
direction in both states and assert the fail-closed default. These tests exist
specifically to stop a future "fix" from flipping the backend to match a broken
client. If you change cash-filtering, they must still pass unchanged.
