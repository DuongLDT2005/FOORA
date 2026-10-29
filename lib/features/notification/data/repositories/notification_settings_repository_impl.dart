import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/repositories/notification_settings_repository.dart';
import '../datasources/notification_settings_local_datasource.dart';
import '../datasources/notification_settings_remote_datasource.dart';
import '../models/notification_settings_model.dart';

class NotificationSettingsRepositoryImpl
    implements NotificationSettingsRepository {
  final NotificationSettingsRemoteDataSource remoteDataSource;
  final NotificationSettingsLocalDataSource localDataSource;

  const NotificationSettingsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Stream<NotificationSettings?> watch(String userId) {
    return remoteDataSource.watch(userId).map((raw) {
      if (raw == null) return null;
      final settings = NotificationSettingsModel.fromMap(raw);
      localDataSource.writeCache(userId, settings);
      return settings;
    });
  }

  @override
  Future<void> save(String userId, NotificationSettings settings) async {
    try {
      await remoteDataSource.save(
        userId,
        NotificationSettingsModel.toMap(settings),
      );
      await localDataSource.writeCache(userId, settings);
    } on AppException catch (e) {
      throw Failure.fromException(e);
    }
  }

  @override
  NotificationSettings? cached(String userId) =>
      localDataSource.readCache(userId);

  @override
  NotificationSettings legacyLocalSettings() => localDataSource.readLegacy();

  @override
  bool get soundEnabled => localDataSource.soundEnabled;

  @override
  Future<void> setSoundEnabled(bool value) =>
      localDataSource.setSoundEnabled(value);
}
