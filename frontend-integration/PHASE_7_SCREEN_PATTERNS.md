# Phase 7: UI Screen Integration Patterns

## Completed ✅

### CRM Module

- **crm_leads_screen.dart** ✅ (298 lines)
  - Pattern: SQLite-backed list with create/filter/status display
  - Key Features: Leads FutureProvider, create dialog, status filtering, card builder
  - Analyzer: No issues found ✅

## Remaining Screens (7 remaining)

### HR Module (3 screens)

#### 1. my_attendance_screen.dart

**Endpoint**: `GET /hr/attendance/me`
**Cached via**: boot-time sync
**Features**:

- Display today's check-in/check-out status
- Show check-in time button (if not checked in)
- Show check-out time button (if checked in)
- Show time entries list

**Pattern**:

```dart
final myAttendanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  // Query daily attendance from cache
});

// Check-in button action: POST /hr/attendance/checkin
await apiClient.post('/hr/attendance/checkin', data: {...});
ref.refresh(myAttendanceProvider); // Refresh UI

// Check-out button action: POST /hr/attendance/checkout
```

**Steps**:

1. Create `lib/features/hr/screens/my_attendance_screen.dart`
2. Add FutureProvider for today's attendance
3. Build AsyncValue.when() with loading/error/data states
4. Add check-in/check-out buttons with apiClient calls
5. Test with `flutter analyze --no-pub`

---

#### 2. my_leaves_screen.dart

**Endpoint**: `GET /hr/leaves/me`
**Cached via**: boot-time sync to leaves table
**Features**:

- Display leave balance (e.g., 15 days total, 3 used, 12 available)
- Show leave requests list with status colors
- Create new leave request dialog (date range + reason)
- Edit pending request capability
- Cancel pending request capability

**Pattern**:

```dart
final myLeavesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Return {balance: {total, used, available}, requests: [...]}
});

// Create leave: POST /hr/leaves/request
await apiClient.post('/hr/leaves/request', data: {
  'start_date': '2024-01-15',
  'end_date': '2024-01-17',
  'reason': 'Personal'
});
ref.refresh(myLeavesProvider);
```

**Status Color Coding**:

- pending → Orange
- approved → Green
- rejected → Red

**Steps**:

1. Create `lib/features/hr/screens/my_leaves_screen.dart`
2. Create leave request dialog with date picker
3. Display balance card at top
4. Build leave requests list with status colors
5. Add edit/cancel buttons on pending leaves
6. Test analyzer

---

#### 3. my_expenses_screen.dart

**Endpoint**: `GET /hr/expenses`
**Cached via**: boot-time sync to expenses table (similar to leads)
**Features**:

- Display expense items with category, amount, receipt image
- Create expense form with photo upload
- Mark expense as submitted (POST /hr/expenses/{id}/submit)
- Filter by status (draft, submitted, approved, rejected)

**Pattern**:

```dart
final myExpensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  return await dbHelper.getCachedExpenses();
});

// Create expense with photo:
// 1. Pick image via image_picker
// 2. Save to temp file
// 3. POST /hr/expenses with file_field_key: 'receipt_image'
await apiClient.uploadFile(
  endpoint: '/hr/expenses',
  fileFieldKey: 'receipt_image',
  localFilePath: pickedImage.path,
  otherData: {
    'category': 'food',
    'amount': '500.00',
    'description': 'Team lunch'
  }
);
```

**Steps**:

1. Create `lib/features/hr/screens/my_expenses_screen.dart`
2. Add image_picker integration for receipt photos
3. Create expense form with category dropdown
4. Display expense cards with photo thumbnails
5. Add submit button per expense
6. Test analyzer

---

### Logistics Module (2 screens)

#### 4. vendors_list_screen.dart

**Endpoint**: `GET /logistics/vendors`
**Cached via**: boot-time sync (cache_provider.dart)
**Features**:

- Display vendor list with company name, contact, phone, email
- Create new vendor form
- Edit vendor details
- Filter by status (active/inactive)

**Pattern**:

```dart
final vendorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  return await dbHelper.getCachedVendors();
});

// Create vendor: POST /logistics/vendors
await apiClient.post('/logistics/vendors', data: {
  'company_name': 'Vendor ABC',
  'contact_person': 'John Doe',
  'phone': '9876543210',
  'email': 'john@abc.com'
});
```

**Steps**:

1. Create `lib/features/logistics/screens/vendors_list_screen.dart`
2. Build vendor cards with contact info
3. Add create/edit dialogs
4. Display status with color coding
5. Test analyzer

---

#### 5. dispatch_recording_screen.dart

**Endpoint**: `POST /logistics/dispatch`
**Features**:

- Form to record dispatch event
- Select delivery/pickup type
- Add notes/special instructions
- Auto-capture timestamp
- Optional photo upload of delivery status

**Pattern**:

```dart
// Create dispatch record: POST /logistics/dispatch
final response = await apiClient.post('/logistics/dispatch', data: {
  'event_type': 'delivery_completed',
  'timestamp': DateTime.now().toIso8601String(),
  'notes': 'Delivered to main gate',
});
```

**Steps**:

1. Create `lib/features/logistics/screens/dispatch_recording_screen.dart`
2. Build form with event type dropdown
3. Add timestamp auto-population
4. Optional: Add photo capture for delivery proof
5. Test analyzer

---

### Execution Module (2 screens)

#### 6. installers_list_screen.dart

**Endpoint**: `GET /execution/installers`
**Cached via**: boot-time sync
**Features**:

- Display installer list with name, expertise area, rate, phone
- Create new installer
- Edit installer details
- Filter by expertise area

**Pattern**:

```dart
final installersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbHelper = DatabaseHelper.instance;
  return await dbHelper.getCachedInstallers();
});
```

**Steps**:

1. Create `lib/features/execution/screens/installers_list_screen.dart`
2. Build installer cards with expertise and rate
3. Add create/edit forms
4. Filter by expertise area
5. Test analyzer

---

#### 7. site_updates_screen.dart

**Endpoint**: `POST /execution/site-updates`
**Features**:

- Form for site update with description and photo
- Uses outbox queue for offline support
- Auto-upload photo, inject remote URL into payload
- Display recent updates

**Pattern**:

```dart
// Create site update with photo:
// 1. Pick image
// 2. Queue mutation with file_field_key: 'photo_url'
final mutation = {
  'endpoint': '/execution/site-updates',
  'method': 'POST',
  'payload': {
    'site_id': siteId,
    'description': 'Installation in progress',
    'photo_url': null, // Will be populated by SyncService
  },
  'has_file': true,
  'local_file_path': pickedImage.path,
  'file_field_key': 'photo_url',
};
await dbHelper.queueMutation(mutation);
```

**Steps**:

1. Create `lib/features/execution/screens/site_updates_screen.dart`
2. Add image_picker for photo capture
3. Implement outbox queue pattern
4. Show recent updates list
5. Test analyzer

---

#### 8. client_signoff_screen.dart

**Endpoint**: `POST /execution/signoff`
**Features**:

- Canvas for client signature capture
- Photo reference (before/after)
- Notes field
- Submit signature + photos to server

**Pattern**:

```dart
// Capture signature as image
// 1. Use signature package for canvas
// 2. Export signature as PNG
// 3. Upload with photo_before, photo_after, signature_image

final payload = {
  'site_id': siteId,
  'signature_image': null,
  'photo_before': null,
  'photo_after': null,
  'notes': signoffNotes,
};
// Queue mutations for each file
```

**Steps**:

1. Add signature package to pubspec.yaml
2. Create `lib/features/execution/screens/client_signoff_screen.dart`
3. Build signature canvas UI
4. Add before/after photo capture
5. Test analyzer

---

## Integration Checklist

For each screen:

- [ ] Create screen file in correct features folder
- [ ] Add FutureProvider for data (reading from SQLite)
- [ ] Build AsyncValue.when() with states
- [ ] Implement forms for mutations (if needed)
- [ ] Add apiClient endpoint calls
- [ ] Implement refresh pattern: `ref.refresh(provider)`
- [ ] Add error handling with SnackBar
- [ ] Run `flutter analyze --no-pub` - must pass
- [ ] Test on emulator/device (Phase 14)

## Testing Before Advance

After each screen completion:

```bash
# Verify no analyzer errors
flutter analyze --no-pub lib/features/{module}/screens/{screen}.dart

# Verify no imports are broken
flutter pub get

# (Optional) Dry-run app build to catch runtime issues
flutter build apk --analyze-size 2>/dev/null || true
```

## Notes

- **Offline-First Pattern**: Always read lists from SQLite, never direct API GET
- **Mutations**: Always queue via outbox for offline support
- **File Uploads**: Use `file_field_key` to inject remote URL to specific payload field
- **Ghost Mode**: Wrap cash-related fields with `GhostModeAware` widget (Phase 10)
- **Caching**: Add new tables to `database_helper.dart` schema if needed

## Continuation

After completing all 8 screens → Phase 8: Form Validation & Error Handling
