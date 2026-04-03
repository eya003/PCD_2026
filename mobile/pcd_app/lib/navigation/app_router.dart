import 'package:flutter/widgets.dart';

class AppRouter {
  const AppRouter._();

  static int tabIndexFromRoute(String route) {
    switch (route) {
      case '/patients':
        return 1;
      case '/ai':
        return 2;
      case '/profile':
        return 3;
      case '/dashboard':
      default:
        return 0;
    }
  }

  static void closeDrawerIfOpen(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
