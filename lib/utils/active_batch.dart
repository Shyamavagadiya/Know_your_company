import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:hcd_project2/services/app_config_service.dart';
import 'package:hcd_project2/user_provider.dart';

class ActiveBatch {
  /// Tries Provider first; falls back to reading Firestore `config/app`.
  static Future<int?> resolve(BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final fromProvider = userProvider.activeBatchYear;
      if (fromProvider != null) return fromProvider;
    } catch (_) {
      // ignore provider errors
    }
    return AppConfigService().getActiveBatchYear();
  }
}

