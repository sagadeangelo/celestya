import 'api_client.dart';

class SafetyApi {
  static Future<void> reportUser({
    required int targetUserId,
    required String reason,
    String? details,
  }) async {
    await ApiClient.postJson('/reports', {
      'target_user_id': targetUserId,
      'reason': reason,
      'details': details,
    });
  }

  static Future<void> blockUser(int targetUserId) async {
    await ApiClient.postJson('/reports/block', {
      'target_user_id': targetUserId,
    });
  }
}
