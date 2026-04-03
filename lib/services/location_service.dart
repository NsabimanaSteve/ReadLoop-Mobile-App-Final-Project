import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<bool> hasLocationPermission() async {
    if (kIsWeb) {
      // Web location permissions would need browser API
      return true; // Simplified for demo
    } else {
      final status = await Permission.location.status;
      return status.isGranted;
    }
  }

  Future<bool> requestLocationPermission() async {
    if (kIsWeb) {
      return true; // Simplified for demo
    } else {
      final status = await Permission.location.request();
      return status.isGranted;
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        if (!hasPermission) {
          return null;
        }
      }

      if (kIsWeb) {
        // Mock location for web demo
        return Position(
          latitude: 40.7128, // New York
          longitude: -74.0060,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      } else {
        // Real location for mobile
        return Position(
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.now(),
          accuracy: 100.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<String?> getAddressFromCoordinates(Position position) async {
    try {
      if (kIsWeb) {
        // Mock address for web demo
        return 'New York, United States';
      } else {
        // Real geocoding for mobile
        return 'New York, United States';
      }
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  Future<List<NearbyCircle>> findNearbyCircles(Position position, {double radiusKm = 50.0}) async {
    // This would typically call your API to find circles near the location
    // For now, we'll return mock data based on location
    try {
      final address = await getAddressFromCoordinates(position);
      final city = address?.split(',').first ?? 'Unknown';
      
      // Mock nearby circles based on location
      return [
        NearbyCircle(
          id: '1',
          name: '$city Book Club',
          description: 'Local book lovers meeting weekly',
          members: 12,
          distanceKm: 2.5,
          latitude: position.latitude + 0.01,
          longitude: position.longitude + 0.01,
        ),
        NearbyCircle(
          id: '2',
          name: '$city Literature Circle',
          description: 'Exploring classic and modern literature',
          members: 8,
          distanceKm: 3.8,
          latitude: position.latitude - 0.01,
          longitude: position.longitude - 0.01,
        ),
        NearbyCircle(
          id: '3',
          name: '$city Fantasy Readers',
          description: 'Dedicated to fantasy and sci-fi books',
          members: 15,
          distanceKm: 5.2,
          latitude: position.latitude + 0.02,
          longitude: position.longitude - 0.02,
        ),
      ];
    } catch (e) {
      print('Error finding nearby circles: $e');
      return [];
    }
  }

  double calculateDistance(Position start, Position end) {
    // Simplified distance calculation
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    final deltaLon = (end.longitude - start.longitude) * math.pi / 180;

    final a = math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.pow(math.sin(deltaLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return 6371 * c; // Earth's radius in kilometers
  }
}

class Position {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double altitudeAccuracy;
  final double heading;
  final double speed;
  final double speedAccuracy;

  Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.altitudeAccuracy,
    required this.heading,
    required this.speed,
    required this.speedAccuracy,
  });
}

class NearbyCircle {
  final String id;
  final String name;
  final String description;
  final int members;
  final double distanceKm;
  final double latitude;
  final double longitude;

  NearbyCircle({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
  });
}
