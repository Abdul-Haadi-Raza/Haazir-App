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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/dialog_helper.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Common Fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];

  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());
  
  final List<TextEditingController> _confirmPinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _confirmPinFocusNodes = List.generate(4, (_) => FocusNode());
  
  String _role = 'customer';

  // Customer Fields
  final _addressCtrl = TextEditingController();
  String _pinnedLocation = "";
  bool _isMapExpanded = false;
  LatLng _selectedLatLng = const LatLng(33.6844, 73.0479);
  
  // Provider Fields
  String _shopPinnedLocation = "";
  LatLng _shopLatLng = const LatLng(33.6844, 73.0479);
  
  String _activePinTarget = "customer"; // 'customer' or 'provider'

  GoogleMapController? _expandedMapController;

  // Provider Fields
  final _cnicCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  String? _selectedTrade;
  File? _cnicFile;
  String? _cnicFileName;
  bool _isUploading = false;
  
  final List<String> _trades = [
    'Plumber',
    'Electrician',
    'AC Technician',
    'Carpenter',
    'Painter'
  ];

  // Inline Validation Error Messages
  String? _nameError;
  String? _phoneError;
  String? _addressError;
  String? _cnicError;
  String? _shopAddressError;
  String? _tradeError;
  String? _experienceError;
  String? _cnicFileError;
  String? _mapError;
  String? _pinError;
  String? _confirmPinError;

  // Colors
  Color _kBackgroundColor = const Color(0xFF0A0F1D);
  Color _kSurfaceColor = const Color(0xFF161B2E);
  Color _kPrimaryPurple = const Color(0xFFBDB2FF);
  Color _kInputBorderColor = const Color(0xFF2E344A);
  Color _kHintTextColor = const Color(0xFF6B7280);
  Color _textColor = Colors.white;
  Color _textSecColor = Colors.white70;

  Future<void> _pickCnicFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _cnicFile = File(result.files.single.path!);
        _cnicFileName = result.files.single.name;
        _cnicFileError = null; // Clear error
      });
    }
  }

  Future<String?> _uploadCnic(String uid) async {
    if (_cnicFile == null) return null;
    
    try {
      final ext = _cnicFileName?.split('.').last ?? 'file';
      final ref = FirebaseStorage.instance.ref().child('cnics/$uid.$ext');
      final uploadTask = await ref.putFile(_cnicFile!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  void _onSignupClick() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pin = _pinControllers.map((e) => e.text).join();
    final confirmPin = _confirmPinControllers.map((e) => e.text).join();
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
      _pinError = null;
      _confirmPinError = null;
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

    if (_role == 'provider') {
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

      if (_shopPinnedLocation.isEmpty) {
        setState(() => _mapError = translate('err_shop_map_empty'));
        hasError = true;
      }
    } else {
      final address = _addressCtrl.text.trim();
      if (address.isEmpty) {
        setState(() => _addressError = translate('err_address_empty'));
        hasError = true;
      }
      if (_pinnedLocation.isEmpty) {
        setState(() => _mapError = translate('err_home_map_empty'));
        hasError = true;
      }
    }

    if (pin.isEmpty) {
      setState(() => _pinError = translate('err_pin_empty'));
      hasError = true;
    } else if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _pinError = translate('err_pin_length'));
      hasError = true;
    }

    if (confirmPin.isEmpty) {
      setState(() => _confirmPinError = translate('err_confirm_pin_empty'));
      hasError = true;
    } else if (pin != confirmPin) {
      setState(() => _confirmPinError = translate('err_pin_mismatch'));
      hasError = true;
    }

    if (hasError) return;

    try {
      final extraData = <String, dynamic>{};
      if (_role == 'customer') {
        extraData['address'] = _addressCtrl.text.trim();
        extraData['latitude'] = _selectedLatLng.latitude;
        extraData['longitude'] = _selectedLatLng.longitude;
      } else {
        extraData['cnic'] = _cnicCtrl.text.trim();
        extraData['shop_address'] = _shopAddressCtrl.text.trim();
        extraData['experience'] = _experienceCtrl.text.trim();
        extraData['category'] = _selectedTrade?.toLowerCase() ?? 'general';
        extraData['latitude'] = _shopLatLng.latitude;
        extraData['longitude'] = _shopLatLng.longitude;
      }

      // Signup will handle user creation and firestore entry
      await ref.read(authProvider.notifier).signup(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        pin: pin,
        role: _role,
        extraData: extraData,
      );

      final user = ref.read(authProvider).user;
      if (user != null && _role == 'provider' && _cnicFile != null) {
        setState(() => _isUploading = true);
        String? cnicUrl = await _uploadCnic(user.id);
        if (cnicUrl != null) {
          // Update both collections with the CNIC URL
          await FirebaseFirestore.instance.collection('Users').doc(user.id).update({'cnic_url': cnicUrl});
          await FirebaseFirestore.instance.collection('ProviderProfiles').doc(user.id).update({'cnic_url': cnicUrl});
        }
        setState(() => _isUploading = false);
      }
      
      if (mounted) {
        if (user?.role == 'provider') {
          context.go('/provider_dashboard');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        final translate = ref.read(localeProvider.notifier).translate;
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring('Exception: '.length);
        }
        DialogHelper.showError(
          context: context,
          title: translate('error_title'),
          message: translate(errorMsg),
          buttonText: translate('ok'),
          isDark: ref.read(localeProvider).isDarkMode,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    _kBackgroundColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF9FAFB);
    _kSurfaceColor = isDark ? const Color(0xFF161B2E) : Colors.white;
    _kPrimaryPurple = isDark ? const Color(0xFFBDB2FF) : const Color(0xFF6366F1);
    _kInputBorderColor = isDark ? const Color(0xFF2E344A) : const Color(0xFFE5E7EB);
    _kHintTextColor = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    _textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    _textSecColor = isDark ? Colors.white70 : const Color(0xFF4B5563);

    final isLoading = ref.watch(authProvider).isLoading || _isUploading;
    final translate = ref.read(localeProvider.notifier).translate;

    return Scaffold(
      backgroundColor: _kBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRoleToggle(),
                          const SizedBox(height: 32),
                          
                          _buildTextField(
                            controller: _nameCtrl, 
                            hint: translate('full_name'), 
                            icon: Icons.person_outline,
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
                            errorText: _phoneError,
                          ),
                          const SizedBox(height: 16),

                          if (_role == 'customer') ...[
                            _buildTextField(
                              controller: _addressCtrl, 
                              hint: translate('home_address_hint'), 
                              icon: Icons.home_outlined,
                              errorText: _addressError,
                            ),
                            const SizedBox(height: 16),
                            _buildLocationOptions(),
                          ] else ...[
                            _buildTextField(
                              controller: _cnicCtrl, 
                              hint: translate('cnic_number_hint'), 
                              icon: Icons.badge_outlined, 
                              keyboardType: TextInputType.number, 
                              maxLength: 13, 
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              errorText: _cnicError,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _shopAddressCtrl, 
                              hint: translate('shop_address_hint'), 
                              icon: Icons.storefront_outlined,
                              errorText: _shopAddressError,
                            ),
                            const SizedBox(height: 16),
                            _buildProviderLocationOptions(),
                            const SizedBox(height: 16),
                            _buildTradeDropdown(),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _experienceCtrl, 
                              hint: translate('experience_years_hint'), 
                              icon: Icons.history_outlined, 
                              keyboardType: TextInputType.number, 
                              maxLength: 2, 
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              errorText: _experienceError,
                            ),
                            const SizedBox(height: 16),
                            _buildCnicFilePicker(),
                          ],

                          const SizedBox(height: 32),
                          _buildPinSection(translate('set_security_pin'), _pinControllers, _pinFocusNodes, errorText: _pinError),
                          const SizedBox(height: 24),
                          _buildPinSection(translate('confirm_security_pin'), _confirmPinControllers, _confirmPinFocusNodes, errorText: _confirmPinError),
                          
                          const SizedBox(height: 40),
                          _buildCreateAccountButton(isLoading),
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(translate('already_have_account'), style: TextStyle(color: _kHintTextColor, fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildDivider(),
                          const SizedBox(height: 24),
                          _buildGoogleButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isMapExpanded) _buildExpandedMap(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _kSurfaceColor, shape: BoxShape.circle),
              child: Icon(Icons.arrow_back, color: _textColor, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Text(translate('create_account'), style: TextStyle(color: _textColor, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRoleToggle() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _kSurfaceColor, borderRadius: BorderRadius.circular(32)),
      child: Row(
        children: [
          _buildToggleButton(translate('customer'), _role == 'customer', () => setState(() => _role = 'customer')),
          _buildToggleButton(translate('provider'), _role == 'provider', () => setState(() => _role = 'provider')),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? _kPrimaryPurple : Colors.transparent, borderRadius: BorderRadius.circular(28)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? (ref.watch(localeProvider).isDarkMode ? _kBackgroundColor : Colors.white) : _kHintTextColor, fontWeight: FontWeight.w600)),
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
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: errorText != null ? Colors.red : _kInputBorderColor)
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _kHintTextColor),
              prefixIcon: Icon(icon, color: _kHintTextColor),
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
            child: Text(errorText, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
  }

  Widget _buildTradeDropdown() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: _tradeError != null ? Colors.red : _kInputBorderColor)
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTrade,
              hint: Text(translate('select_trade'), style: TextStyle(color: _kHintTextColor)),
              isExpanded: true,
              dropdownColor: _kSurfaceColor,
              icon: Icon(Icons.keyboard_arrow_down, color: _kHintTextColor),
              items: _trades.map((String trade) => DropdownMenuItem<String>(value: trade, child: Text(trade, style: TextStyle(color: _textColor)))).toList(),
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
            child: Text(_tradeError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
  }

  Widget _buildCnicFilePicker() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickCnicFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: _kSurfaceColor.withOpacity(0.5), 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: _cnicFileError != null ? Colors.red : _kInputBorderColor)
            ),
            child: Column(
              children: [
                Icon(_cnicFile == null ? Icons.add_a_photo_outlined : Icons.check_circle_outline, color: _cnicFileError != null ? Colors.red : _kPrimaryPurple, size: 32),
                const SizedBox(height: 12),
                Text(
                  _cnicFileName ?? translate('upload_cnic_prompt'), 
                  style: TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(translate('click_to_scan'), style: TextStyle(color: _kHintTextColor, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (_cnicFileError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(_cnicFileError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationOptions() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            _activePinTarget = 'customer';
            _goToCurrentLocation();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: _kSurfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _kInputBorderColor)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_outlined, color: _kPrimaryPurple, size: 18),
                const SizedBox(width: 8),
                Text(translate('use_current_location'), style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() {
            _activePinTarget = 'customer';
            _isMapExpanded = true;
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: _kSurfaceColor.withOpacity(0.5), 
                border: Border.all(color: _mapError != null ? Colors.red : _kInputBorderColor)
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
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(color: Colors.black.withOpacity(0.1)),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _kBackgroundColor.withOpacity(0.7), shape: BoxShape.circle, border: Border.all(color: _mapError != null ? Colors.red : _kPrimaryPurple.withOpacity(0.3))),
                        child: Icon(Icons.location_on, color: _mapError != null ? Colors.red : _kPrimaryPurple, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _kBackgroundColor.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                        child: Text(_pinnedLocation.isEmpty ? translate('tap_to_pin_home') : '${translate('location_pinned_label')}$_pinnedLocation', style: TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.w500)),
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
            child: Text(_mapError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
  }

  Widget _buildProviderLocationOptions() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            _activePinTarget = 'provider';
            _goToCurrentLocation();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: _kSurfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _kInputBorderColor)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_outlined, color: _kPrimaryPurple, size: 18),
                const SizedBox(width: 8),
                Text(translate('use_current_shop_location'), style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() {
            _activePinTarget = 'provider';
            _isMapExpanded = true;
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: _kSurfaceColor.withOpacity(0.5), 
                border: Border.all(color: _mapError != null ? Colors.red : _kInputBorderColor)
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: _shopLatLng, zoom: 14),
                    liteModeEnabled: true,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    markers: {
                      Marker(markerId: const MarkerId('pinned_shop'), position: _shopLatLng),
                    },
                  ),
                  IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(color: Colors.black.withOpacity(0.1)),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _kBackgroundColor.withOpacity(0.7), shape: BoxShape.circle, border: Border.all(color: _mapError != null ? Colors.red : _kPrimaryPurple.withOpacity(0.3))),
                        child: Icon(Icons.store, color: _mapError != null ? Colors.red : _kPrimaryPurple, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _kBackgroundColor.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                        child: Text(_shopPinnedLocation.isEmpty ? translate('tap_to_pin_shop') : '${translate('shop_pinned_label')}$_shopPinnedLocation', style: TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.w500)),
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
            child: Text(_mapError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
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
        _mapError = null; // Clear error
        if (_activePinTarget == 'customer') {
          _selectedLatLng = newLatLng;
          _pinnedLocation = "${_selectedLatLng.latitude.toStringAsFixed(4)}, ${_selectedLatLng.longitude.toStringAsFixed(4)}";
        } else {
          _shopLatLng = newLatLng;
          _shopPinnedLocation = "${_shopLatLng.latitude.toStringAsFixed(4)}, ${_shopLatLng.longitude.toStringAsFixed(4)}";
        }
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
      debugPrint("Search error: $e");
    }
  }

  void _onResultTap(dynamic result) {
    final locData = result['geometry']['location'];
    final newLatLng = LatLng(locData['lat'], locData['lng']);
    _expandedMapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 18.0));
    
    setState(() {
      _searchResults = [];
      _searchCtrl.clear();
      _mapError = null; // Clear error
      if (_activePinTarget == 'customer') {
        _selectedLatLng = newLatLng;
        _pinnedLocation = "${_selectedLatLng.latitude.toStringAsFixed(4)}, ${_selectedLatLng.longitude.toStringAsFixed(4)}";
      } else {
        _shopLatLng = newLatLng;
        _shopPinnedLocation = "${_shopLatLng.latitude.toStringAsFixed(4)}, ${_shopLatLng.longitude.toStringAsFixed(4)}";
      }
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildExpandedMap() {
    LatLng initialTarget = _activePinTarget == 'customer' ? _selectedLatLng : _shopLatLng;
    final translate = ref.read(localeProvider.notifier).translate;
    
    return Positioned.fill(
      child: Container(
        color: _kBackgroundColor,
        child: Column(
          children: [
            AppBar(
              backgroundColor: _kSurfaceColor,
              elevation: 0,
              title: Text(_activePinTarget == 'customer' ? translate('pin_home_title') : translate('pin_shop_title'), style: const TextStyle(color: Colors.white, fontSize: 18)),
              iconTheme: const IconThemeData(color: Colors.white),
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
                    initialCameraPosition: CameraPosition(target: initialTarget, zoom: 16),
                    onMapCreated: (controller) => _expandedMapController = controller,
                    onCameraMove: (position) {
                      if (_activePinTarget == 'customer') {
                        _selectedLatLng = position.target;
                      } else {
                        _shopLatLng = position.target;
                      }
                    },
                    onCameraIdle: () {
                      setState(() {
                        _mapError = null; // Clear error
                        if (_activePinTarget == 'customer') {
                          _pinnedLocation = "${_selectedLatLng.latitude.toStringAsFixed(4)}, ${_selectedLatLng.longitude.toStringAsFixed(4)}";
                        } else {
                          _shopPinnedLocation = "${_shopLatLng.latitude.toStringAsFixed(4)}, ${_shopLatLng.longitude.toStringAsFixed(4)}";
                        }
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
                            decoration: BoxDecoration(color: _kPrimaryPurple, borderRadius: BorderRadius.circular(20)),
                            child: Text(translate('pin_here'), style: TextStyle(color: _kBackgroundColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Icon(Icons.location_on, color: _kPrimaryPurple, size: 45),
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
                            color: _kSurfaceColor, 
                            borderRadius: BorderRadius.circular(12), 
                            border: Border.all(color: _kInputBorderColor),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.search,
                            onChanged: (val) {
                              if (val.length > 2) _searchLocation(val);
                              if (val.isEmpty) setState(() => _searchResults = []);
                            },
                            onSubmitted: _searchLocation,
                            decoration: InputDecoration(
                              hintText: translate('search_area'),
                              hintStyle: TextStyle(color: _kHintTextColor, fontSize: 14),
                              prefixIcon: Icon(Icons.search, color: _kHintTextColor),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(color: _kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kInputBorderColor)),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(color: _kInputBorderColor, height: 1),
                              itemBuilder: (context, index) {
                                final res = _searchResults[index];
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.location_on, color: _kHintTextColor, size: 18),
                                    title: Text(res['formatted_address'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    onTap: () => _onResultTap(res),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  // GPS Button
                  Positioned(
                    bottom: 110,
                    right: 20,
                    child: GestureDetector(
                      onTap: _goToCurrentLocation,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: _kSurfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kInputBorderColor)),
                        child: Icon(Icons.gps_fixed, color: _kPrimaryPurple, size: 24),
                      ),
                    ),
                  ),
                  // Confirm Button
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isMapExpanded = false),
                      style: ElevatedButton.styleFrom(backgroundColor: _kPrimaryPurple, foregroundColor: _kBackgroundColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(translate('confirm_location'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildPinSection(String title, List<TextEditingController> controllers, List<FocusNode> nodes, {String? errorText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) => _buildPinBox(index, controllers, nodes, errorText: errorText)),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(errorText, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ],
    );
  }

  Widget _buildPinBox(int index, List<TextEditingController> controllers, List<FocusNode> nodes, {String? errorText}) {
    return SizedBox(
      width: 60,
      height: 60,
      child: GestureDetector(
        onTapDown: (_) {
          int firstEmpty = -1;
          for (int i = 0; i < 4; i++) {
            if (controllers[i].text.isEmpty) { firstEmpty = i; break; }
          }
          nodes[firstEmpty != -1 && firstEmpty < index ? firstEmpty : index].requestFocus();
        },
        child: AbsorbPointer(
          child: TextField(
            controller: controllers[index],
            focusNode: nodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '●',
            style: TextStyle(color: _textColor, fontSize: 24),
            decoration: InputDecoration(
              counterText: '',
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), 
                borderSide: BorderSide(color: errorText != null ? Colors.red : _kInputBorderColor)
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), 
                borderSide: BorderSide(color: errorText != null ? Colors.red : _kPrimaryPurple)
              ),
              fillColor: _kSurfaceColor,
              filled: true,
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 3) {
                nodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                nodes[index - 1].requestFocus();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAccountButton(bool isLoading) {
    final translate = ref.read(localeProvider.notifier).translate;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _onSignupClick,
        style: ElevatedButton.styleFrom(backgroundColor: _kPrimaryPurple, foregroundColor: _kBackgroundColor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        child: isLoading 
          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: _kBackgroundColor, strokeWidth: 2))
          : Text(translate('create_account'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDivider() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Row(
      children: [
        Expanded(child: Divider(color: _kInputBorderColor)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(translate('or'), style: TextStyle(color: _kHintTextColor, fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(child: Divider(color: _kInputBorderColor)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    final translate = ref.read(localeProvider.notifier).translate;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final notifier = ref.read(authProvider.notifier);
          final result = await notifier.signInWithGoogle(context, defaultRole: _role);
          if (result != null) {
            if (result.needsDetails) {
              if (mounted) {
                context.go('/google_details', extra: {
                  'email': result.email,
                  'name': result.name,
                  'role': result.role,
                });
              }
            } else {
              if (mounted) {
                if (result.role == 'provider') {
                  context.go('/provider_dashboard');
                } else {
                  context.go('/home');
                }
              }
            }
          }
        },
        style: OutlinedButton.styleFrom(side: BorderSide(color: _kInputBorderColor), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network('https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png', height: 20, errorBuilder: (_,__,___) => Icon(Icons.account_circle, color: _textColor, size: 20)),
            const SizedBox(width: 12),
            Text(translate('continue_google'), style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
