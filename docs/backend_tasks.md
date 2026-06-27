# Backend Engineering Task List

This document outlines all bugs and tasks identified during the QA testing phase that fall under the scope of the backend engineering team.

## Collaboration Required (Frontend + Backend)

#### BUG-B01: Lead Status Enum Mismatch [Severity: HIGH]
- **Type:** Backend / Logical Error
- **File:** `backend/internal/crm/service/lead_svc.go`
- **Description:** The `validLeadStatuses` map uses `first_call` but the API contracts documentation lists `contacted` as a valid status. The frontend testing guide also references statuses inconsistent with what the backend accepts.
- **Valid statuses in code:** `new, first_call, pdf_sent, sample_sent, site_visit, negotiation, finalized, lost`
- **Documented statuses:** `contacted, negotiation` (in `api_contracts.md`)
- **Impact:** Frontend forms sending `contacted` will receive 400 errors.
- **Fix:** Coordinate with the Frontend engineer to decide on a single source of truth. Either update the backend enum to include `contacted` or update all docs/frontend to use `first_call`.

---

## Core Backend Bugs

#### BUG-B02: Logistics Module Missing Service Layer [Severity: MEDIUM]
- **Type:** Backend / Architecture
- **File:** `backend/internal/app/app.go`
- **Description:** The Logistics module skips the service layer entirely. The handler directly calls the repository. All other modules follow handler -> service -> repository pattern.
- **Fix:** Refactor the module to introduce a proper service layer to encapsulate business logic.

#### BUG-B03: Ghost Mode Not Enforced on Quotation Creation [Severity: HIGH]
- **Type:** Backend / Security / Logical Error
- **File:** `backend/internal/crm/service/quotation_svc.go`
- **Description:** The `Create` method in `QuotationService` never checks the `ghost_mode` claim from the JWT context. Any authenticated user can create a quotation with `payment_term_type: "cash"`.
- **Fix:** Extract `ghost_mode` from the context and reject `cash` payment terms when `ghost_mode == false`.

#### BUG-B04: OTP Generation Truncation Risk [Severity: LOW]
- **Type:** Backend / Logical Error
- **File:** `backend/internal/iam/service/iam_service.go`
- **Description:** OTP generation truncates an 8-character string, leading to non-uniform distributions.
- **Fix:** Use a modulo operator (`% 1000000`) instead of string truncation for secure 6-digit distributions.

#### BUG-B05: `strconv.Atoi` Errors Silently Ignored in Logistics/Execution [Severity: MEDIUM]
- **Type:** Backend / Error Handling
- **Files:** `logistics_handler.go`, `execution_handler.go`
- **Description:** Handlers ignore `strconv.Atoi` errors on URL parameters.
- **Fix:** Check `err` and return a `400 Bad Request` if parsing fails.

#### BUG-B06: Missing `down.sql` for Seed Migration [Severity: LOW]
- **Type:** Backend / Database
- **Description:** `000002_seed_default_iam.up.sql` lacks a rollback script.
- **Fix:** Create `000002_seed_default_iam.down.sql` to delete seeded users.

#### BUG-B07: RabbitMQ Global Mutable State [Severity: MEDIUM]
- **Type:** Backend / Concurrency
- **File:** `backend/internal/broker/rabbitmq.go`
- **Description:** Package-level globals for AMQP channels are not safe for concurrent use.
- **Fix:** Use a channel pool or create a channel per publish call.

#### BUG-B08: MinIO URL Points to Internal Docker Hostname [Severity: MEDIUM]
- **Type:** Backend / Configuration
- **File:** `backend/internal/storage/minio.go`
- **Description:** File URLs are returned as `minio:9000`, which is inaccessible to clients.
- **Fix:** Use a configurable public base URL.

---

## Flow & Integration Logic

#### BUG-I01: Quote->Order Handoff Has No Idempotency [Severity: MEDIUM]
- **Description:** The `quote_approved` consumer uses `auto-ack=true`. Messages are lost if order creation fails.
- **Fix:** Implement manual acks (`auto-ack=false`) upon successful DB commit.

#### BUG-I02: WhatsApp Notifications Fire-and-Forget in Goroutines [Severity: LOW]
- **Description:** Context escapes the HTTP request scope via `context.Background()` during notification publishing.

#### BUG-I03: Complaint Escalation Threshold Inconsistency [Severity: LOW]
- **Description:** Mismatch between documentation (48 hrs) and code (72 hrs / 3 days).

#### BUG-I04: Follow-Up Cancellation on Lead Loss Not Implemented [Severity: MEDIUM]
- **Description:** Lead `lost` status does not trigger automatic cancellation of follow-ups.

#### BUG-I05: Order Status Not Updated After PO Creation [Severity: MEDIUM]
- **Description:** Parent orders are not transitioned to `partially_ordered` or `ready_for_dispatch` after POs are generated.

#### BUG-I06: No Database Transaction in Quotation Creation [Severity: MEDIUM]
- **Description:** Lack of explicit transactions across quotation headers and line items.

---

## Security & Documentation

#### SEC-01: JWT Secret Hardcoded as "secret" [Severity: CRITICAL]
- **Fix:** Use a cryptographically secure string in `.env`.

#### SEC-02: WhatsApp Token Committed to Repository [Severity: CRITICAL]
- **Fix:** Remove real tokens, add `.env` to `.gitignore`.

#### SEC-03: No Rate Limiting on Authentication Endpoints [Severity: HIGH]
- **Fix:** Add rate limiting middleware.

#### SEC-04: Password Hash Returned in ListUsers [Severity: HIGH]
- **Fix:** Exclude sensitive columns from raw repository queries.

#### DOC-01 & DOC-02: API Contract Mismatches
- **Fix:** Update `api_contracts.md` regarding lead statuses and 201 Created codes.
