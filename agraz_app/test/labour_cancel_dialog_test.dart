import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agraz/app_theme.dart';

/// Reproduces labour Opening Balance dialog pattern: controllers live outside
/// showDialog; Cancel with empty fields must not dispose while TextFields
/// are still attached ('_dependents.isEmpty' assert).
Future<bool?> showTestOpeningBalanceDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Opening Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Opening amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  // Capture before deferred dispose (same as production fix).
  // ignore: unused_local_variable
  final amount = double.tryParse(amountCtrl.text.trim());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    nameCtrl.dispose();
    amountCtrl.dispose();
  });
  return ok;
}

void main() {
  testWidgets('Opening Balance Cancel with empty fields does not crash',
      (tester) async {
    bool? result = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTestOpeningBalanceDialog(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Opening Balance'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    // Leave fields empty — this used to crash on Cancel.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Opening Balance'), findsNothing);
    expect(result, isFalse);
    // Extra frames so deferred dispose runs without assert.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Opening Balance Save with values closes cleanly', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTestOpeningBalanceDialog(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ramesh');
    await tester.enterText(fields.at(1), '500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Opening Balance'), findsNothing);
    expect(result, isTrue);
  });
}
