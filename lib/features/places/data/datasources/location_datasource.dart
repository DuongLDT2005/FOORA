import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/user_location.dart';

abstract class LocationDataSource {
  Future<UserLocation> getCurrentLocation();

  Future<void> openLocationSettings({required bool appSettings});
}

class LocationDataSourceImpl implements LocationDataSource {
  const LocationDataSourceImpl({this.fixedLocation});

  /// Development override that skips GPS (see `DEV_LOCATION`).
  final UserLocation? fixedLocation;

  @override
  Future<UserLocation> getCurrentLocation() async {
    final fixed = fixedLocation;
    if (fixed != null) return fixed;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw LocationException(LocationErrorCode.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw LocationException(LocationErrorCode.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationException(LocationErrorCode.deniedForever);
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          DateTime.now().difference(lastKnown.timestamp) <
              const Duration(minutes: 2)) {
        return _toUserLocation(lastKnown);
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _toUserLocation(current);
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw LocationException(LocationErrorCode.timeout);
    } on LocationServiceDisabledException {
      throw LocationException(LocationErrorCode.serviceDisabled);
    } catch (error, stackTrace) {
      // Plugin errors (a permission request already in progress, platform
      // failures) become a retryable state instead of an endless spinner.
      AppLogger.e('Could not read the device location.', error, stackTrace);
      throw LocationException(LocationErrorCode.timeout);
    }
  }

  @override
  Future<void> openLocationSettings({required bool appSettings}) async {
    if (appSettings) {
      await Geolocator.openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
  }

  UserLocation _toUserLocation(Position position) => UserLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
  );
}
