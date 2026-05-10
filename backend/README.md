# Spacesio Beryl - Backend Architecture

This directory contains the backend microservices, database migrations, and background workers for the Spacesio Beryl CRM & ERP. The system is built using a domain-driven design, cleanly separating business logic across five core operational modules.

## Tech Stack

*   Language: Go (Golang) 1.25+
*   Database: PostgreSQL 17 (Primary transactional store)
*   Cache: Redis (Session caching and temporary state)
*   Message Broker: RabbitMQ (Asynchronous worker queues and cross-module event handoffs)
*   Object Storage: MinIO (S3-compatible storage for PDFs, receipts, and site photos)
*   Deployment: Docker & Docker Compose

---

## Core Modules

The architecture is divided into five strictly bounded domains located in internal/:

### 1. IAM (Identity & Access Management)
Handles Role-Based Access Control (RBAC) and authentication.
*   Feature: JWT issuance with embedded role and department claims.
*   Security (Ghost Mode): A dual-PIN authentication system. Logging in with the Super Admin's "High-Security PIN" injects a ghost_mode: true claim into the JWT, globally revealing cash-based financial records across the system.

### 2. Internal HR & Administration
Handles daily office operations.
*   Attendance: IP-fenced check-in/check-out with manual manager overrides for field staff.
*   Leaves: State-machine based leave tracking (pending -> approved/rejected).
*   Expenses: Daily ledger for office expenses with receipt image uploads.

### 3. CRM & Sales Pipeline
Tracks the revenue lifecycle.
*   Leads: Kanban-style pipeline progression.
*   Quotations: Dynamic line-item generation, tax calculation, and payment terms definition.
*   Complaints: Post-sale support ticketing linked to clients.

### 4. Supply Chain & Logistics
Executes on approved sales.
*   Procurement: Converts approved CRM quotes into manageable Orders and Purchase Orders (POs) targeting specific Vendors.
*   Dispatches: Time-stamped tracking for "Dispatch" (left warehouse) and "Delivery" (arrived at site) events.

### 5. Field Execution & Installation
Manages external contractors and site completion.
*   Contractor Management: Directories, rate tracking, and daily presence verification.
*   Site Updates: Timeline of photo and text updates from the field.
*   Financial Lock: External contractors cannot receive their "Final Discharge" payment until the client has physically signed the digital completion document.

---

## Detailed Documentation

For an in-depth understanding of the backend integration, please refer to the following handover documents:

*   **[API Contracts](api_contracts.md):** An exhaustive list of all 70+ REST API endpoints. This document details the HTTP methods, exact JSON request payloads, and expected responses for every module.
*   **[Module Flows & Architecture](module_flows.md):** A comprehensive guide to the internal state machines (e.g., Leave approval rules) and inter-module event-driven architecture. This document explains how edge cases are handled (like missing network during dispatch or lead loss) and how modules communicate via RabbitMQ.

---

## Background Workers

To keep the primary HTTP API fast and responsive, heavy tasks and cross-module communications are offloaded to RabbitMQ and handled by the Go worker process (cmd/worker/main.go):

*   Event Handoffs: e.g., When a CRM Quotation is marked client_approved, the API fires an event. The worker consumes this and creates the physical Order in the Logistics module.
*   Notifications: The whatsapp_worker.go safely handles outbound HTTP requests to the Meta Cloud API for automated client updates.
*   Cron Jobs: Internal tickers run periodically to escalate unresolved support complaints and flag missed sales follow-ups.

---

## Getting Started

### Prerequisites
*   Docker & Docker Compose

### Running Locally
The entire stack is configured to run locally via Docker Compose.

1.  Configure Environment:
    Ensure you have an .env file in the root system-v1/ directory.

2.  Start the Infrastructure:
    ```bash
    docker compose up -d --build
    ```
    This spins up PostgreSQL, Redis, RabbitMQ, MinIO, the Go API server, and the Go Worker.

3.  Database Migrations:
    Upon booting, the Go API container automatically runs golang-migrate to execute all SQL schemas located in backend/db/migrations/, seeding the database with the default Super Admin account.

### API Testing
A comprehensive Postman collection (Spacesio_Beryl_Postman.json) is provided in the project root. It contains 70+ requests mapping to every backend route, including negative tests to verify business logic constraints.

---

## Testing
The backend business logic (such as Ghost Mode token generation and Leave state constraints) can be tested natively using Go's testing suite. We also utilize Go's built-in Fuzzing to ensure the HTTP handlers are memory-safe against arbitrary JSON payloads.

```bash
cd backend
go test ./tests -v
go test ./tests -fuzz=FuzzCreateComplaintAPI -fuzztime=10s
```