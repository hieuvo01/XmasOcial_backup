// lib/models/direction_models.dart
import 'package:latlong2/latlong.dart';

// ĐỊNH NGHĨA CLASS 'SearchSuggestion' Ở ĐÂY
class SearchSuggestion {
  final String displayName;
  final LatLng point;

  SearchSuggestion({required this.displayName, required this.point});
}

// Class để quản lý một ô input địa điểm
class LocationInput {
  String address;
  LatLng? coordinates;

  LocationInput({this.address = '', this.coordinates});
}

// Class để chứa thông tin chi tiết về đường đi
class DirectionDetails {
  final List<LatLng> points;
  final String distance;
  final String duration;

  DirectionDetails({
    required this.points,
    required this.distance,
    required this.duration,
  });
}
