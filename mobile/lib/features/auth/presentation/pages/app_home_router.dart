/// Thiago Ryuji Ogawa - RA:24024450
///
/// Roteador interno da area autenticada.
/// Decide qual home deve ser exibida com base no papel do usuario
/// e no conjunto de startups administradas.

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
