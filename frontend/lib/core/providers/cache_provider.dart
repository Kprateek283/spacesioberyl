import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../local_db/database_helper.dart';
import '../network/api_client.dart';
import '../utils/api_parse.dart';
import '../network/sync_service.dart';

// ----- Cached data providers (SQLite read-through) -----
final cachedVendorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return DatabaseHelper.instance.getCachedVendors();
});

final cachedInstallersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return DatabaseHelper.instance.getCachedInstallers();
});

final cachedLeadsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return DatabaseHelper.instance.getCachedLeads();
});

/// Pull latest CRM leads from API and refresh SQLite cache.
Future<void> refreshLeadsCache(WidgetRef ref) async {
  try {
    final response = await ref.read(apiClientProvider).getLeads();
    final leads = ApiParse.asMapList(response.data);
    await DatabaseHelper.instance.cacheLeads(leads);
    ref.invalidate(cachedLeadsProvider);
  } catch (e) {
    rethrow;
  }
}

Future<void> _cacheListResponse(
  dynamic responseData,
  Future<void> Function(List<Map<String, dynamic>>) cacheFn,
) async {
  await cacheFn(ApiParse.asMapList(responseData));
}

// ----- Boot sync (online only) -----
final cacheBootSyncProvider = FutureProvider<void>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final dbHelper = DatabaseHelper.instance;

  final connectivity = await Connectivity().checkConnectivity();
  final isConnected = connectivity.contains(ConnectivityResult.mobile) ||
      connectivity.contains(ConnectivityResult.wifi);

  if (!isConnected) return;

  Future<void> safeSync(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Keep cached data when individual sync calls fail.
    }
  }

  await safeSync(() async {
    final res = await apiClient.get('/logistics/vendors');
    if (res.statusCode == 200) {
      await _cacheListResponse(res.data, dbHelper.cacheVendors);
      ref.invalidate(cachedVendorsProvider);
    }
  });

  await safeSync(() async {
    final res = await apiClient.get('/execution/installers');
    if (res.statusCode == 200) {
      await _cacheListResponse(res.data, dbHelper.cacheInstallers);
      ref.invalidate(cachedInstallersProvider);
    }
  });

  await safeSync(() async {
    final res = await apiClient.get('/crm/leads');
    if (res.statusCode == 200) {
      await _cacheListResponse(res.data, dbHelper.cacheLeads);
      ref.invalidate(cachedLeadsProvider);
    }
  });

  await safeSync(() async {
    final res = await apiClient.get('/hr/attendance/me');
    if (res.statusCode == 200) {
      await dbHelper.cacheAttendance(ApiParse.asMapList(res.data));
    }
  });

  await safeSync(() async {
    final res = await apiClient.get('/hr/leaves/me');
    if (res.statusCode == 200) {
      await dbHelper.cacheLeaves(ApiParse.asMapList(res.data));
    }
  });

  await safeSync(() async {
    final res = await apiClient.get('/hr/expenses');
    if (res.statusCode == 200) {
      await dbHelper.cacheExpenses(ApiParse.asMapList(res.data));
    }
  });

  ref.invalidate(pendingSyncCountProvider);
});
