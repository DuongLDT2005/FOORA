import 'package:meta/meta.dart';

@immutable
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
}
