# Frontend Architecture & Integration Overview

## 1. Core Principles
- **Cross-Platform:** The application is built in Flutter, targeting Mobile (Android/iOS) for field staff, and Web/Desktop for office administrators.
- **Offline-First Capability:** Given field operations in remote sites, critical modules (Logistics & Execution) must support offline read/write.
- **State Management & Architecture:** Feature-based folder structure (`lib/features/`). State management will handle real-time sync status and RBAC (Role-Based Access Control) visibility.
- **Ghost Mode:** UI elements rendering financial data (Quotations, Orders, Payments) must check the local token claims. If `ghost_mode` is false, hide any cash-related filters or indicators.

## 2. Infrastructure Components
- **API Client (`lib/core/network/api_client.dart`):** Dio-based HTTP client with interceptors for JWT injection, token refresh, and global error handling (e.g., 401 redirects to PIN/Login).
- **Local Database (`lib/core/database/database_helper.dart`):** SQLite (via `sqflite`) for caching vendor directories, installer directories, and queuing offline site updates.
- **Secure Storage:** `flutter_secure_storage` to persist the JWT, Refresh Token, and User Profile.
- **Sync Manager:** A background service that listens to network connectivity changes and flushes SQLite queues (like Dispatch Logs and Site Updates) to the backend automatically.

## 3. UI Component Library (Shared)
- **BaseScaffold:** Standard layout with a drawer/sidebar, dynamic app bar title, and offline status banner.
- **RBACBuilder:** A wrapper widget that conditionally renders children based on the user's role (e.g., hiding "Create User" from staff).
- **OfflineSyncBanner:** A floating indicator showing "X items pending sync... Reconnecting."
- **SignaturePad:** A reusable canvas widget for capturing client sign-offs, outputting to a PNG byte array for MinIO upload.