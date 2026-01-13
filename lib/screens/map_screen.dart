// lib/screens/map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ai_service.dart';
import '../services/search_service.dart';
import '../utils/debouncer.dart';
import '../models/direction_models.dart';

enum MapLayerType { normal, satellite }
enum MapViewState { browsing, directions }

class MapScreen extends StatefulWidget {
  final LatLng? initialTargetLocation; // Tọa độ mục tiêu từ tin nhắn
  final String? targetAddress;         // Tên địa chỉ hiển thị
  final String? senderAvatar;
  final String? receiverAvatar;

  const MapScreen({super.key, this.initialTargetLocation, this.targetAddress, this.senderAvatar, this.receiverAvatar});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final String _graphhopperApiKey = '92735f62-7865-45b1-afab-887d7c429f60';
  static const String _esriUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  // DARK MODE COLORS
  final Color _darkBg = const Color(0xFF121212);
  final Color _darkSurface = const Color(0xFF1E1E1E);
  final Color _darkAccent = Colors.blueAccent;
  final Color _darkText = Colors.white;
  final Color _darkTextSecondary = Colors.white70;


  MapLayerType _currentMapLayer = MapLayerType.normal;
  Future<List<String>>? _historyFuture;
  bool _isTrafficLayerVisible = false;
  final List<Polyline> _trafficPolylines = [];
  final MapController _mapController = MapController();
  Future<Position?>? _locationFuture;
  String _selectedVehicle = 'car';
  Position? _currentPosition;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _compassHeading;
  final List<Marker> _markers = [];
  final _debouncer = Debouncer(milliseconds: 700);
  List<SearchSuggestion> _suggestions = [];
  bool _isFetchingSuggestions = false;
  MapViewState _currentViewState = MapViewState.browsing;
  LocationInput _startLocation = LocationInput();
  LocationInput _endLocation = LocationInput();
  DirectionDetails? _directionDetails;
  bool _isEditingStart = false;
  final TextEditingController _searchController = TextEditingController();
  final AiService _aiService = AiService();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isAiListening = false;
  String _aiResponseText = "";
  bool _isAiSpeaking = false;
  final FocusNode _searchFocusNode = FocusNode();
  final SearchService _searchService = SearchService();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  // HÀM QUAN TRỌNG: Xử lý khi mở Map từ tin nhắn vị trí
  void _handleReceivedLocation(LatLng point, String address) {
    setState(() {
      _updateSearchedLocationMarker(point);
      _animatedMove(point, 15.0);

      // Hiển thị bảng thông tin
      _showLocationDetailsSheet(SearchSuggestion(
        displayName: address,
        point: point,
      ));
    });
  }

  // SỬA LỖI DẪN ĐƯỜNG: Khi nhấn "Đường đi" từ tin nhắn, dùng thẳng tọa độ
  void _showLocationDetailsSheet(SearchSuggestion suggestion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              suggestion.displayName,
              style: TextStyle(
                color: _darkText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions),
                label: const Text('Đường đi'),
                onPressed: () {
                  Navigator.pop(context);
                  // Gọi hàm dẫn đường trực tiếp bằng tọa độ để tránh lỗi Geocoding
                  _startDirectionsFromCoords(suggestion.point, suggestion.displayName);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


// Hàm bổ trợ để kích hoạt dẫn đường từ tọa độ (LatLng)
  void _startDirectionsFromCoords(LatLng target, String address) {
    if (_currentPosition == null) return;

    _searchFocusNode.unfocus();
    setState(() {
      _currentViewState = MapViewState.directions;
      _startLocation = LocationInput(
        address: 'Vị trí của bạn',
        coordinates: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      );
      _endLocation = LocationInput(
        address: address,
        coordinates: target,
      );
      _markers.clear();
      _searchController.clear();
      _suggestions = [];
    });
    // Gọi engine GraphHopper để tính toán quãng đường và thời gian
    _getDirections();
  }

// 3. HÀM PHỤ TRỢ VẼ AVATAR TRÒN CÓ VIỀN
  Widget _buildAvatarMarker(String url, Color borderColor, LatLng point) {
    return GestureDetector(
      onTap: () {
        // Khi nhấn vào avatar, hiện lại bảng thông tin để người dùng bấm "Chỉ đường"
        _showLocationDetailsSheet(SearchSuggestion(
          displayName: widget.targetAddress ?? "Vị trí đối phương",
          point: point,
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))
          ],
        ),
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.grey, child: const Icon(Icons.person, color: Colors.white)),
          ),
        ),
      ),
    );
  }




  String _formatDuration(int totalMinutes) {
    if (totalMinutes < 60) return '$totalMinutes phút';
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours giờ' : '$hours giờ $minutes phút';
  }

  void _generateFakeTraffic() {
    _trafficPolylines.clear();
    if (!_isTrafficLayerVisible) {
      setState(() {});
      return;
    }
    final fakeRoutes = [
      [LatLng(10.7716, 106.7042), LatLng(10.7750, 106.7028)],
      [LatLng(10.7750, 106.7028), LatLng(10.7770, 106.6983)],
      [LatLng(10.7778, 106.6953), LatLng(10.7845, 106.6917)],
      [LatLng(10.7795, 106.6923), LatLng(10.7774, 106.6858)],
    ];
    final trafficColors = [Colors.green, Colors.orange, Colors.red];
    final random = Random();
    for (var route in fakeRoutes) {
      _trafficPolylines.add(Polyline(points: route, color: trafficColors[random.nextInt(trafficColors.length)], strokeWidth: 4.0));
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Khởi tạo vị trí và xử lý nếu có tọa độ truyền vào từ tin nhắn
    _locationFuture = _getCurrentLocation().then((pos) {
      if (widget.initialTargetLocation != null && pos != null) {
        // Sử dụng PostFrameCallback để đảm bảo MapController đã sẵn sàng
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleReceivedLocation(widget.initialTargetLocation!, widget.targetAddress ?? "Vị trí được chia sẻ");
        });
      }
      return pos;
    });
    _listenToCompass();
    _initSpeech();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() => _historyFuture = _searchService.getSearchHistory());
      }
    });
  }


  @override
  void dispose() {
    _mapController.dispose();
    _compassSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _speechToText.stop();
    super.dispose();
  }

  void _startAiListening() {
    if (_isAiSpeaking) {
      _flutterTts.stop();
      setState(() { _isAiSpeaking = false; _aiResponseText = ""; });
    }
    setState(() => _isAiListening = true);
    _startListening();
  }

  Future<void> _speak(String text) async {
    setState(() => _isAiSpeaking = true);
    await _flutterTts.setLanguage("vi-VN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() { _isAiSpeaking = false; _aiResponseText = ""; _lastWords = ""; });
    });
  }

  void _initSpeech() async => await _speechToText.initialize();
  void _startListening() async { await _stopListening(); await _speechToText.listen(onResult: _onSpeechResult, localeId: 'vi_VN'); setState(() => _isListening = true); }
  Future<void> _stopListening() async { if (!_isListening) return; await _speechToText.stop(); setState(() => _isListening = false); }

  Future<void> _searchNearby(String query) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể xác định vị trí hiện tại để tìm kiếm.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang tìm "$query" xung quanh bạn...')));
    const double radiusKm = 5.0;
    double lat = _currentPosition!.latitude;
    double lon = _currentPosition!.longitude;
    double latDelta = radiusKm / 111.0;
    double lonDelta = radiusKm / (111.0 * cos(lat * pi / 180.0));
    double minLat = lat - latDelta; double maxLat = lat + latDelta;
    double minLon = lon - lonDelta; double maxLon = lon + lonDelta;
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=15&viewbox=$minLon,$minLat,$maxLon,$maxLat&bounded=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'com.example.vo_minh_hieu'});
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        if (results.isNotEmpty) {
          List<LatLng> resultPoints = [];
          setState(() {
            _markers.removeWhere((m) => m.key != const Key('user_marker'));
            for (var result in results) {
              final rLat = double.parse(result['lat']); final rLon = double.parse(result['lon']);
              final point = LatLng(rLat, rLon); resultPoints.add(point);
              _markers.add(Marker(width: 80.0, height: 80.0, point: point, child: GestureDetector(onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['display_name'] ?? 'Không có tên'))), child: const Icon(Icons.location_on, color: Colors.red, size: 35))));
            }
          });
          if (resultPoints.isNotEmpty) {
            resultPoints.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
            final bounds = LatLngBounds.fromPoints(resultPoints);
            _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)));
          }
        } else { _speak('Rất tiếc, tôi không tìm thấy kết quả nào cho "$query" ở gần đây.'); }
      } else { _speak('Gặp lỗi khi tìm kiếm, bạn thử lại sau nhé.'); }
    } catch (e) { _speak('Đã xảy ra lỗi mạng khi tìm kiếm.'); }
  }

  void _onSpeechResult(SpeechRecognitionResult result) async {
    setState(() {
      _lastWords = result.recognizedWords;
      if (!_isAiListening) {
        _searchController.text = _lastWords;
        _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
      }
    });
    if (!result.finalResult || result.recognizedWords.isEmpty) return;
    await _stopListening();
    final String spokenText = result.recognizedWords;
    String lowerCaseText = spokenText.toLowerCase();
    const List<String> fromKeywords = ['từ', 'xuất phát từ'];
    const List<String> toKeywords = ['đến', 'tới'];
    String? startAddressRaw; String? endAddressRaw;
    int fromIndex = -1; int toIndex = -1;
    String fromKeywordUsed = ''; String toKeywordUsed = '';

    for (var keyword in fromKeywords) { fromIndex = lowerCaseText.indexOf(keyword); if (fromIndex != -1) { fromKeywordUsed = keyword; break; } }
    if (fromIndex != -1) { for (var keyword in toKeywords) { toIndex = lowerCaseText.indexOf(keyword, fromIndex + fromKeywordUsed.length); if (toIndex != -1) { toKeywordUsed = keyword; break; } } }

    if (fromIndex != -1 && toIndex != -1 && toIndex > fromIndex) {
      startAddressRaw = spokenText.substring(fromIndex + fromKeywordUsed.length, toIndex).trim();
      endAddressRaw = spokenText.substring(toIndex + toKeywordUsed.length).trim();
      if (startAddressRaw.isNotEmpty && endAddressRaw.isNotEmpty) {
        _searchService.saveSearchQuery('$startAddressRaw đến $endAddressRaw');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang tìm đường từ "$startAddressRaw" đến "$endAddressRaw"...')));
        try {
          final results = await Future.wait([locationFromAddress(startAddressRaw), locationFromAddress(endAddressRaw)]);
          if (results[0].isNotEmpty && results[1].isNotEmpty && mounted) {
            final startPoint = LatLng(results[0].first.latitude, results[0].first.longitude);
            final endPoint = LatLng(results[1].first.latitude, results[1].first.longitude);
            setState(() { _currentViewState = MapViewState.directions; _startLocation = LocationInput(address: startAddressRaw!, coordinates: startPoint); _endLocation = LocationInput(address: endAddressRaw!, coordinates: endPoint); _markers.clear(); _searchController.clear(); _suggestions = []; _isAiListening = false; });
            _getDirections(); return;
          } else { _speak('Không tìm thấy địa điểm.'); setState(() => _isAiListening = false); return; }
        } catch (e) { _speak('Lỗi: $e'); setState(() => _isAiListening = false); return; }
      }
    }
    if (_isAiListening) { setState(() { _isListening = false; _lastWords = spokenText; }); _handleAiRequest(spokenText); }
    else { _handleSimpleDirectionOrSearch(spokenText); }
  }

  Future<void> _handleSimpleDirectionOrSearch(String spokenText) async {
    const List<String> directionKeywords = ['chỉ đường đến', 'tìm đường đến', 'đường đi đến', 'đi đến', 'chỉ đường tới', 'tìm đường tới', 'đường đi tới', 'đi tới'];
    String? destination;
    for (var keyword in directionKeywords) { if (spokenText.toLowerCase().startsWith(keyword)) { destination = spokenText.substring(keyword.length).trim(); break; } }
    if (destination != null && destination.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang tự động tìm đường đến "$destination"...')));
      _searchService.saveSearchQuery(destination); _findAndNavigate(destination);
    } else { _searchController.text = spokenText; _debouncer.run(() => _fetchSuggestions(spokenText)); }
  }

  Future<void> _handleAiRequest(String spokenText) async {
    String? currentLocationString;
    if (_currentPosition != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          currentLocationString = [p.street, p.subLocality, p.locality, p.subAdministrativeArea, p.administrativeArea].where((s) => s != null && s.isNotEmpty).join(', ');
        }
      } catch (e) { currentLocationString = "Không xác định"; }
    }
    try {
      final aiParsedResult = await _aiService.getAiResponse(spokenText, currentLocation: currentLocationString);
      if (!mounted) return;
      setState(() { _isAiListening = false; _isAiSpeaking = true; _aiResponseText = aiParsedResult.speech; });
      _speak(aiParsedResult.speech);
      if (aiParsedResult.action != 'none' && aiParsedResult.query != null) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          if (aiParsedResult.action == 'search') { _searchNearby(aiParsedResult.query!); }
          else if (aiParsedResult.action == 'navigate') { _findAndNavigate(aiParsedResult.query!); }
        });
      }
    } catch (error) { setState(() => _isAiListening = false); _speak("Lỗi xử lý AI."); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: FutureBuilder<Position?>(
        future: _locationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _darkAccent), const SizedBox(height: 16), Text('Đang lấy vị trí...', style: TextStyle(color: _darkText))]));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Lỗi: ${snapshot.error}', style: TextStyle(color: _darkText)));
          }
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                    initialCenter: LatLng(snapshot.data!.latitude, snapshot.data!.longitude),
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.doubleTapZoom),
                    onLongPress: (tapPosition, point) => _handleLongPress(point),
                    onTap: (tapPosition, point) { if (_searchFocusNode.hasFocus) _searchFocusNode.unfocus(); }),
                children: [
                  if (_currentMapLayer == MapLayerType.normal)
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.vo_minh_hieu',
                      tileBuilder: (context, tileWidget, tile) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            -0.2126, -0.7152, -0.0722, 0, 255,
                            -0.2126, -0.7152, -0.0722, 0, 255,
                            -0.2126, -0.7152, -0.0722, 0, 255,
                            0, 0, 0, 1, 0,
                          ]),
                          child: tileWidget,
                        );
                      },
                    ),
                  if (_currentMapLayer == MapLayerType.satellite)
                    TileLayer(urlTemplate: _esriUrl, userAgentPackageName: 'com.example.vo_minh_hieu'),
                  if (_directionDetails != null)
                    PolylineLayer(polylines: [Polyline(points: _directionDetails!.points, strokeWidth: 5.0, color: _darkAccent)]),
                  MarkerLayer(markers: _markers),
                ],
              ),
              if (_currentViewState == MapViewState.browsing) _buildBrowsingControlButtons(),
              if (_currentViewState == MapViewState.directions) _buildDirectionsSheet(),
              if (_isListening || _isAiListening || _isAiSpeaking)
                Positioned(
                  bottom: 100, left: 15, right: 15,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          if (_isListening) const Icon(Icons.mic, color: Colors.red, size: 30)
                          else if (_isAiListening) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          else const Icon(Icons.support_agent, color: Colors.blue, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_isListening ? 'Đang lắng nghe...' : 'Trợ lý AI', style: TextStyle(color: _darkText, fontWeight: FontWeight.bold)),
                                Text(_isListening ? '...' : _isAiListening ? 'Đang xử lý: "$_lastWords"' : _aiResponseText, style: TextStyle(color: _darkTextSecondary, fontSize: 14), maxLines: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              _buildMapActionButtons(),
              _buildSearchUI(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchUI() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12, right: 12),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(30),
              color: _darkSurface,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  // SỬA Ở ĐÂY: Thay vì gọi trực tiếp _fetchSuggestions,
                  // mình bọc nó vào _debouncer
                  _debouncer.run(() => _fetchSuggestions(value));
                },
                style: TextStyle(color: _darkText),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm hoặc nhập địa chỉ...',
                  hintStyle: TextStyle(color: _darkTextSecondary),
                  prefixIcon: Icon(Icons.search, color: _darkTextSecondary),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty) IconButton(icon: Icon(Icons.clear, color: _darkTextSecondary), onPressed: () => _searchController.clear()),
                      IconButton(icon: Icon(Icons.mic, color: _isListening ? Colors.red : _darkAccent), onPressed: _startListening),
                    ],
                  ),
                  filled: true,
                  fillColor: _darkSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty && (_suggestions.isNotEmpty || _isFetchingSuggestions)) _buildSuggestionsList()
          else if (_searchController.text.isEmpty && _searchFocusNode.hasFocus) _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
      decoration: BoxDecoration(color: _darkSurface, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)]),
      child: FutureBuilder<List<String>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: CircularProgressIndicator(color: _darkAccent)));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return ListTile(leading: const Icon(Icons.info_outline, color: Colors.grey), title: Text('Không có lịch sử.', style: TextStyle(color: _darkTextSecondary)));
          var historyItems = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Tìm kiếm gần đây", style: TextStyle(color: _darkText, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () async { await _searchService.clearSearchHistory(); setState(() => _historyFuture = _searchService.getSearchHistory()); }),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true, itemCount: historyItems.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(historyItems[index], style: TextStyle(color: _darkText)),
                    trailing: IconButton(icon: const Icon(Icons.clear, color: Colors.grey, size: 20), onPressed: () async { historyItems.removeAt(index); final prefs = await SharedPreferences.getInstance(); await prefs.setStringList('search_history', historyItems); setState(() {}); }),
                    onTap: () { _searchService.saveSearchQuery(historyItems[index]); _searchController.text = historyItems[index]; _searchFocusNode.unfocus(); _findAndNavigate(historyItems[index]); },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
      decoration: BoxDecoration(color: _darkSurface, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)]),
      child: _isFetchingSuggestions ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: CircularProgressIndicator(color: _darkAccent))) : ListView.builder(
        shrinkWrap: true, itemCount: _suggestions.length,
        itemBuilder: (context, index) => ListTile(
          leading: Icon(Icons.location_on_outlined, color: _darkAccent),
          title: Text(_suggestions[index].displayName, style: TextStyle(color: _darkText), maxLines: 2),
          onTap: () => _onSuggestionTapped(_suggestions[index]),
        ),
      ),
    );
  }

  Future<void> _findAndNavigate(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty && _currentPosition != null) {
        final destinationPoint = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() { _currentViewState = MapViewState.directions; _startLocation = LocationInput(address: 'Vị trí của bạn', coordinates: LatLng(_currentPosition!.latitude, _currentPosition!.longitude)); _endLocation = LocationInput(address: address, coordinates: destinationPoint); _markers.clear(); _searchController.clear(); _suggestions = []; });
        _getDirections();
      }
    } catch (e) { debugPrint("Navigation error: $e"); }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _addUserMarker(_currentPosition!);
      return _currentPosition;
    } catch (e) { return null; }
  }

  Future<void> _fetchSuggestions(String query) async {
    // 1. Nếu xóa hết chữ, xóa luôn gợi ý ngay lập tức
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }

    // 2. Chỉ tìm kiếm khi gõ từ 2-3 ký tự trở lên để tránh tìm kiếm rác
    if (query.length < 2) return;

    if (mounted) setState(() => _isFetchingSuggestions = true);

    // Thêm giới hạn quốc gia (vn) để Server phản hồi nhanh hơn
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=vn');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'com.example.vo_minh_hieu'});
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _suggestions = data
              .map((item) => SearchSuggestion(
            displayName: item['display_name'],
            point: LatLng(double.parse(item['lat']), double.parse(item['lon'])),
          ))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Lỗi khi lấy gợi ý: $e");
    } finally {
      if (mounted) setState(() => _isFetchingSuggestions = false);
    }
  }


  Future<void> _handleLongPress(LatLng point) async {
    // Nếu đang xem vị trí từ Chat (có avatar), không cho phép đè giữ để đổi vị trí
    if (widget.initialTargetLocation != null) return;

    HapticFeedback.mediumImpact();
    _updateSearchedLocationMarker(point);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      String address = placemarks.isNotEmpty
          ? [placemarks.first.street, placemarks.first.locality].where((s) => s != null && s!.isNotEmpty).join(', ')
          : "Vị trí đã chọn";
      _showLocationDetailsSheet(SearchSuggestion(displayName: address, point: point));
    } catch (e) { debugPrint("Long press error: $e"); }
  }


  void _onSuggestionTapped(SearchSuggestion suggestion) {
    _searchService.saveSearchQuery(suggestion.displayName);
    _searchFocusNode.unfocus();
    setState(() {
      _suggestions = []; _searchController.clear();
      if (_isEditingStart) { _startLocation = LocationInput(address: suggestion.displayName, coordinates: suggestion.point); _isEditingStart = false; if (_endLocation.coordinates != null) _getDirections(); }
      else { _currentViewState = MapViewState.browsing; _directionDetails = null; _animatedMove(suggestion.point, 15.0); _updateSearchedLocationMarker(suggestion.point); _showLocationDetailsSheet(suggestion); }
    });
  }

  Future<void> _getDirections() async {
    if (_startLocation.coordinates == null || _endLocation.coordinates == null) return;
    final url = Uri.parse('https://graphhopper.com/api/1/route?point=${_startLocation.coordinates!.latitude},${_startLocation.coordinates!.longitude}&point=${_endLocation.coordinates!.latitude},${_endLocation.coordinates!.longitude}&vehicle=$_selectedVehicle&locale=vi&calc_points=true&key=$_graphhopperApiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final path = json.decode(response.body)['paths'][0];
        List<PointLatLng> decodedResult = PolylinePoints.decodePolyline(path['points']);
        List<LatLng> points = decodedResult.map((p) => LatLng(p.latitude, p.longitude)).toList();
        setState(() { _directionDetails = DirectionDetails(points: points, distance: (path['distance'] / 1000).toStringAsFixed(1), duration: _formatDuration((path['time'] / (1000 * 60)).round())); _updateDirectionMarkers(); });
        _fitRouteOnScreen();
      }
    } catch (e) { debugPrint("Directions error: $e"); }
  }

  void _listenToCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) { if (mounted) setState(() => _compassHeading = event.heading); });
  }

  void _resetRotation() {
    final animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    final rotateAnim = Tween<double>(begin: _mapController.camera.rotation, end: 0.0).animate(animation)..addListener(() => _mapController.rotate(animation.value));
    animation.forward().whenComplete(() => animation.dispose());
  }

  void _openInGoogleMaps() {
    if (_currentPosition != null) launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}'), mode: LaunchMode.externalApplication);
  }

// 1. VỊ TRÍ CỦA MÌNH (Người nhận/Người xem bản đồ)
  void _addUserMarker(Position pos) {
    setState(() {
      final point = LatLng(pos.latitude, pos.longitude); // Tạo tọa độ
      _markers.removeWhere((m) => m.key == const Key('user_marker'));
      _markers.add(Marker(
        key: const Key('user_marker'),
        point: point,
        width: 50,
        height: 50,
        child: widget.receiverAvatar != null
            ? _buildAvatarMarker(widget.receiverAvatar!, Colors.blueAccent, point) // Truyền đủ 3 tham số
            : Icon(Icons.person_pin_circle, color: _darkAccent, size: 45),
      ));
    });
  }


  void _updateSearchedLocationMarker(LatLng point) {
    setState(() {
      _markers.removeWhere((m) => m.key == const Key('search_marker'));
      _markers.add(Marker(
        key: const Key('search_marker'),
        point: point,
        width: 60,
        height: 60,
        child: widget.senderAvatar != null
            ? _buildAvatarMarker(widget.senderAvatar!, Colors.orangeAccent, point) // Truyền đủ 3 tham số
            : const Icon(Icons.location_on, color: Colors.blueAccent, size: 45),
      ));
    });
  }



  void _updateDirectionMarkers() {
    _markers.clear();

    // Ghim điểm đi (Vị trí của mình)
    if (_startLocation.coordinates != null) {
      _addUserMarker(Position(
          latitude: _startLocation.coordinates!.latitude,
          longitude: _startLocation.coordinates!.longitude,
          timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0
      ));
    }

    // Ghim điểm đến (Vị trí đối phương)
    if (_endLocation.coordinates != null) {
      _updateSearchedLocationMarker(_endLocation.coordinates!);
    }
  }


  void _animatedMove(LatLng dest, double zoom) {
    final animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: dest.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: dest.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: zoom);
    animation.addListener(() => _mapController.move(LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)), zoomTween.evaluate(animation)));
    animation.forward().whenComplete(() => animation.dispose());
  }

  void _fitRouteOnScreen() {
    if (_startLocation.coordinates == null || _endLocation.coordinates == null) return;
    _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds(_startLocation.coordinates!, _endLocation.coordinates!), padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 150)));
  }

  Widget _buildMapActionButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80, right: 16,
      child: Column(
        children: [
          FloatingActionButton(
              mini: true,
              heroTag: 'fab_compass', // <--- TAG RIÊNG
              backgroundColor: _darkSurface,
              onPressed: _resetRotation,
              child: Transform.rotate(
                  angle: (-(_compassHeading ?? 0) * (pi / 180)),
                  child: const Icon(Icons.navigation, color: Colors.white70)
              )
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
              mini: true,
              heroTag: 'fab_layer', // <--- TAG RIÊNG
              backgroundColor: _darkSurface,
              onPressed: () => setState(() => _currentMapLayer = _currentMapLayer == MapLayerType.normal ? MapLayerType.satellite : MapLayerType.normal),
              child: Icon(_currentMapLayer == MapLayerType.normal ? Icons.satellite_alt_outlined : Icons.map_outlined, color: Colors.white70)
          ),
        ],
      ),
    );
  }

  Widget _buildBrowsingControlButtons() {
    return Positioned(
      bottom: 30, right: 20,
      child: Column(
        children: [
          FloatingActionButton(
              heroTag: 'fab_ai', // <--- TAG RIÊNG
              backgroundColor: Colors.deepPurple,
              onPressed: _startAiListening,
              child: const Icon(Icons.auto_awesome, color: Colors.white)
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
              heroTag: 'fab_location', // <--- TAG RIÊNG
              backgroundColor: _darkSurface,
              onPressed: () { if (_currentPosition != null) _animatedMove(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0); },
              child: Icon(Icons.my_location, color: _darkAccent)
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
              heroTag: 'fab_google_maps', // <--- TAG RIÊNG
              backgroundColor: _darkSurface,
              onPressed: _openInGoogleMaps,
              child: const Icon(Icons.map, color: Colors.green)
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsSheet() {
    Widget _buildIcon(String v, IconData i) => IconButton(
      icon: Icon(i, size: 28),
      color: _selectedVehicle == v ? _darkAccent : Colors.grey,
      onPressed: () {
        setState(() => _selectedVehicle = v);
        _getDirections();
      },
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      maxChildSize: 0.6,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: _darkSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: Container(width: 40, height: 4, color: Colors.white12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIcon('car', Icons.directions_car),
                _buildIcon('bike', Icons.directions_bike),
                _buildIcon('foot', Icons.directions_walk)
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    // CẬP NHẬT Ở ĐÂY: Hiển thị cả thời gian và số km
                    _directionDetails != null
                        ? "${_directionDetails!.duration} (${_directionDetails!.distance} km)"
                        : 'Đang tính...',
                    style: TextStyle(
                      color: _darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    _currentViewState = MapViewState.browsing;
                    _directionDetails = null;
                    if (_currentPosition != null) _addUserMarker(_currentPosition!);
                  }),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: Text(
                _startLocation.address,
                style: TextStyle(color: _darkText, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: Text(
                _endLocation.address,
                style: TextStyle(color: _darkText, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

class LocationInput { String address; LatLng? coordinates; LocationInput({this.address = '', this.coordinates}); }
class SearchSuggestion { final String displayName; final LatLng point; SearchSuggestion({required this.displayName, required this.point}); }
