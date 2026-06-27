import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/utils/api_parse.dart';

final logisticsServiceProvider = Provider<LogisticsService>((ref) {
  return LogisticsService(
    ref.watch(apiClientProvider),
    ref.watch(syncServiceProvider),
  );
});

class LogisticsService {
  final ApiClient _api;
  final SyncService _sync;

  LogisticsService(this._api, this._sync);

  Future<void> createVendor({
    required String companyName,
    required String contactPerson,
    required String phone,
    String? email,
    required String defaultPaymentMode,
  }) async {
    await _api.post('/logistics/vendors', data: {
      'company_name': companyName,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'default_payment_mode': defaultPaymentMode,
    });
    await _refreshVendorsCache();
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _api.getOrders();
    return ApiParse.asMapList(response.data);
  }

  Future<void> assignOrderManager(int orderId, int operationsManagerId) async {
    await _api.assignOrderManager(orderId, operationsManagerId);
  }

  Future<List<Map<String, dynamic>>> getMyDispatches() async {
    final response = await _api.getMyDispatches();
    return ApiParse.asMapList(response.data);
  }

  Future<void> logDispatchEvent({
    required int dispatchId,
    required String type,
    String? notes,
    String? challanUrl,
  }) async {
    final payload = {
      'type': type,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (challanUrl != null && challanUrl.isNotEmpty) 'challan_url': challanUrl,
    };

    await DatabaseHelper.instance.queueMutation(
      endpoint: '/logistics/dispatches/$dispatchId/log',
      method: 'PATCH',
      payload: jsonEncode(payload),
    );
    await _sync.triggerManualSync();
  }

  Future<void> createDispatch({
    required int orderId,
    required int operationsStaffId,
    required String loadingResponsibility,
    String? transportDriverName,
    String? transportVehicleNo,
  }) async {
    await _api.createDispatch(
      orderId: orderId,
      operationsStaffId: operationsStaffId,
      loadingResponsibility: loadingResponsibility,
      transportDriverName: transportDriverName,
      transportVehicleNo: transportVehicleNo,
    );
  }

  Future<void> createPurchaseOrder({
    required int orderId,
    required int vendorId,
    required double totalAmount,
    required String expectedDeliveryDate,
  }) async {
    await _api.createPurchaseOrder(
      orderId: orderId,
      vendorId: vendorId,
      totalAmount: totalAmount,
      expectedDeliveryDate: expectedDeliveryDate,
    );
  }

  Future<void> _refreshVendorsCache() async {
    final response = await _api.getVendors();
    await DatabaseHelper.instance.cacheVendors(
      ApiParse.asMapList(response.data),
    );
  }
}
