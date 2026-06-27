# Phase 9: Image & Signature Capture Integration - Preview & Setup

## Overview

Phase 9 will add image capture (camera/gallery) and signature canvas to the remaining 3 screens, integrating with the Phase 8 validation and Phase 5 offline sync patterns.

## Screens to Enhance

### 1. **dispatch_recording_screen.dart** (Currently: 158 lines)

**Current State**: DateTime picker + event type buttons
**Enhancement**: Add timestamp verification (no future dates)
**Scope**:

- Add validation that event timestamp ≤ now
- Keep existing button-based event selection
- Event type is immutable once recorded

**Integration**:

```dart
// Phase 8 pattern continues
final timeError = FormValidators.validateDateTime(selectedTime);
if (timeError != null) { /* show error */ }
```

**Status**: Ready, minimal changes needed

---

### 2. **site_updates_screen.dart** (Currently: 186 lines)

**Current State**: Site ID + description + photo placeholder
**Enhancement**: Real camera/gallery photo capture
**Scope**:

- Add `image_picker` dependency
- Replace photo placeholder with actual ImagePicker call
- Store photo locally, queue in outbox with file_field_key='photo_url'
- Add file size validation (max 5MB)
- Show photo preview after selection

**Integration**:

```dart
final pickedImage = await ImagePicker().pickImage(
  source: ImageSource.camera,
  imageQuality: 80,
);

// Phase 8 validation pattern
final photoError = validatePhotoFile(pickedImage);
if (photoError != null) { /* show error */ }

// Phase 5 outbox pattern
await dbHelper.queueMutation({
  'endpoint': '/execution/site-updates',
  'method': 'POST',
  'payload': { /* ... */ },
  'has_file': true,
  'local_file_path': pickedImage.path,
  'file_field_key': 'photo_url',
});
```

**New Validators**:

```dart
// Photo file validation
FormValidators.validatePhotoFile(image, maxSizeMB=5)
  - Checks file exists
  - Validates size ≤ 5MB
  - Validates image format (jpg/png)
```

**Status**: Ready for implementation

---

### 3. **client_signoff_screen.dart** (Currently: 162 lines)

**Current State**: Site ID + before/after photos + signature placeholder
**Enhancement**: Real signature canvas + before/after photos
**Scope**:

- Add `signature` package for signature canvas
- Add two `image_picker` calls (before/after photos)
- Store all three files locally
- Queue signoff mutation with 3 files
- Add validation: signature must not be empty

**Integration**:

```dart
// Before photo
final beforePhoto = await ImagePicker().pickImage(
  source: ImageSource.camera,
  imageQuality: 90,
);

// After photo
final afterPhoto = await ImagePicker().pickImage(
  source: ImageSource.camera,
  imageQuality: 90,
);

// Signature canvas
final signatureImage = await _signaturePad.toPng();

// Phase 8 validation
if (beforePhoto == null) showError('Before photo required');
if (afterPhoto == null) showError('After photo required');
if (signatureImage.isEmpty) showError('Signature required');

// Phase 5 outbox with multiple files
// Note: Single mutation, but file upload handling needs enhancement
// to support multiple files
```

**UI Pattern**:

```dart
// Signature canvas with "Clear" button
Signature(
  controller: _signatureController,
  height: 200,
  backgroundColor: Colors.white,
)

// Before/After photo preview
Image.file(beforePhotoFile, height: 150)
Image.file(afterPhotoFile, height: 150)
```

**Status**: Requires multi-file support enhancement

---

## Package Dependencies to Add

### pubspec.yaml Additions

```yaml
dependencies:
  image_picker: ^1.0.0
  signature: ^5.3.0
  path_provider: ^2.1.0
  image: ^4.1.0
```

### Dependency Justification

- **image_picker**: Camera/gallery access (Android/iOS)
- **signature**: Signature canvas widget
- **path_provider**: Temporary file storage during capture
- **image**: Image manipulation (optional, for thumbnail generation)

---

## New Files to Create

### 1. Enhanced Validators Extension

**File**: `lib/core/utils/form_validators.dart` (ENHANCEMENT)
**Additions**:

```dart
static String? validatePhotoFile(XFile? image, {int maxSizeMB = 5}) {
  if (image == null) return 'Photo is required';
  final sizeBytes = File(image.path).lengthSync();
  if (sizeBytes > maxSizeMB * 1024 * 1024) {
    return 'Photo must be less than ${maxSizeMB}MB';
  }
  return null;
}

static String? validateDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'Date/time is required';
  if (dateTime.isAfter(DateTime.now())) {
    return 'Date/time cannot be in future';
  }
  return null;
}
```

### 2. Photo Preview Widget

**File**: `lib/core/widgets/photo_preview_widget.dart` (NEW)

```dart
class PhotoPreviewWidget extends StatelessWidget {
  final XFile? photo;
  final String label;
  final VoidCallback onCapture;
  final VoidCallback? onRemove;

  const PhotoPreviewWidget({
    required this.photo,
    required this.label,
    required this.onCapture,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return ElevatedButton.icon(
        onPressed: onCapture,
        icon: const Icon(Icons.camera_alt),
        label: Text('Capture $label'),
      );
    }

    return Column(
      children: [
        Image.file(File(photo!.path), height: 150, fit: BoxFit.cover),
        ElevatedButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete),
          label: Text('Remove $label'),
        ),
      ],
    );
  }
}
```

### 3. Signature Canvas Widget

**File**: `lib/core/widgets/signature_canvas_widget.dart` (NEW)

```dart
class SignatureCanvasWidget extends StatefulWidget {
  final Function(Uint8List) onSignatureComplete;

  const SignatureCanvasWidget({
    required this.onSignatureComplete,
  });

  @override
  State<SignatureCanvasWidget> createState() => _SignatureCanvasWidgetState();
}

class _SignatureCanvasWidgetState extends State<SignatureCanvasWidget> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 5,
      penColor: Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Signature(
          controller: _controller,
          height: 200,
          backgroundColor: Colors.white,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _controller.clear,
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () async {
                final sig = await _controller.toPng();
                widget.onSignatureComplete(sig!);
              },
              child: const Text('Save Signature'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## Integration Sequence

### Step 1: Package Addition

```bash
cd frontend
flutter pub add image_picker signature path_provider image
flutter pub get
```

### Step 2: Android Permissions (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### Step 3: iOS Permissions (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access</string>
```

### Step 4: Screen-by-Screen Implementation

#### 4a. dispatch_recording_screen.dart

```dart
// Minimal changes: Add datetime validation
final timeError = FormValidators.validateDateTime(selectedDateTime);
if (timeError != null) { /* show snackbar */ }

// Keep existing event button logic
```

**Estimated**: 30 minutes
**Analyzer**: 0 issues expected

#### 4b. site_updates_screen.dart

```dart
// Add image picker
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/photo_preview_widget.dart';

// Add state variable
XFile? _selectedPhoto;

// Add picker button
PhotoPreviewWidget(
  photo: _selectedPhoto,
  label: 'Site Photo',
  onCapture: () async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    setState(() => _selectedPhoto = photo);
  },
  onRemove: () => setState(() => _selectedPhoto = null),
)

// Add validation in create dialog
final photoError = FormValidators.validatePhotoFile(_selectedPhoto);

// Queue mutation with file
await dbHelper.queueMutation({
  'endpoint': '/execution/site-updates',
  'method': 'POST',
  'payload': { /* ... */ },
  'has_file': _selectedPhoto != null,
  'local_file_path': _selectedPhoto?.path,
  'file_field_key': 'photo_url',
});
```

**Estimated**: 1.5 hours
**Analyzer**: 0 issues expected

#### 4c. client_signoff_screen.dart

```dart
// Add signature import
import '../../../core/widgets/signature_canvas_widget.dart';

// Add state variables
XFile? _beforePhoto;
XFile? _afterPhoto;
Uint8List? _signature;

// Build UI
PhotoPreviewWidget(
  photo: _beforePhoto,
  label: 'Before',
  onCapture: () { /* ... */ },
)

PhotoPreviewWidget(
  photo: _afterPhoto,
  label: 'After',
  onCapture: () { /* ... */ },
)

SignatureCanvasWidget(
  onSignatureComplete: (sig) {
    setState(() => _signature = sig);
  },
)

// Validation
final beforeError = FormValidators.validatePhotoFile(_beforePhoto);
final afterError = FormValidators.validatePhotoFile(_afterPhoto);
if (_signature == null) showError('Signature required');

// Queue mutations (one per file + signature)
```

**Estimated**: 2 hours
**Analyzer**: 0 issues expected
**Note**: Requires multi-file support (Phase 9 enhancement)

---

## Multi-File Handling Enhancement

### Challenge

Current outbox_queue supports single file per mutation. Signoff needs 3 files (before, after, signature).

### Solution Options

**Option A**: Multiple Mutations (Recommended)

```dart
// Create 3 mutations for 1 signoff action
const signoffId = uuid.v4();

// Mutation 1: Before photo
await dbHelper.queueMutation({
  'endpoint': '/execution/signoff',
  'method': 'POST_BEFORE_PHOTO',
  'payload': {'signoff_id': signoffId, 'type': 'before'},
  'file_field_key': 'before_photo_url',
  'local_file_path': beforePhoto.path,
});

// Mutation 2: After photo
// Similar...

// Mutation 3: Signature
// Similar...
```

**Option B**: Single Mutation with Metadata
Enhance SyncService to handle multiple files per mutation:

```dart
// outbox_queue schema enhancement
'files': [
  {'field': 'before_photo_url', 'path': '...'},
  {'field': 'after_photo_url', 'path': '...'},
  {'field': 'signature_url', 'path': '...'},
]
```

**Recommendation**: Use Option A (simpler, less schema change)

---

## Testing Plan

### Unit Tests

```dart
// Test file size validation
test('photo validation rejects files > 5MB', () {
  expect(
    FormValidators.validatePhotoFile(largePhoto),
    contains('less than 5MB'),
  );
});

// Test datetime validation
test('datetime validation rejects future dates', () {
  final future = DateTime.now().add(Duration(hours: 1));
  expect(
    FormValidators.validateDateTime(future),
    isNotNull,
  );
});
```

### Integration Tests

```dart
// Test photo capture flow
testWidgets('Site update captures and queues photo', (tester) async {
  await tester.tap(find.byIcon(Icons.camera_alt));
  // Verify photo preview shown
  // Verify mutation queued on submit
});

// Test signature capture
testWidgets('Client signoff captures signature', (tester) async {
  await tester.tap(find.byType(Signature));
  // Draw signature
  await tester.tap(find.byText('Save Signature'));
  // Verify signature stored
});
```

### Manual Testing

1. Capture photo from camera
2. Capture photo from gallery
3. Test file size limit (try large file)
4. Draw signature and clear
5. Submit with all files offline
6. Verify SyncService uploads all files on online

---

## Timeline Estimate

| Task                               | Duration       | Status                           |
| ---------------------------------- | -------------- | -------------------------------- |
| Add package dependencies           | 15 min         | Ready                            |
| Add Android/iOS permissions        | 15 min         | Ready                            |
| Create validator extensions        | 20 min         | Ready                            |
| Create PhotoPreviewWidget          | 30 min         | Ready                            |
| Create SignatureCanvasWidget       | 30 min         | Ready                            |
| Enhance dispatch_recording_screen  | 30 min         | Ready                            |
| Enhance site_updates_screen        | 1.5 hrs        | Ready                            |
| Enhance client_signoff_screen      | 2 hrs          | Ready (needs multi-file support) |
| Test all three screens             | 1.5 hrs        | Plan                             |
| Multi-file SyncService enhancement | 1 hr           | Optional enhancement             |
| **Total Phase 9**                  | **~7.5 hours** | **Estimated**                    |

---

## Success Criteria

✅ All screens pass analyzer (0 issues)
✅ Photo capture works on Android emulator/device
✅ Photo capture works on iOS simulator/device
✅ Signature canvas captures readable signature
✅ File size validation prevents large uploads
✅ Files queue correctly in outbox_queue
✅ SyncService uploads all files when online
✅ Offline photos appear in next sync
✅ User can retake/remove photos before submit
✅ Clear button works on signature canvas

---

## Risk Mitigation

| Risk                            | Mitigation                                              |
| ------------------------------- | ------------------------------------------------------- |
| Image picker permissions denied | Show friendly error, fallback to text description       |
| Signature canvas crashes        | Validate canvas widget, add error handling              |
| Large file crashes app          | Validate file size before queuing                       |
| Multi-file sync issues          | Start with single-file screens (dispatch, site-updates) |
| Device storage full             | Check available space before capture                    |
| Network timeout during upload   | SyncService already handles with retry logic            |

---

## Documentation Deliverables

- Phase 9 Implementation Guide (similar to Phase 8)
- Photo & Signature Capture Testing Report
- Before/After code comparison (image picker integration)
- API endpoint documentation updates (if needed)

---

## Next Steps After Phase 9

### Phase 10: Ghost Mode Enforcement

- Wrap all cash-related fields with GhostModeAware
- Hide amounts when isGhostMode = true
- Test ghost mode toggle visibility

### Phase 11: Integration Testing

- End-to-end flow tests
- Offline/online sync validation
- Ghost mode security testing

### Phase 12: Performance & QA

- App profiling
- Memory leak checks
- Battery/network optimization

### Phase 13: Documentation & Store Prep

- Screenshots for app stores
- Release notes
- Privacy policy updates

---

## Ready to Start Phase 9?

Once Phase 8 is fully tested and merged, Phase 9 is ready to begin. The implementation sequence is clear:

1. ✅ Add packages
2. ✅ Create widgets
3. ✅ Enhance validators
4. ✅ Update dispatch screen (easiest)
5. ✅ Update site-updates screen (medium)
6. ✅ Update client-signoff screen (hardest, needs multi-file logic)
7. ✅ Test all changes
8. ✅ Verify analyzer compliance

**Current Status**: Phase 8 Complete ✅ → Phase 9 Ready to Go 🚀
