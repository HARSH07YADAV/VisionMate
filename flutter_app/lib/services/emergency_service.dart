import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Emergency service (Feature 17)
/// SOS button with location sharing
class EmergencyService extends ChangeNotifier {
  bool _isInitialized = false;
  Position? _lastPosition;
  String _emergencyContact = '';

  bool get isInitialized => _isInitialized;
  Position? get lastPosition => _lastPosition;

  /// Initialize and request location permission
  Future<void> initialize() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      
      // Get initial position
      await _updateLocation();
      
      _isInitialized = true;
      debugPrint('Emergency: Initialized');
    } catch (e) {
      debugPrint('Emergency: Init error: $e');
    }
  }

  /// Set emergency contact number
  void setEmergencyContact(String contact) {
    _emergencyContact = contact;
  }

  /// Update current location
  Future<void> _updateLocation() async {
    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Emergency: Location error: $e');
    }
  }

  /// Trigger emergency SOS
  /// Sends SMS with location to emergency contact
  Future<bool> triggerSOS({String? customMessage}) async {
    await _updateLocation();
    
    if (_emergencyContact.isEmpty) {
      debugPrint('Emergency: No contact set');
      return false;
    }
    
    String message = customMessage ?? 'EMERGENCY! I need help.';
    
    if (_lastPosition != null) {
      final lat = _lastPosition!.latitude;
      final lng = _lastPosition!.longitude;
      final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
      message += '\n\nMy location: $mapsUrl';
    }
    
    try {
      final smsUri = Uri(
        scheme: 'sms',
        path: _emergencyContact,
        queryParameters: {'body': message},
      );
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Emergency: SMS error: $e');
      return false;
    }
  }

  /// Call emergency contact
  Future<bool> callEmergency() async {
    if (_emergencyContact.isEmpty) return false;
    
    try {
      final telUri = Uri(
        scheme: 'tel',
        path: _emergencyContact,
      );
      
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Emergency: Call error: $e');
      return false;
    }
  }

  /// Get location description
  String getLocationDescription() {
    if (_lastPosition == null) {
      return 'Location unknown';
    }
    return 'Lat: ${_lastPosition!.latitude.toStringAsFixed(4)}, '
           'Lng: ${_lastPosition!.longitude.toStringAsFixed(4)}';
  }
}
