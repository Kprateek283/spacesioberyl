import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/mock_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/ghost_mode_aware.dart';
import '../services/crm_service.dart';

class QuotationLineItem {
  final TextEditingController name = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController price = TextEditingController();

  double get lineTotal {
    final q = double.tryParse(qty.text) ?? 0;
    final p = double.tryParse(price.text) ?? 0;
    return q * p;
  }

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

class QuotationBuilderScreen extends ConsumerStatefulWidget {
  final int leadId;
  final String clientName;

  const QuotationBuilderScreen({super.key, required this.leadId, required this.clientName});

  @override
  ConsumerState<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends ConsumerState<QuotationBuilderScreen> {
  final List<QuotationLineItem> _items = [QuotationLineItem()];
  final TextEditingController _taxRateController = TextEditingController(text: '18');
  String _paymentTerm = '100_advance';
  String? _customPdfPath;
  bool _isSubmitting = false;
  bool _isUploadingPdf = false;

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _taxRate => double.tryParse(_taxRateController.text) ?? 0;
  double get _total => _paymentTerm == 'cash' ? _subtotal : _subtotal * (1 + _taxRate / 100);

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _taxRateController.dispose();
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(QuotationLineItem()));

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index).dispose();
    });
  }

  Future<void> _pickCustomPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = result?.files.single.path;
    if (path != null) setState(() => _customPdfPath = path);
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quotation Preview'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client: ${widget.clientName}'),
              const SizedBox(height: 8),
              ..._items.where((i) => i.name.text.isNotEmpty).map(
                    (i) => Text('${i.name.text} × ${i.qty.text} @ ${i.price.text} = ${i.lineTotal.toStringAsFixed(2)}'),
                  ),
              const Divider(),
              Text('Subtotal: ${_subtotal.toStringAsFixed(2)}'),
              if (_paymentTerm != 'cash') Text('Tax (${_taxRateController.text}%): ${(_total - _subtotal).toStringAsFixed(2)}'),
              Text('Total: ${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Payment Term: ${_paymentTerm.replaceAll('_', ' ')}'),
              if (_customPdfPath != null) const Text('Custom PDF will override the generated document.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final lineItems = <Map<String, dynamic>>[];
    for (final item in _items) {
      final qty = double.tryParse(item.qty.text);
      final price = double.tryParse(item.price.text);
      if (item.name.text.trim().isEmpty || qty == null || price == null) {
        UiFeedback.error(context, 'Fill in all line item fields correctly');
        return;
      }
      lineItems.add({
        'item_name': item.name.text.trim(),
        'quantity': qty,
        'unit_price': price,
      });
    }
    if (lineItems.isEmpty) {
      UiFeedback.error(context, 'Add at least one line item');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? customPdfUrl;
      if (_customPdfPath != null) {
        setState(() => _isUploadingPdf = true);
        // TODO: replace with a real upload once a generic backend upload
        // endpoint exists (see issue/01-backend-issues.md).
        customPdfUrl = MockUploadService.toMockUrl(_customPdfPath!, bucket: 'quotations');
        if (mounted) setState(() => _isUploadingPdf = false);
      }

      await ref.read(crmServiceProvider).createQuotation(
            leadId: widget.leadId,
            paymentTermType: _paymentTerm,
            taxRate: _paymentTerm == 'cash' ? 0.0 : _taxRate,
            lineItems: lineItems,
            customPdfUrl: customPdfUrl,
          );

      if (mounted) {
        UiFeedback.success(context, 'Quotation created');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) UiFeedback.parsedError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Quotation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Client: ${widget.clientName}', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            const SizedBox(height: 24),
            Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._items.asMap().entries.map((entry) => _LineItemRow(
                  item: entry.value,
                  showRemove: _items.length > 1,
                  isCash: _paymentTerm == 'cash',
                  onRemove: () => _removeItem(entry.key),
                  onChanged: () => setState(() {}),
                )),
            OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(_subtotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _paymentTerm == 'cash'
                      ? GhostModeAware(child: _taxRateField())
                      : _taxRateField(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Terms', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _paymentTerm,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: '100_advance', child: Text('100% Advance')),
                          DropdownMenuItem(value: '50_advance', child: Text('50% Advance')),
                          DropdownMenuItem(value: 'cash', child: Text('Cash (Ghost Mode)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _paymentTerm = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onPrimaryContainer)),
                  Text(
                    _total.toStringAsFixed(2),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text('Manual Override (Optional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Upload a custom PDF quotation to override the generated document.',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickCustomPdf,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outlineVariant, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      _customPdfPath != null ? Icons.picture_as_pdf : Icons.upload_file,
                      color: _customPdfPath != null ? AppColors.primary : AppColors.onSurfaceVariant,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _customPdfPath != null ? _customPdfPath!.split(RegExp(r'[\\/]')).last : 'Click to browse for a PDF',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text('Maximum file size 10MB', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPreview,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isUploadingPdf ? 'Uploading PDF...' : 'Generate & Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _taxRateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tax Rate (%)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _taxRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: '%'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final QuotationLineItem item;
  final bool showRemove;
  final bool isCash;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _LineItemRow({
    required this.item,
    required this.showRemove,
    required this.isCash,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final priceField = TextField(
      controller: item.price,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Unit Price', border: OutlineInputBorder()),
      onChanged: (_) => onChanged(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.name,
                    decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                  ),
                ),
                if (showRemove)
                  IconButton(icon: Icon(Icons.delete, color: AppColors.error), onPressed: onRemove),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: isCash ? GhostModeAware(child: priceField) : priceField),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
