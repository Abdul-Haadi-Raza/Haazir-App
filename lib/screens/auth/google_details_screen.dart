import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class GoogleDetailsScreen extends ConsumerStatefulWidget {
  final String email;
  final String? name;
  final String? role;

  const GoogleDetailsScreen({
    super.key,
    required this.email,
    this.name,
    this.role,
  });

  @override
  ConsumerState<GoogleDetailsScreen> createState() => _GoogleDetailsScreenState();
}

class _GoogleDetailsScreenState extends ConsumerState<GoogleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Inline Validation Error State Variables
  String? _nameError;
  String? _phoneError;
  String? _addressError;
  String? _cnicError;
  String? _shopAddressError;
  String? _tradeError;
  String? _experienceError;
  String? _cnicFileError;
  String? _mapError;

  // Input Controllers
  late final TextEditingController _nameCtrl;
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  
  // Customer-specific controllers
  final _addressCtrl = TextEditingController();
  
  // Provider-specific controllers
  final _cnicCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  
  String? _selectedTrade;
  File? _cnicFile;
  String? _cnicFileName;
  bool _isUploading = false;
  String? _lockedRole;
  
  // Role selected when role is ambiguous
  String _activeRole = 'customer';
  
  // Maps fields
  bool _isMapExpanded = false;
  LatLng _selectedLatLng = const LatLng(33.6844, 73.0479);
  String _pinnedLocationString = "";
  
  GoogleMapController? _expandedMapController;
  List<dynamic> _searchResults = [];

  final List<String> _trades = [
    'Plumber',
    'Electrician',
    'AC Technician',
    'Carpenter',
    'Painter'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _lockedRole = widget.role;
    if (_lockedRole != null) {
      _activeRole = _lockedRole!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    _addressCtrl.dispose();
    _cnicCtrl.dispose();
    _shopAddressCtrl.dispose();
    _experienceCtrl.dispose();
    _expandedMapController?.dispose();
    super.dispose();
  }

  Future<void> _pickCnicFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _cnicFile = File(result.files.single.path!);
        _cnicFileName = result.files.single.name;
      });
    }
  }

  Future<String?> _uploadCnic(String uid) async {
    if (_cnicFile == null) return null;
    try {
      final ext = _cnicFileName?.split('.').last ?? 'jpg';
      final ref = FirebaseStorage.instance.ref().child('cnic_proofs/$uid.$ext');
      final uploadTask = await ref.putFile(_cnicFile!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage Upload error: $e");
      return null;
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final translate = ref.read(localeProvider.notifier).translate;

    setState(() {
      _nameError = null;
      _phoneError = null;
      _addressError = null;
      _cnicError = null;
      _shopAddressError = null;
      _tradeError = null;
      _experienceError = null;
      _cnicFileError = null;
      _mapError = null;
    });

    bool hasError = false;

    if (name.isEmpty) {
      setState(() => _nameError = translate('err_name_empty'));
      hasError = true;
    }

    if (phone.isEmpty) {
      setState(() => _phoneError = translate('err_phone_empty'));
      hasError = true;
    } else if (phone.length != 11 || !RegExp(r'^\d+$').hasMatch(phone)) {
      setState(() => _phoneError = translate('err_phone_length'));
      hasError = true;
    }

    if (_activeRole == 'provider') {
      final cnic = _cnicCtrl.text.trim();
      final shopAddress = _shopAddressCtrl.text.trim();
      final experience = _experienceCtrl.text.trim();

      if (_selectedTrade == null) {
        setState(() => _tradeError = translate('err_trade_empty'));
        hasError = true;
      }

      if (cnic.isEmpty) {
        setState(() => _cnicError = translate('err_cnic_empty'));
        hasError = true;
      } else if (cnic.length != 13 || !RegExp(r'^\d{13}$').hasMatch(cnic)) {
        setState(() => _cnicError = translate('err_cnic_length'));
        hasError = true;
      }

      if (shopAddress.isEmpty) {
        setState(() => _shopAddressError = translate('err_shop_address_empty'));
        hasError = true;
      }

      if (experience.isEmpty) {
        setState(() => _experienceError = translate('err_experience_empty'));
        hasError = true;
      }

      if (_cnicFile == null) {
        setState(() => _cnicFileError = translate('err_cnic_file_empty'));
        hasError = true;
      }

      if (_pinnedLocationString.isEmpty) {
        setState(() => _mapError = translate('err_shop_map_empty'));
        hasError = true;
      }
    } else {
      final address = _addressCtrl.text.trim();
      if (address.isEmpty) {
        setState(() => _addressError = translate('err_address_empty'));
        hasError = true;
      }
      if (_pinnedLocationString.isEmpty) {
        setState(() => _mapError = translate('err_home_map_empty'));
        hasError = true;
      }
    }

    if (hasError) return;

    setState(() => _isUploading = true);

    try {
      final extraData = <String, dynamic>{};
      final mockUid = "google_${widget.email.replaceAll('@', '_').replaceAll('.', '_')}";

      if (_activeRole == 'customer') {
        extraData['address'] = _addressCtrl.text.trim();
        extraData['latitude'] = _selectedLatLng.latitude;
        extraData['longitude'] = _selectedLatLng.longitude;
      } else {
        // Upload CNIC to Storage
        final cnicUrl = await _uploadCnic(mockUid);
        if (cnicUrl == null) {
          throw Exception("Failed to upload CNIC card proof. Please try again.");
        }
        extraData['cnic'] = _cnicCtrl.text.trim();
        extraData['cnic_url'] = cnicUrl;
        extraData['shop_address'] = _shopAddressCtrl.text.trim();
        extraData['category'] = _selectedTrade!.toLowerCase();
        extraData['experience'] = _experienceCtrl.text.trim();
        extraData['latitude'] = _selectedLatLng.latitude;
        extraData['longitude'] = _selectedLatLng.longitude;
      }

      await ref.read(authProvider.notifier).completeGoogleSignup(
        email: widget.email,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _activeRole,
        extraData: extraData,
      );

      if (mounted) {
        if (_activeRole == 'provider') {
          context.go('/provider_dashboard');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _goToCurrentLocation() async {
    final location = loc.Location();
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;
    loc.LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    locationData = await location.getLocation();
    if (locationData.latitude != null && locationData.longitude != null) {
      final newLatLng = LatLng(locationData.latitude!, locationData.longitude!);
      _expandedMapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 18.0));
      setState(() {
        _selectedLatLng = newLatLng;
        _pinnedLocationString = "${newLatLng.latitude.toStringAsFixed(4)}, ${newLatLng.longitude.toStringAsFixed(4)}";
        _mapError = null;
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    const String apiKey = "AIzaSyBIGjvzRpCVZRtWgmbHIVn3OHecXZhYJRI";
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() => _searchResults = data['results']);
        } else {
          setState(() => _searchResults = []);
        }
      }
    } catch (e) {
      debugPrint("Geocoding search failed: $e");
    }
  }

  void _onResultTap(dynamic result) {
    final locData = result['geometry']['location'];
    final newLatLng = LatLng(locData['lat'], locData['lng']);
    _expandedMapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 18.0));
    setState(() {
      _searchResults = [];
      _searchCtrl.clear();
      _selectedLatLng = newLatLng;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final translate = ref.read(localeProvider.notifier).translate;
    
    // Premium theme tokens
    final backgroundColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF161B2E) : Colors.white;
    final primaryAccent = isDark ? const Color(0xFFBDB2FF) : const Color(0xFF4F46E5);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF6B7280) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0A0F1D).withOpacity(0.5) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(textPrimary),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGoogleBadge(surfaceColor, borderCol, textSecondary, textPrimary),
                          const SizedBox(height: 24),
                          
                          // Segmented Role Toggle (only show if role is ambiguous)
                          if (_lockedRole == null) ...[
                            Text(
                              translate('choose_role').toUpperCase(),
                              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 12),
                            _buildRoleToggle(surfaceColor, primaryAccent, textSecondary, isDark),
                            const SizedBox(height: 24),
                          ],

                          Text(
                            translate('personal_details').toUpperCase(),
                            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _nameCtrl,
                            hint: translate('full_name'),
                            icon: Icons.person_outline,
                            textPrimary: textPrimary,
                            borderCol: borderCol,
                            inputBg: inputBg,
                            errorText: _nameError,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _phoneCtrl,
                            hint: translate('mobile_number_hint'),
                            icon: Icons.phone_android_outlined,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textPrimary: textPrimary,
                            borderCol: borderCol,
                            inputBg: inputBg,
                            errorText: _phoneError,
                          ),
                          const SizedBox(height: 24),

                          // Dynamic Screen Sections depending on current role
                          if (_activeRole == 'customer') ...[
                            Text(
                              translate('home_address_map_pin').toUpperCase(),
                              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _addressCtrl,
                              hint: translate('home_address_hint'),
                              icon: Icons.home_outlined,
                              textPrimary: textPrimary,
                              borderCol: borderCol,
                              inputBg: inputBg,
                              errorText: _addressError,
                            ),
                            const SizedBox(height: 16),
                            _buildLocationOptions(surfaceColor, borderCol, primaryAccent, textPrimary, textSecondary, backgroundColor),
                          ] else ...[
                            Text(
                              translate('professional_details').toUpperCase(),
                              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _cnicCtrl,
                              hint: translate('cnic_number_hint'),
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                              maxLength: 13,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textPrimary: textPrimary,
                              borderCol: borderCol,
                              inputBg: inputBg,
                              errorText: _cnicError,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _shopAddressCtrl,
                              hint: translate('shop_address_hint'),
                              icon: Icons.storefront_outlined,
                              textPrimary: textPrimary,
                              borderCol: borderCol,
                              inputBg: inputBg,
                              errorText: _shopAddressError,
                            ),
                            const SizedBox(height: 16),
                            _buildTradeDropdown(borderCol, textSecondary, surfaceColor, textPrimary),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _experienceCtrl,
                              hint: translate('experience_years_hint'),
                              icon: Icons.history_outlined,
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textPrimary: textPrimary,
                              borderCol: borderCol,
                              inputBg: inputBg,
                              errorText: _experienceError,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              translate('cnic_identity_card_proof').toUpperCase(),
                              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 12),
                            _buildCnicFilePicker(surfaceColor, borderCol, primaryAccent, textPrimary, textSecondary),
                            const SizedBox(height: 24),
                            Text(
                              translate('shop_map_location').toUpperCase(),
                              style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 12),
                            _buildLocationOptions(surfaceColor, borderCol, primaryAccent, textPrimary, textSecondary, backgroundColor),
                          ],

                          const SizedBox(height: 40),
                          _buildSubmitButton(primaryAccent, isDark),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isMapExpanded) _buildExpandedMap(backgroundColor, surfaceColor, borderCol, textSecondary, textPrimary, primaryAccent),
          if (_isUploading) _buildLoadingOverlay(primaryAccent),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.arrow_back),
            color: textPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            'Complete Your Profile',
            style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleBadge(Color surfaceColor, Color borderCol, Color textSecondary, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Image.network(
            'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
            height: 28,
            errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in with Google', style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(widget.email, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRoleToggle(Color surfaceColor, Color primaryAccent, Color textSecondary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildToggleButton('Customer', _activeRole == 'customer', primaryAccent, textSecondary, isDark, () {
            setState(() => _activeRole = 'customer');
          }),
          _buildToggleButton('Service Provider', _activeRole == 'provider', primaryAccent, textSecondary, isDark, () {
            setState(() => _activeRole = 'provider');
          }),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, Color primaryAccent, Color textSecondary, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected 
                  ? (isDark ? const Color(0xFF0A0F1D) : Colors.white) 
                  : textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    required Color textPrimary,
    required Color borderCol,
    required Color inputBg,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: errorText != null ? Colors.red : borderCol),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: TextStyle(color: textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTradeDropdown(Color borderCol, Color textSecondary, Color surfaceColor, Color textPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _tradeError != null ? Colors.red : borderCol),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTrade,
              hint: Text('Select Trade Category', style: TextStyle(color: textSecondary, fontSize: 14)),
              isExpanded: true,
              dropdownColor: surfaceColor,
              icon: Icon(Icons.keyboard_arrow_down, color: textSecondary),
              items: _trades.map((String trade) {
                return DropdownMenuItem<String>(
                  value: trade,
                  child: Text(trade, style: TextStyle(color: textPrimary, fontSize: 14)),
                );
              }).toList(),
              onChanged: (String? newValue) => setState(() {
                _selectedTrade = newValue;
                _tradeError = null;
              }),
            ),
          ),
        ),
        if (_tradeError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _tradeError!,
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCnicFilePicker(Color surfaceColor, Color borderCol, Color primaryAccent, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickCnicFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: surfaceColor, 
              borderRadius: BorderRadius.circular(14), 
              border: Border.all(color: _cnicFileError != null ? Colors.red : borderCol),
            ),
            child: Column(
              children: [
                Icon(
                  _cnicFile == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline,
                  color: _cnicFileError != null ? Colors.red : primaryAccent,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  _cnicFileName ?? 'Upload CNIC Identity Card Image', 
                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text('Supports PNG, JPG, or JPEG proofs', style: TextStyle(color: textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (_cnicFileError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _cnicFileError!,
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationOptions(
    Color surfaceColor, 
    Color borderCol, 
    Color primaryAccent, 
    Color textPrimary, 
    Color textSecondary,
    Color backgroundColor,
  ) {
    final translate = ref.read(localeProvider.notifier).translate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _goToCurrentLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_outlined, color: primaryAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  _activeRole == 'customer' 
                      ? translate('use_current_location') 
                      : translate('use_current_shop_location'), 
                  style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() {
            _isMapExpanded = true;
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border.all(color: _mapError != null ? Colors.red : borderCol),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: _selectedLatLng, zoom: 14),
                    liteModeEnabled: true,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    markers: {
                      Marker(markerId: const MarkerId('pinned'), position: _selectedLatLng),
                    },
                  ),
                  IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                      child: Container(color: Colors.black.withOpacity(0.08)),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: backgroundColor.withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: _mapError != null ? Colors.red : primaryAccent.withOpacity(0.3)),
                        ),
                        child: Icon(
                          _activeRole == 'customer' ? Icons.location_on : Icons.store,
                          color: _mapError != null ? Colors.red : primaryAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: backgroundColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _pinnedLocationString.isEmpty 
                              ? (_activeRole == 'customer' ? translate('tap_to_pin_home') : translate('tap_to_pin_shop'))
                              : '${_activeRole == 'customer' ? translate('location_pinned_label') : translate('shop_pinned_label')}$_pinnedLocationString', 
                          style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_mapError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _mapError!,
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandedMap(
    Color backgroundColor,
    Color surfaceColor,
    Color borderCol,
    Color textSecondary,
    Color textPrimary,
    Color primaryAccent,
  ) {
    return Positioned.fill(
      child: Container(
        color: backgroundColor,
        child: Column(
          children: [
            AppBar(
              backgroundColor: surfaceColor,
              elevation: 0,
              title: Text(_activeRole == 'customer' ? 'Pin Home Location' : 'Pin Shop Location', style: TextStyle(color: textPrimary, fontSize: 18)),
              iconTheme: IconThemeData(color: textPrimary),
              leading: IconButton(
                icon: const Icon(Icons.close), 
                onPressed: () => setState(() {
                  _isMapExpanded = false;
                  _searchResults = [];
                  _searchCtrl.clear();
                })
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: _selectedLatLng, zoom: 16),
                    onMapCreated: (controller) => _expandedMapController = controller,
                    onCameraMove: (position) {
                      _selectedLatLng = position.target;
                    },
                    onCameraIdle: () {
                      setState(() {
                        _pinnedLocationString = "${_selectedLatLng.latitude.toStringAsFixed(4)}, ${_selectedLatLng.longitude.toStringAsFixed(4)}";
                      });
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                  ),
                  IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 35),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: primaryAccent, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              "Pin here", 
                              style: TextStyle(
                                color: ref.read(localeProvider).isDarkMode ? const Color(0xFF0A0F1D) : Colors.white,
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(Icons.location_on, color: primaryAccent, size: 45),
                        ],
                      ),
                    ),
                  ),
                  // Search Bar Overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor, 
                            borderRadius: BorderRadius.circular(14), 
                            border: Border.all(color: borderCol),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(color: textPrimary),
                            textInputAction: TextInputAction.search,
                            onChanged: (val) {
                              if (val.length > 2) _searchLocation(val);
                              if (val.isEmpty) setState(() => _searchResults = []);
                            },
                            onSubmitted: _searchLocation,
                            decoration: InputDecoration(
                              hintText: 'Search home/shop area...',
                              hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                              prefixIcon: Icon(Icons.search, color: textSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(color: borderCol, height: 1),
                              itemBuilder: (context, index) {
                                final res = _searchResults[index];
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.location_on, color: textSecondary, size: 18),
                                    title: Text(res['formatted_address'], style: TextStyle(color: textPrimary, fontSize: 13)),
                                    onTap: () => _onResultTap(res),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  // GPS Position Button
                  Positioned(
                    bottom: 110,
                    right: 20,
                    child: GestureDetector(
                      onTap: _goToCurrentLocation,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol)),
                        child: Icon(Icons.gps_fixed, color: primaryAccent, size: 24),
                      ),
                    ),
                  ),
                  // Confirm Location Pin Button
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isMapExpanded = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccent, 
                        foregroundColor: ref.read(localeProvider).isDarkMode ? const Color(0xFF0A0F1D) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Confirm Location Pin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryAccent, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: isDark ? const Color(0xFF0A0F1D) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          'Complete My Registration',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(Color primaryAccent) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.65),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: const Color(0xFF161B2E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2E344A)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryAccent),
                const SizedBox(height: 24),
                const Text(
                  'Finalizing Account...',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uploading CNIC proofs and registering in cloud Firestore...',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
