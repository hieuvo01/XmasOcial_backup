// lib/models.dart
import 'package:latlong2/latlong.dart';

// Lớp để chứa thông tin gợi ý tìm kiếm
class SearchSuggestion {
  final String displayName;
  final LatLng point;
  SearchSuggestion({required this.displayName, required this.point});
}

// Lớp để chứa thông tin của một điểm (đi hoặc đến)
class LocationInput {
  String address;
  LatLng? coordinates;
  LocationInput({this.address = '', this.coordinates});
}

// Enum để quản lý các loại bản đồ
enum MapLayerType { normal, satellite }
