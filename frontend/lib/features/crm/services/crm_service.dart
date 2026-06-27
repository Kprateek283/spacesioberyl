import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/api_parse.dart';

final crmServiceProvider = Provider<CrmService>((ref) {
  return CrmService(ref.watch(apiClientProvider));
});

class CrmService {
  final ApiClient _api;

  CrmService(this._api);

  Future<void> createLead({
    required String clientName,
    required String clientPhone,
    String? clientEmail,
    String? source,
  }) async {
    await _api.createLead(
      clientName: clientName,
      clientPhone: clientPhone,
      clientEmail: clientEmail,
      source: source,
    );
    await _refreshLeadsCache();
  }

  Future<List<Map<String, dynamic>>> getLeads({String? status}) async {
    final response = await _api.getLeads(status: status);
    return ApiParse.asMapList(response.data);
  }

  Future<Map<String, dynamic>> getLead(int leadId) async {
    final response = await _api.getLead(leadId);
    return ApiParse.asMap(response.data);
  }

  Future<void> updateLeadStatus(int leadId, String status,
      {String? lostReason}) async {
    await _api.updateLeadStatus(leadId, status, lostReason: lostReason);
    await _refreshLeadsCache();
  }

  Future<void> assignLead(int leadId, int assignedTo) async {
    await _api.assignLead(leadId, assignedTo);
    await _refreshLeadsCache();
  }

  Future<List<Map<String, dynamic>>> getFollowupQueue() async {
    final response = await _api.getMyFollowupQueue();
    return ApiParse.asMapList(response.data);
  }

  Future<void> completeFollowup(int followupId, String outcomeNotes) async {
    await _api.completeFollowup(followupId, outcomeNotes);
  }

  Future<void> createFollowup({
    required int leadId,
    required String scheduledFor,
    required String notes,
  }) async {
    await _api.createFollowup(
      leadId: leadId,
      scheduledFor: scheduledFor,
      notes: notes,
    );
  }

  Future<List<Map<String, dynamic>>> getComplaints() async {
    final response = await _api.getComplaints();
    return ApiParse.asMapList(response.data);
  }

  Future<void> createComplaint({
    required String title,
    required String description,
    required String priority,
    int? leadId,
    int? orderId,
    String? clientName,
    String? clientPhone,
  }) async {
    await _api.createComplaint(
      title: title,
      description: description,
      priority: priority,
      leadId: leadId,
      orderId: orderId,
      clientName: clientName,
      clientPhone: clientPhone,
    );
  }

  Future<void> resolveComplaint(int complaintId) async {
    await _api.updateComplaintStatus(complaintId, 'resolved');
  }

  Future<List<Map<String, dynamic>>> getQuotations(int leadId) async {
    final response = await _api.getLeadQuotations(leadId);
    return ApiParse.asMapList(response.data);
  }

  Future<void> approveQuotation(int quotationId) async {
    await _api.updateQuotationStatus(quotationId, 'client_approved');
  }

  Future<void> createQuotation({
    required int leadId,
    required String paymentTermType,
    required double taxRate,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    await _api.createQuotation(
      leadId: leadId,
      paymentTermType: paymentTermType,
      taxRate: taxRate,
      lineItems: lineItems,
    );
  }

  Future<void> _refreshLeadsCache() async {
    final leads = await getLeads();
    await DatabaseHelper.instance.cacheLeads(leads);
  }
}
