import 'package:hive/hive.dart';

part 'quiz_attempt.g.dart';

@HiveType(typeId: 0)
class QuizAttempt extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Map<String, dynamic> answers;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  String status; // 'pending', 'synced', 'failed'

  @HiveField(4)
  int retryCount;

  @HiveField(5)
  String? lastError;

  QuizAttempt({
    required this.id,
    required this.answers,
    required this.timestamp,
    this.status = 'pending',
    this.retryCount = 0,
    this.lastError,
  });
}
