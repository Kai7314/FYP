import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getBestAvailablePosition() async {
    if (!await _canAccessLocation()) return null;
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;
    return _requestCurrentPosition();
  }

  Future<Position?> getCurrentPosition() async {
    if (!await _canAccessLocation()) return null;
    return _requestCurrentPosition();
  }

  Future<bool> _canAccessLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<Position> _requestCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }
}
