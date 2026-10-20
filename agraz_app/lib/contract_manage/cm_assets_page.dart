import 'package:flutter/material.dart';

import '../l10n/app_l10n.dart';
import 'cm_entity_page.dart';

class CmAssetsPage extends StatelessWidget {
  const CmAssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CmEntityPage(
      title: 'Assets',
      path: '/contract/assets',
      fields: const ['name', 'asset_type', 'vendor_name', 'serial_no', 'status', 'notes'],
      subtitleOf: (r) =>
          '${r['asset_type'] ?? ''} · ₹${r['purchase_amt'] ?? 0} · ${r['vendor_name'] ?? ''} · ${r['status'] ?? ''}',
      extraFields: (ctx, ctrls, setLocal, extras) {
        ctrls.putIfAbsent(
          'purchase_amt',
          () => TextEditingController(text: extras['edit_purchase_amt']?.toString() ?? ''),
        );
        ctrls.putIfAbsent(
          'purchase_date',
          () => TextEditingController(
            text: (extras['edit_purchase_date']?.toString() ?? '').split('T').first,
          ),
        );
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: ctrls['purchase_amt'],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Purchase amount'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: ctrls['purchase_date'],
              decoration: InputDecoration(
                labelText: tr('Purchase date'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ];
      },
      toBody: (c, extras) => {
        'name': c['name']!.text.trim(),
        'asset_type': c['asset_type']!.text.trim(),
        'vendor_name': c['vendor_name']!.text.trim(),
        'serial_no': c['serial_no']!.text.trim(),
        'status': c['status']!.text.trim().isEmpty ? 'active' : c['status']!.text.trim(),
        'notes': c['notes']!.text.trim(),
        'purchase_amt': double.tryParse((c['purchase_amt']?.text ?? '').replaceAll(',', '')) ?? 0,
        if ((c['purchase_date']?.text ?? '').trim().isNotEmpty)
          'purchase_date': c['purchase_date']!.text.trim(),
      },
    );
  }
}
