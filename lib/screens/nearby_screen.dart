import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/customer_app_bar.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/customer_drawer.dart';
import '../providers/locale_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/auth_provider.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
const Color _kDarkSurfaceColor = Color(0xFF161B2E);
const Color _kDarkPrimaryPurple = Color(0xFFBDB2FF);
const Color _kDarkAccentCyan = Color(0xFF00D1FF);
const Color _kDarkInputBorderColor = Color(0xFF2E344A);
const Color _kDarkHintTextColor = Color(0xFF6B7280);
const Color _kDarkCardColor = Color(0xFF1C2237);
const Color _kSuccessGreen = Color(0xFF4ADE80);

// ─── Simulated Route: F-8 Sector → F-10 Sector (Islamabad) ──────────────────
const List<LatLng> _kSimulatedRoute = [
  LatLng(33.7104, 73.0534), // F-8 Markaz (Start)
  LatLng(33.7090, 73.0510), // F-8 Service Road
  LatLng(33.7078, 73.0488), // F-8/1 junction
  LatLng(33.7060, 73.0460), // Margalla Road turn
  LatLng(33.7042, 73.0435), // Near Faisal Mosque Road
  LatLng(33.7025, 73.0408), // Towards F-9 Park
  LatLng(33.7010, 73.0380), // F-9 Park entrance
  LatLng(33.6998, 73.0352), // F-9 main road
  LatLng(33.6985, 73.0325), // F-9/F-10 boundary
  LatLng(33.6975, 73.0298), // F-10 Markaz approach
  LatLng(33.6965, 73.0270), // F-10/1 junction
  LatLng(33.6955, 73.0240), // F-10/2 Service Road
  LatLng(33.6948, 73.0210), // F-10/3 inner street
  LatLng(33.6942, 73.0180), // Near destination
  LatLng(33.6936, 73.0127), // Customer Home F-10 (End)
];

// ─── Provider Navigation Steps ──────────────────────────────────────────────
const List<Map<String, String>> _kNavigationSteps = [
  {'instruction': 'Head south on F-8 Markaz Road', 'distance': '300 m'},
  {'instruction': 'Turn right onto Service Road East', 'distance': '450 m'},
  {'instruction': 'Continue on Jinnah Avenue', 'distance': '600 m'},
  {'instruction': 'Keep left at the Margalla Road fork', 'distance': '400 m'},
  {'instruction': 'Turn left onto F-9 Park Road', 'distance': '500 m'},
  {'instruction': 'Continue straight past F-9 Park', 'distance': '350 m'},
  {'instruction': 'Turn right at F-10 roundabout', 'distance': '250 m'},
  {'instruction': 'Enter F-10 Markaz', 'distance': '200 m'},
  {'instruction': 'Turn left onto Street 14', 'distance': '150 m'},
  {'instruction': 'Destination is on your right', 'distance': '50 m'},
];

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen>
    with TickerProviderStateMixin {
  // ─── Map State ───────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng _currentLatLng = const LatLng(33.6844, 73.0479);
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];

  static const List<Map<String, dynamic>> _islamabadLandmarks = [
    {
      'formatted_address': 'Faisal Mosque, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.7297, 'lng': 73.0372}
      }
    },
    {
      'formatted_address': 'Centaurus Mall, F-8, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.7077, 'lng': 73.0498}
      }
    },
    {
      'formatted_address': 'Zero Point, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.6938, 'lng': 73.0652}
      }
    },
    {
      'formatted_address': 'Safa Gold Mall, F-7, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.7171, 'lng': 73.0560}
      }
    },
    {
      'formatted_address': 'Giga Mall, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.5251, 'lng': 73.1491}
      }
    },
    {
      'formatted_address': 'Rawal Lake, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.7001, 'lng': 73.1257}
      }
    },
    {
      'formatted_address': 'Daman-e-Koh, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.7380, 'lng': 73.0592}
      }
    },
    {
      'formatted_address': 'Lok Virsa Museum, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.6811, 'lng': 73.0694}
      }
    },
    {
      'formatted_address': 'Islamic International University, H-10, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.6593, 'lng': 73.0242}
      }
    },
    {
      'formatted_address': 'National University of Sciences & Technology (NUST), H-12, Islamabad, Pakistan',
      'geometry': {
        'location': {'lat': 33.6426, 'lng': 72.9904}
      }
    },
  ];
  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  late PolylinePoints _polylinePoints;
  String _travelMode = 'driving';

  // ─── Tracking State ──────────────────────────────────────────────────────
  Timer? _trackingTimer;
  int _currentWaypointIndex = 0;
  bool _providerArrived = false;
  double _currentDistance = 0.0;
  int _currentETA = 0;
  bool _isTrackingMode = false;
  bool _isProviderMode = false;

  // ─── Provider Nav State ──────────────────────────────────────────────────
  int _currentNavStepIndex = 0;
  Timer? _navStepTimer;

  // ─── Animation ───────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _arrivalController;
  late Animation<double> _arrivalScaleAnimation;
  late Animation<double> _arrivalOpacityAnimation;
  late AnimationController _sheetSlideController;
  late Animation<Offset> _sheetSlideAnimation;

  @override
  void initState() {
    super.initState();
    _polylinePoints =
        PolylinePoints(apiKey: "AIzaSyBIGjvzRpCVZRtWgmbHIVn3OHecXZhYJRI");

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _arrivalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _arrivalScaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _arrivalController, curve: Curves.elasticOut),
    );
    _arrivalOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _arrivalController, curve: Curves.easeOut),
    );

    _sheetSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sheetSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _sheetSlideController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMode();
    });
  }

  void _initializeMode() {
    final bookingState = ref.read(bookingProvider);
    final authState = ref.read(authProvider);
    final userRole = authState.user?.role ?? 'customer';

    if (bookingState.result != null) {
      if (userRole == 'provider') {
        _startProviderNavigation();
      } else {
        _startCustomerTracking();
      }
    } else {
      _setInitialLocation();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOMER TRACKING MODE
  // ═══════════════════════════════════════════════════════════════════════════

  void _startCustomerTracking() {
    setState(() {
      _isTrackingMode = true;
      _isProviderMode = false;
      _currentWaypointIndex = 0;
      _providerArrived = false;
      _currentDistance = _calculateTotalDistance();
      _currentETA = _calculateInitialETA();
    });

    _setupTrackingMarkers();
    _setupTrackingPolyline();
    _sheetSlideController.forward();

    // Center camera to show the full route
    _fitCameraToRoute();

    // Start simulated movement
    _trackingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_currentWaypointIndex < _kSimulatedRoute.length - 1) {
        setState(() {
          _currentWaypointIndex++;
          _updateProviderMarker();
          _updateTrackingPolyline();
          _currentDistance = _calculateRemainingDistance();
          _currentETA = _calculateRemainingETA();
        });

        // Smoothly animate camera to follow the car
        final currentPos = _kSimulatedRoute[_currentWaypointIndex];
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(currentPos),
        );

        // Provider has arrived at the last waypoint
        if (_currentWaypointIndex >= _kSimulatedRoute.length - 1) {
          timer.cancel();
          setState(() {
            _providerArrived = true;
            _currentDistance = 0;
            _currentETA = 0;
          });
          _arrivalController.forward();
        }
      }
    });
  }

  void _setupTrackingMarkers() {
    // Customer Home Marker
    const customerMarkerId = MarkerId('customer_home');
    final customerMarker = Marker(
      markerId: customerMarkerId,
      position: _kSimulatedRoute.last,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: const InfoWindow(
        title: 'Your Home',
        snippet: 'F-10, Islamabad',
      ),
    );

    // Provider Car Marker
    const providerMarkerId = MarkerId('provider_car');
    final providerMarker = Marker(
      markerId: providerMarkerId,
      position: _kSimulatedRoute.first,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      infoWindow: const InfoWindow(
        title: 'Provider',
        snippet: 'On the way...',
      ),
      flat: true,
      anchor: const Offset(0.5, 0.5),
    );

    setState(() {
      _markers[customerMarkerId] = customerMarker;
      _markers[providerMarkerId] = providerMarker;
    });
  }

  void _updateProviderMarker() {
    const providerMarkerId = MarkerId('provider_car');
    final newPos = _kSimulatedRoute[_currentWaypointIndex];

    // Calculate rotation based on bearing to next point
    double rotation = 0;
    if (_currentWaypointIndex < _kSimulatedRoute.length - 1) {
      rotation = _calculateBearing(
        newPos,
        _kSimulatedRoute[_currentWaypointIndex + 1],
      );
    }

    final updatedMarker = Marker(
      markerId: providerMarkerId,
      position: newPos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      infoWindow: InfoWindow(
        title: 'Provider',
        snippet: _providerArrived ? 'Arrived!' : 'On the way...',
      ),
      flat: true,
      rotation: rotation,
      anchor: const Offset(0.5, 0.5),
    );

    setState(() {
      _markers[providerMarkerId] = updatedMarker;
    });
  }

  void _setupTrackingPolyline() {
    const polylineId = PolylineId('tracking_route');
    final polyline = Polyline(
      polylineId: polylineId,
      color: _kDarkAccentCyan,
      points: _kSimulatedRoute.toList(),
      width: 5,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
    );
    setState(() {
      _polylines[polylineId] = polyline;
    });
  }

  void _updateTrackingPolyline() {
    const polylineId = PolylineId('tracking_route');
    final remainingRoute =
        _kSimulatedRoute.sublist(_currentWaypointIndex);
    final polyline = Polyline(
      polylineId: polylineId,
      color: _kDarkAccentCyan,
      points: remainingRoute,
      width: 5,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
    );

    // Add traveled path
    const traveledId = PolylineId('traveled_route');
    final traveledRoute =
        _kSimulatedRoute.sublist(0, _currentWaypointIndex + 1);
    final traveledPolyline = Polyline(
      polylineId: traveledId,
      color: _kDarkPrimaryPurple.withOpacity(0.4),
      points: traveledRoute,
      width: 4,
    );

    setState(() {
      _polylines[polylineId] = polyline;
      _polylines[traveledId] = traveledPolyline;
    });
  }

  void _fitCameraToRoute() {
    if (_mapController == null) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final point in _kSimulatedRoute) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.005, minLng - 0.005),
          northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        80,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROVIDER NAVIGATION MODE
  // ═══════════════════════════════════════════════════════════════════════════

  void _startProviderNavigation() {
    setState(() {
      _isProviderMode = true;
      _isTrackingMode = false;
      _currentNavStepIndex = 0;
      _currentWaypointIndex = 0;
      _providerArrived = false;
    });

    _setupTrackingMarkers();
    _setupTrackingPolyline();
    _fitCameraToRoute();

    // Advance navigation steps automatically
    _navStepTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentNavStepIndex < _kNavigationSteps.length - 1) {
        setState(() {
          _currentNavStepIndex++;
          if (_currentWaypointIndex < _kSimulatedRoute.length - 1) {
            _currentWaypointIndex++;
            _updateProviderMarker();
            _updateTrackingPolyline();
          }
        });

        final currentPos = _kSimulatedRoute[_currentWaypointIndex];
        _mapController?.animateCamera(CameraUpdate.newLatLng(currentPos));
      } else {
        timer.cancel();
        setState(() => _providerArrived = true);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NORMAL MODE (fallback)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _setInitialLocation() async {
    final location = loc.Location();
    try {
      final locationData = await location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLatLng =
              LatLng(locationData.latitude!, locationData.longitude!);
        });
      }
    } catch (_) {
      // Use default Islamabad coords
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    // Try local landmarks first
    final localMatches = _islamabadLandmarks.where((landmark) {
      final name = landmark['formatted_address'].toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    if (localMatches.isNotEmpty) {
      setState(() => _searchResults = localMatches);
      return;
    }

    const String apiKey = "AIzaSyBIGjvzRpCVZRtWgmbHIVn3OHecXZhYJRI";
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() => _searchResults = data['results']);
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  void _onResultTap(dynamic result) {
    final locData = result['geometry']['location'];
    final destLatLng = LatLng(locData['lat'], locData['lng']);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(destLatLng, 16));
    _addMarker(destLatLng, "Searched Location", result['formatted_address']);
    _getPolyline(destLatLng);
    setState(() {
      _searchResults = [];
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _addMarker(LatLng position, String id, String info) {
    final markerId = MarkerId(id);
    final marker = Marker(
      markerId: markerId,
      position: position,
      infoWindow: InfoWindow(title: id, snippet: info),
      onTap: () => _getPolyline(position),
    );
    setState(() => _markers[markerId] = marker);
  }

  Future<void> _getPolyline(LatLng dest) async {
    _polylineCoordinates.clear();
    PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin:
            PointLatLng(_currentLatLng.latitude, _currentLatLng.longitude),
        destination: PointLatLng(dest.latitude, dest.longitude),
        mode: _travelMode == 'driving'
            ? TravelMode.driving
            : TravelMode.walking,
      ),
    );
    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }
    _addPolyline();
  }

  void _addPolyline() {
    const id = PolylineId("poly");
    final polyline = Polyline(
      polylineId: id,
      color: _kDarkPrimaryPurple,
      points: _polylineCoordinates,
      width: 5,
    );
    setState(() => _polylines[id] = polyline);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  double _calculateTotalDistance() {
    double total = 0;
    for (int i = 0; i < _kSimulatedRoute.length - 1; i++) {
      total += _haversineDistance(
          _kSimulatedRoute[i], _kSimulatedRoute[i + 1]);
    }
    return total;
  }

  int _calculateInitialETA() {
    // Estimate 2 minutes per km at ~30 km/h city speed
    final distKm = _calculateTotalDistance();
    return (distKm * 2.5).ceil().clamp(1, 30);
  }

  double _calculateRemainingDistance() {
    double total = 0;
    for (int i = _currentWaypointIndex;
        i < _kSimulatedRoute.length - 1;
        i++) {
      total += _haversineDistance(
          _kSimulatedRoute[i], _kSimulatedRoute[i + 1]);
    }
    return total;
  }

  int _calculateRemainingETA() {
    final remaining = _calculateRemainingDistance();
    return (remaining * 2.5).ceil().clamp(0, 30);
  }

  double _haversineDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final h = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) *
            cos(_toRad(b.latitude)) *
            sinDLng *
            sinDLng;
    return 2 * earthRadius * asin(sqrt(h));
  }

  double _toRad(double deg) => deg * pi / 180;

  double _calculateBearing(LatLng from, LatLng to) {
    final dLng = _toRad(to.longitude - from.longitude);
    final fromLat = _toRad(from.latitude);
    final toLat = _toRad(to.latitude);
    final y = sin(dLng) * cos(toLat);
    final x =
        cos(fromLat) * sin(toLat) - sin(fromLat) * cos(toLat) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _navStepTimer?.cancel();
    _pulseController.dispose();
    _arrivalController.dispose();
    _sheetSlideController.dispose();
    _searchCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final locale = ref.watch(localeProvider);
    final bookingState = ref.watch(bookingProvider);

    final backgroundColor =
        isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final primaryPurple =
        isDark ? _kDarkPrimaryPurple : const Color(0xFF4F46E5);
    final inputBorderColor =
        isDark ? _kDarkInputBorderColor : const Color(0xFFE2E8F0);
    final hintTextColor =
        isDark ? _kDarkHintTextColor : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _isTrackingMode || _isProviderMode ? null : const CustomerAppBar(),
      drawer: _isTrackingMode || _isProviderMode ? null : const CustomerDrawer(),
      body: Stack(
        children: [
          // ─── Map ─────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _currentLatLng, zoom: 14),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_isTrackingMode || _isProviderMode) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  _fitCameraToRoute();
                });
              }
              // Apply dark map style
              if (isDark) {
                controller.setMapStyle(_kDarkMapStyle);
              }
            },
            myLocationEnabled: !_isTrackingMode && !_isProviderMode,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: Set<Marker>.of(_markers.values),
            polylines: Set<Polyline>.of(_polylines.values),
            padding: EdgeInsets.only(
              bottom: _isTrackingMode ? 300 : 0,
              top: _isProviderMode ? 120 : 0,
            ),
            onTap: (!_isTrackingMode && !_isProviderMode)
                ? (latLng) {
                    _addMarker(latLng, "Custom Pin",
                        "${latLng.latitude}, ${latLng.longitude}");
                    _getPolyline(latLng);
                  }
                : null,
          ),

          // ─── CUSTOMER TRACKING UI ────────────────────────────────────────
          if (_isTrackingMode) ...[
            // Top status bar
            _buildTrackingTopBar(isDark, bookingState, locale),
            // Bottom sheet
            _buildTrackingBottomSheet(
                isDark, bookingState, primaryPurple, textColor),
            // Arrival overlay
            if (_providerArrived) _buildArrivalOverlay(isDark),
          ],

          // ─── PROVIDER NAVIGATION UI ──────────────────────────────────────
          if (_isProviderMode) ...[
            _buildProviderNavBanner(isDark),
            _buildProviderBottomButton(isDark),
          ],

          // ─── NORMAL MODE UI ──────────────────────────────────────────────
          if (!_isTrackingMode && !_isProviderMode) ...[
            // Search Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: inputBorderColor),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(color: textColor),
                      onChanged: (val) {
                        if (val.length > 2) _searchLocation(val);
                        if (val.isEmpty) {
                          setState(() => _searchResults = []);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search nearby...',
                        hintStyle:
                            TextStyle(color: hintTextColor, fontSize: 14),
                        prefixIcon:
                            Icon(Icons.search, color: hintTextColor),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: inputBorderColor),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final res = _searchResults[index];
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              title: Text(res['formatted_address'] ?? '',
                                  style: TextStyle(
                                      color: textColor, fontSize: 13)),
                              onTap: () => _onResultTap(res),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            // Travel Mode Toggle
            Positioned(
              bottom: 100,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: inputBorderColor),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 6)
                  ],
                ),
                child: Row(
                  children: [
                    _buildModeBtn(Icons.directions_car, 'driving',
                        primaryPurple, textColor),
                    _buildModeBtn(Icons.directions_walk, 'walking',
                        primaryPurple, textColor),
                  ],
                ),
              ),
            ),
            // GPS Button
            Positioned(
              bottom: 100,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: surfaceColor,
                shape: const CircleBorder(),
                heroTag: 'gps_fab',
                onPressed: () async {
                  final location = loc.Location();
                  final locData = await location.getLocation();
                  if (locData.latitude != null) {
                    final latLng =
                        LatLng(locData.latitude!, locData.longitude!);
                    setState(() => _currentLatLng = latLng);
                    _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(latLng, 18));
                  }
                },
                child: Icon(Icons.gps_fixed, color: primaryPurple),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          (!_isTrackingMode && !_isProviderMode)
              ? const CustomerBottomNav(currentIndex: 2)
              : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOMER TRACKING WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTrackingTopBar(
      bool isDark, BookingState bookingState, AppLocaleState locale) {
    final providerName = bookingState.result?.topProvider.name ?? 'Provider';
    final isUrdu = locale.language == AppLanguage.urdu;

    String statusText;
    if (_providerArrived) {
      statusText = isUrdu ? '$providerName پہنچ گئے ہیں!' : '$providerName has arrived!';
    } else {
      statusText = isUrdu
          ? '$providerName آ رہے ہیں'
          : '$providerName is on his way';
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? _kDarkSurfaceColor : Colors.white)
                  .withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _providerArrived
                    ? _kSuccessGreen.withOpacity(0.5)
                    : _kDarkAccentCyan.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: (_providerArrived ? _kSuccessGreen : _kDarkAccentCyan)
                      .withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: _providerArrived ? 1.0 : _pulseAnimation.value,
                    child: child,
                  ),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _providerArrived
                          ? _kSuccessGreen
                          : _kDarkAccentCyan,
                      boxShadow: [
                        BoxShadow(
                          color: (_providerArrived
                                  ? _kSuccessGreen
                                  : _kDarkAccentCyan)
                              .withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!_providerArrived)
                        Text(
                          isUrdu
                              ? '$providerName آ رہے ہیں'
                              : 'Arriving in ~$_currentETA min',
                          style: GoogleFonts.inter(
                            color: _kDarkAccentCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Back button
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kDarkPrimaryPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: _kDarkPrimaryPurple,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingBottomSheet(
      bool isDark, BookingState bookingState, Color primaryPurple, Color textColor) {
    final provider = bookingState.result?.topProvider;
    final booking = bookingState.result?.booking;
    final providerName = provider?.name ?? 'Muhammad Arshad';
    final providerRating = provider?.rating ?? 4.8;
    final providerCategory = provider?.category ?? 'Plumber';
    final providerPhone = provider?.phone ?? booking?.providerPhone ?? '03001234567';
    final serviceType = booking?.serviceType ?? providerCategory;
    final locale = ref.watch(localeProvider);
    final isUrdu = locale.language == AppLanguage.urdu;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _sheetSlideAnimation,
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          _kDarkSurfaceColor.withOpacity(0.95),
                          _kDarkBackgroundColor.withOpacity(0.98),
                        ]
                      : [
                          Colors.white.withOpacity(0.95),
                          const Color(0xFFF0F0F5).withOpacity(0.98),
                        ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: _kDarkAccentCyan.withOpacity(0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white24
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Provider Info Row
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _kDarkPrimaryPurple,
                                _kDarkAccentCyan,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _kDarkPrimaryPurple.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: provider?.profileImageUrl != null
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  child: Image.network(
                                    provider!.profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildAvatarFallback(providerName),
                                  ),
                                )
                              : _buildAvatarFallback(providerName),
                        ),
                        const SizedBox(width: 14),
                        // Name & Rating
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                providerName,
                                style: GoogleFonts.inter(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: const Color(0xFFFFD700),
                                      size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    providerRating.toStringAsFixed(1),
                                    style: GoogleFonts.inter(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _kDarkAccentCyan
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      serviceType.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: _kDarkAccentCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  if (provider?.verified == true) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.verified_rounded,
                                        color: _kDarkAccentCyan,
                                        size: 16),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ETA & Distance Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.timer_outlined,
                            label: isUrdu ? 'متوقع وقت' : 'ETA',
                            value: _providerArrived
                                ? (isUrdu ? 'پہنچ گئے' : 'Arrived')
                                : '$_currentETA min',
                            color: _kDarkAccentCyan,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.route_rounded,
                            label: isUrdu ? 'فاصلہ' : 'Distance',
                            value: _providerArrived
                                ? '0 km'
                                : '${_currentDistance.toStringAsFixed(1)} km',
                            color: _kDarkPrimaryPurple,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.attach_money_rounded,
                            label: isUrdu ? 'قیمت' : 'Price',
                            value: booking?.priceEstimate ?? 'Rs. 500+',
                            color: _kSuccessGreen,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Bilingual Status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? _kDarkCardColor.withOpacity(0.6)
                            : const Color(0xFFF5F5FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _kDarkInputBorderColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _providerArrived
                                ? '$providerName has arrived at your location!'
                                : '$providerName is on his way to your location',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _providerArrived
                                ? '!$providerName آپ کے مقام پر پہنچ گئے ہیں'
                                : '$providerName آپ کے مقام کی طرف آ رہے ہیں',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoNastaliqUrdu(
                              color: _kDarkAccentCyan.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.phone_rounded,
                            label: isUrdu ? 'کال کریں' : 'Call',
                            color: _kSuccessGreen,
                            isDark: isDark,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Calling $providerName at $providerPhone...'),
                                  backgroundColor: _kSuccessGreen,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.message_rounded,
                            label: isUrdu ? 'پیغام' : 'Message',
                            color: _kDarkPrimaryPurple,
                            isDark: isDark,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Opening chat with $providerName...'),
                                  backgroundColor: _kDarkPrimaryPurple,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildCircularAction(
                          icon: Icons.share_location_rounded,
                          color: _kDarkAccentCyan,
                          isDark: isDark,
                          onTap: () {
                            _fitCameraToRoute();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : '?';
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? color.withOpacity(0.08)
            : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  // ─── Arrival Overlay ─────────────────────────────────────────────────────
  Widget _buildArrivalOverlay(bool isDark) {
    return AnimatedBuilder(
      animation: _arrivalController,
      builder: (_, __) => Positioned.fill(
        child: IgnorePointer(
          ignoring: !_providerArrived,
          child: Opacity(
            opacity: _arrivalOpacityAnimation.value,
            child: Container(
              color: Colors.black.withOpacity(0.5 * _arrivalOpacityAnimation.value),
              child: Center(
                child: Transform.scale(
                  scale: _arrivalScaleAnimation.value,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: (isDark ? _kDarkSurfaceColor : Colors.white)
                              .withOpacity(0.9),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: _kSuccessGreen.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _kSuccessGreen.withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _kSuccessGreen,
                                    _kSuccessGreen.withOpacity(0.7),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        _kSuccessGreen.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Provider Has Arrived!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '!سروس فراہم کنندہ پہنچ گئے ہیں',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoNastaliqUrdu(
                                color: _kDarkAccentCyan,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  _trackingTimer?.cancel();
                                  context.go('/home');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kSuccessGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Go to Home',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROVIDER NAVIGATION WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProviderNavBanner(bool isDark) {
    final step = _kNavigationSteps[_currentNavStepIndex];
    final totalSteps = _kNavigationSteps.length;
    final progress = (_currentNavStepIndex + 1) / totalSteps;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? _kDarkSurfaceColor : Colors.white)
                  .withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _kDarkPrimaryPurple.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: _kDarkPrimaryPurple.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark
                        ? Colors.white10
                        : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _kDarkPrimaryPurple,
                    ),
                    minHeight: 3,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _kDarkPrimaryPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getNavIcon(step['instruction'] ?? ''),
                          color: _kDarkPrimaryPurple,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['instruction'] ?? '',
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${step['distance']} · Step ${_currentNavStepIndex + 1}/$totalSteps',
                              style: GoogleFonts.inter(
                                color: _kDarkHintTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderBottomButton(bool isDark) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recenter button
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _fitCameraToRoute,
              child: Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? _kDarkSurfaceColor.withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _kDarkInputBorderColor.withOpacity(0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.my_location_rounded,
                    color: _kDarkAccentCyan, size: 22),
              ),
            ),
          ),
          // Arrived button
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _providerArrived
                      ? () {
                          _navStepTimer?.cancel();
                          context.go('/provider_job_diagnosis');
                        }
                      : null,
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _providerArrived
                            ? [_kSuccessGreen, _kSuccessGreen.withOpacity(0.8)]
                            : [
                                _kDarkPrimaryPurple.withOpacity(0.3),
                                _kDarkAccentCyan.withOpacity(0.3)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _providerArrived
                            ? _kSuccessGreen.withOpacity(0.5)
                            : _kDarkPrimaryPurple.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: _providerArrived
                          ? [
                              BoxShadow(
                                color: _kSuccessGreen.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _providerArrived
                              ? Icons.check_circle_rounded
                              : Icons.navigation_rounded,
                          color: _providerArrived
                              ? Colors.white
                              : _kDarkHintTextColor,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _providerArrived
                              ? 'Arrived at Customer\'s Location'
                              : 'Navigating to Customer...',
                          style: GoogleFonts.inter(
                            color: _providerArrived
                                ? Colors.white
                                : _kDarkHintTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNavIcon(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('turn right')) return Icons.turn_right_rounded;
    if (lower.contains('turn left')) return Icons.turn_left_rounded;
    if (lower.contains('keep left')) return Icons.turn_slight_left_rounded;
    if (lower.contains('keep right')) return Icons.turn_slight_right_rounded;
    if (lower.contains('destination')) return Icons.flag_rounded;
    if (lower.contains('head')) return Icons.straight_rounded;
    if (lower.contains('enter')) return Icons.roundabout_right_rounded;
    return Icons.arrow_upward_rounded;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NORMAL MODE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildModeBtn(
      IconData icon, String mode, Color primaryPurple, Color textColor) {
    bool isSelected = _travelMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _travelMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryPurple : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isSelected ? Colors.white : textColor),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DARK MAP STYLE
// ═══════════════════════════════════════════════════════════════════════════════

const String _kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0a0f1d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0a0f1d"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#161b2e"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#161b2e"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#4a5568"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#0f1626"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#1c2237"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#2e344a"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#2e344a"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#3d4460"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#161b2e"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0d1321"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#2e344a"}]}
]
''';
