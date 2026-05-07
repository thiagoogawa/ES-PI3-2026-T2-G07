import 'package:flutter/widgets.dart';

import '../../domain/entities/authenticated_user.dart';
import 'admin_startup_selection_page.dart';
import 'home_page.dart';

Widget buildHomePageForUser(AuthenticatedUser user) {
  if (user.isStartupAdmin) {
    return AdminStartupSelectionPage(user: user);
  }

  return HomePage(user: user);
}
