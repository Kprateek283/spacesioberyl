// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../services/hr_service.dart';

// Riverpod provider for HR attendance
final myAttendanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final cached = await DatabaseHelper.instance.getCachedAttendance();
  if (cached.isNotEmpty) {
    return _normalizeAttendanceFromList(cached);
  }
  return _normalizeAttendance(const <String, dynamic>{});
});

class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen> {
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _refreshAttendanceCache();
      if (mounted) {
        // ignore: unused_result
        ref.refresh(myAttendanceProvider);
      }
    });
  }

  Future<void> _handleCheckIn() async {
    try {
      setState(() => isProcessing = true);
      await ref.read(hrServiceProvider).checkIn();
      await _refreshAttendanceCache();
      // ignore: unused_result
      ref.refresh(myAttendanceProvider);
      if (mounted) {
        UiFeedback.success(context, 'Checked in successfully');
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _handleCheckOut() async {
    try {
      setState(() => isProcessing = true);
      await ref.read(hrServiceProvider).checkOut();
      await _refreshAttendanceCache();
      // ignore: unused_result
      ref.refresh(myAttendanceProvider);
      if (mounted) {
        UiFeedback.success(context, 'Checked out successfully');
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _refreshAttendanceCache() async {
    final data = await ref.read(hrServiceProvider).getMyAttendance();
    if (data is List) {
      await DatabaseHelper.instance.cacheAttendance(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(myAttendanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: attendanceAsync.when(
        data: (attendance) {
          final isCheckedIn = attendance['checked_in'] as bool? ?? false;
          final checkInTime = attendance['check_in_time'] as String?;
          final checkOutTime = attendance['check_out_time'] as String?;
          final totalHours = attendance['total_hours'] as double? ?? 0.0;
          final entries = attendance['entries'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                // Status Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isCheckedIn ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isCheckedIn ? 'CHECKED IN' : 'CHECKED OUT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (checkInTime != null)
                        Text(
                          'Check-in: ${_formatTime(checkInTime)}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      if (checkOutTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Check-out: ${_formatTime(checkOutTime)}',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Today: ${totalHours.toStringAsFixed(1)} hours',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (!isCheckedIn)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isProcessing ? null : _handleCheckIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: const Icon(Icons.login),
                            label: const Text('Check In'),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isProcessing ? null : _handleCheckOut,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9800),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text('Check Out'),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Today's Time Entries
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Entries',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (entries.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No entries for today'),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: entries.length,
                          itemBuilder: (ctx, index) {
                            final entry = entries[index] as Map<String, dynamic>;
                            return _buildEntryCard(entry);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0061a4)),
        ),
        error: (err, stack) => AsyncErrorView(
          error: err,
          onRetry: () => ref.invalidate(myAttendanceProvider),
        ),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['type'] == 'check_in' ? 'Check In' : 'Check Out',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(entry['timestamp']),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: entry['type'] == 'check_in'
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : const Color(0xFFFF9800).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                entry['type'] == 'check_in' ? 'IN' : 'OUT',
                style: TextStyle(
                  color: entry['type'] == 'check_in' ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return timestamp;
    }
  }
}

Map<String, dynamic> _normalizeAttendance(Map<String, dynamic> raw) {
  final entriesRaw = raw['entries'];
  final entries = (entriesRaw is List)
      ? entriesRaw
          .whereType<Map>()
          .map(
            (item) => <String, dynamic>{
              'type': (item['type'] ?? item['entry_type'] ?? '').toString(),
              'timestamp':
                  (item['timestamp'] ?? item['created_at'] ?? '').toString(),
            },
          )
          .toList()
      : <Map<String, dynamic>>[];

  return {
    'checked_in': raw['checked_in'] == true,
    'check_in_time': raw['check_in_time']?.toString(),
    'check_out_time': raw['check_out_time']?.toString(),
    'total_hours': (raw['total_hours'] as num?)?.toDouble() ?? 0.0,
    'entries': entries,
  };
}

Map<String, dynamic> _normalizeAttendanceFromList(List<dynamic> items) {
  final rows = items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (rows.isEmpty) {
    return _normalizeAttendance(const <String, dynamic>{});
  }

  rows.sort((a, b) {
    final aDate = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });

  final latest = rows.first;
  final status = latest['status']?.toString().toLowerCase();
  final checkIn = latest['check_in_time']?.toString();
  final checkOut = latest['check_out_time']?.toString();

  return {
    'checked_in': status == 'present' && (checkOut == null || checkOut.isEmpty),
    'check_in_time': checkIn,
    'check_out_time': checkOut,
    'total_hours': 0.0,
    'entries': rows
        .expand((row) {
          final list = <Map<String, dynamic>>[];
          final inTime = row['check_in_time']?.toString();
          final outTime = row['check_out_time']?.toString();
          if (inTime != null && inTime.isNotEmpty) {
            list.add({'type': 'check_in', 'timestamp': inTime});
          }
          if (outTime != null && outTime.isNotEmpty) {
            list.add({'type': 'check_out', 'timestamp': outTime});
          }
          return list;
        })
        .toList(),
  };
}
