import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getBestAvailablePosition() async {
    if (!await _canAccessLocation()) return null;
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) return lastKnown;
    return _requestCurrentPosition();
  }

  Future<Position?> getCurrentPosition() async {
    try {
      if (!await _canAccessLocation()) return null;
      try {
        return await _requestCurrentPosition();
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      return null;
    }
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
