import '../entities/ai_assistant_response.dart';
import '../repositories/ai_repository.dart';

class WatchAiQuota {
  const WatchAiQuota(this.repository);

  final AiRepository repository;

  /// Usage of the Vietnam calendar day the backend counts quota by.
  Stream<AiAssistantQuota> call({
    required String userId,
    required String membershipId,
    DateTime? now,
  }) {
    return repository.watchQuota(
      userId: userId,
      membershipId: membershipId,
      day: aiQuotaDay(now ?? DateTime.now()),
    );
  }
}

/// `YYYY-MM-DD` in Asia/Ho_Chi_Minh (UTC+7, no daylight saving).
String aiQuotaDay(DateTime now) {
  final vietnam = now.toUtc().add(const Duration(hours: 7));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${vietnam.year}-${two(vietnam.month)}-${two(vietnam.day)}';
}
