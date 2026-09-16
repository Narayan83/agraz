import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'income_expense_data.dart';
import 'l10n/app_l10n.dart';

/// Opens a bottom sheet grid to edit farm-income product lines.
Future<List<FarmIncomeProductLine>?> showFarmIncomeProductLinesSheet({
  required BuildContext context,
  required String crop,
  required List<FarmIncomeProductLine> initial,
}) {
  return showModalBottomSheet<List<FarmIncomeProductLine>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FarmIncomeProductLinesSheet(
      crop: crop,
      initial: initial,
    ),
  );
}

class _LineCtrls {
  String product;
  final qty = TextEditingController();
  final price = TextEditingController();
  final total = TextEditingController();
  String unit;
  bool lastEditedTotal = false;

  _LineCtrls({
    this.product = '',
    this.unit = 'kg',
    String qtyText = '',
    String priceText = '',
    String totalText = '',
  }) {
    qty.text = qtyText;
    price.text = priceText;
    total.text = totalText;
  }

  void dispose() {
    qty.dispose();
    price.dispose();
    total.dispose();
  }

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(price.text.trim()) ?? 0;
  double get lineTotal => double.tryParse(total.text.trim()) ?? 0;
}

class _FarmIncomeProductLinesSheet extends StatefulWidget {
  final String crop;
  final List<FarmIncomeProductLine> initial;

  const _FarmIncomeProductLinesSheet({
    required this.crop,
    required this.initial,
  });

  @override
  State<_FarmIncomeProductLinesSheet> createState() =>
      _FarmIncomeProductLinesSheetState();
}

class _FarmIncomeProductLinesSheetState
    extends State<_FarmIncomeProductLinesSheet> {
  late final List<_LineCtrls> _lines;
  late final List<String> _catalog;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _catalog = IncomeExpenseData.productsForCrop(widget.crop);
    if (widget.initial.isEmpty) {
      _lines = [_LineCtrls()];
    } else {
      final e = widget.initial.first;
      _lines = [
        _LineCtrls(
          product: e.product,
          unit: e.unit.isEmpty ? 'kg' : e.unit,
          qtyText: e.quantity == 0 ? '' : _trimNum(e.quantity),
          priceText: e.unitPrice == 0 ? '' : _trimNum(e.unitPrice),
          totalText: e.total == 0 ? '' : _trimNum(e.total),
        ),
      ];
    }
  }

  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  void _setCtrl(TextEditingController c, double v) {
    final t = v <= 0 ? '' : _trimNum(v);
    if (c.text == t) return;
    c.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  void _recalc(_LineCtrls line, {required String keepField}) {
    if (_syncing) return;
    _syncing = true;
    final r = FarmIncomeLineCalc.sync(
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      total: line.lineTotal,
      fromTotal: keepField == 'total' ||
          (keepField == 'qty' && line.lastEditedTotal),
    );
    if (keepField != 'price') {
      _setCtrl(line.price, r.unitPrice);
    }
    if (keepField != 'total') {
      _setCtrl(line.total, r.total);
    }
    _syncing = false;
    setState(() {});
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _grandTotal =>
      _lines.fold<double>(0, (s, e) => s + e.lineTotal);

  void _selectProduct(_LineCtrls line, String product) {
    setState(() {
      line.product = line.product == product ? '' : product;
    });
  }

  void _removeLine(int i) {
    if (_lines.length <= 1) {
      setState(() {
        _lines[0].product = '';
        _lines[0].qty.clear();
        _lines[0].price.clear();
        _lines[0].total.clear();
        _lines[0].unit = 'kg';
        _lines[0].lastEditedTotal = false;
      });
      return;
    }
    setState(() {
      _lines.removeAt(i).dispose();
    });
  }

  void _save() {
    final out = <FarmIncomeProductLine>[];
    for (final l in _lines) {
      if (l.product.trim().isEmpty &&
          l.quantity <= 0 &&
          l.unitPrice <= 0 &&
          l.lineTotal <= 0) {
        continue;
      }
      out.add(
        FarmIncomeProductLine(
          product: l.product.trim(),
          quantity: l.quantity,
          unit: l.unit,
          unitPrice: l.unitPrice,
          lineTotal: l.lineTotal,
        ),
      );
    }
    Navigator.pop(context, out);
  }

  InputDecoration _fieldDeco(String label) {
    return InputDecoration(
      labelText: tr(label),
      filled: true,
      fillColor: AppColors.field,
      isDense: true,
    );
  }

  List<TextInputFormatter> get _numFmt => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ];

  Widget _productGrid(_LineCtrls line) {
    if (_catalog.isEmpty) {
      return TextFormField(
        initialValue: line.product,
        decoration: _fieldDeco('Product'),
        onChanged: (v) => line.product = v,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _catalog)
          ChoiceChip(
            selected: line.product == p,
            showCheckmark: false,
            label: Text(
              tr(p),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: line.product == p ? Colors.white : AppColors.textPrimary,
              ),
            ),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: line.product == p ? AppColors.primary : AppColors.border,
            ),
            onSelected: (_) => _selectProduct(line, p),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = NumberFormat('#,##0.##');
    final line = _lines.first;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Product details'), style: AppText.title),
                    Text(
                      tr(widget.crop),
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Remove'),
                onPressed: () => _removeLine(0),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.expense.withValues(alpha: 0.85),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('Enter quantity, then price or total'),
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr('Product'), style: AppText.label),
                    const SizedBox(height: 8),
                    _productGrid(line),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: line.qty,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _numFmt,
                            decoration: _fieldDeco('Qty'),
                            onChanged: (_) {
                              _recalc(line, keepField: 'qty');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                IncomeExpenseData.productUnits.contains(
                                        line.unit)
                                    ? line.unit
                                    : 'kg',
                            decoration: _fieldDeco('Unit'),
                            items: IncomeExpenseData.productUnits
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => line.unit = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: line.price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _numFmt,
                            decoration: _fieldDeco('Price'),
                            onChanged: (_) {
                              line.lastEditedTotal = false;
                              _recalc(line, keepField: 'price');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: line.total,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _numFmt,
                            decoration: _fieldDeco('Total'),
                            onChanged: (_) {
                              line.lastEditedTotal = true;
                              _recalc(line, keepField: 'total');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(tr('Grand total'), style: AppText.label),
                ),
                Text(
                  '₹${fmt.format(_grandTotal)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(tr('Save details')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact read-only list of product lines for detail screens.
Widget buildFarmIncomeProductLinesReadonly(List<dynamic>? rawLines) {
  final lines = <FarmIncomeProductLine>[];
  for (final e in rawLines ?? const []) {
    if (e is Map) {
      lines.add(FarmIncomeProductLine.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  if (lines.isEmpty) return const SizedBox.shrink();
  final fmt = NumberFormat('#,##0.##');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      Text(tr('Product details'), style: AppText.label),
      const SizedBox(height: 8),
      ...lines.map((l) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${tr(l.product.isEmpty ? '—' : l.product)}'
                    ' · ${fmt.format(l.quantity)} ${l.unit}'
                    ' × ₹${fmt.format(l.unitPrice)}',
                    style: AppText.small,
                  ),
                ),
                Text(
                  '₹${fmt.format(l.total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ],
  );
}
