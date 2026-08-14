import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: tr('Help')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('Help Page Content')),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(tr('Back to Main')),
            ),
          ],
        ),
      ),
    );
  }
}
