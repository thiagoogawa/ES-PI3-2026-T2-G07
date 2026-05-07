import 'package:flutter/widgets.dart';

import '../../domain/entities/authenticated_user.dart';
import 'admin_home_page.dart';
import 'home_page.dart';

Widget buildHomePageForUser(AuthenticatedUser user) {
  if (user.managedStartups.isNotEmpty) {
    return AdminHomePage(user: user);
  }

  return HomePage(user: user);
}
