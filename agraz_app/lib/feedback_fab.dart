import 'package:flutter/material.dart';

import 'feedback_page.dart';
import 'l10n/app_l10n.dart';

/// Small reusable feedback/chat icon for AppBars and AppHeader trailing.
class FeedbackIconButton extends StatelessWidget {
  final String menu;
  final Color color;
  final String? tooltip;

  const FeedbackIconButton({
    super.key,
    this.menu = '',
    this.color = Colors.white,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? tr('Feedback'),
      icon: Icon(Icons.feedback_outlined, color: color),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeedbackPage(initialMenu: menu),
          ),
        );
      },
    );
  }
}

/// Appends a feedback icon to [actions] (or returns just the icon).
List<Widget> withFeedbackAction(
  BuildContext context, {
  String menu = '',
  List<Widget>? actions,
  Color color = Colors.white,
}) {
  return [
    ...?actions,
    FeedbackIconButton(menu: menu, color: color),
  ];
}
