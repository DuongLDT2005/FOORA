import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_location.dart';

abstract class LocationDataSource {
  Future<UserLocation> getCurrentLocation();
}

class LocationDataSourceImpl implements LocationDataSource {
  const LocationDataSourceImpl();

  @override
  Future<UserLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationErrorCode.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationErrorCode.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationErrorCode.deniedForever);
    }

    try {
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
    } on TimeoutException {
      throw const LocationException(LocationErrorCode.timeout);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationErrorCode.serviceDisabled);
    }
  }

  UserLocation _toUserLocation(Position position) => UserLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
  );
}
