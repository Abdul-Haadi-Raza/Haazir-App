import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/dialog_helper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  String? _phoneError;
  String? _pinError;

  Color _kBackgroundColor = const Color(0xFF0A0F1D);
  Color _kSurfaceColor = const Color(0xFF161B2E);
  Color _kPrimaryPurple = const Color(0xFFBDB2FF);
  Color _kInputBorderColor = const Color(0xFF2E344A);
  Color _kHintTextColor = const Color(0xFF6B7280);
  Color _textColor = Colors.white;
  Color _textSecColor = Colors.white70;

  void _login() async {
    final phone = _phoneCtrl.text.trim();
    final pin = _pinControllers.map((e) => e.text).join();
    final translate = ref.read(localeProvider.notifier).translate;

    setState(() {
      _phoneError = null;
      _pinError = null;
    });

    bool hasError = false;

    if (phone.isEmpty) {
      setState(() {
        _phoneError = translate('number_tou_enter_kro');
      });
      hasError = true;
    } else if (phone.length != 11 || !RegExp(r'^\d+$').hasMatch(phone)) {
      setState(() {
        _phoneError = translate('err_phone_length');
      });
      hasError = true;
    }

    if (pin.isEmpty) {
      setState(() {
        _pinError = translate('pin_tou_enter_kro');
      });
      hasError = true;
    } else if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() {
        _pinError = translate('err_pin_length');
      });
      hasError = true;
    }

    if (hasError) return;

    try {
      await ref.read(authProvider.notifier).login(phone, pin);
    } catch (e) {
      if (mounted) {
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

    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: _kBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildWelcomeText(),
              const SizedBox(height: 48),
              _buildLoginCard(isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    final translate = ref.read(localeProvider.notifier).translate;
    return Column(
      children: [
        const Icon(Icons.handshake, size: 64, color: Colors.blue),
        const SizedBox(height: 12),
        Text(
          'HAAZIR',
          style: TextStyle(color: _textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4),
        ),
        const SizedBox(height: 40),
        Text(translate('welcome'), style: TextStyle(color: _textColor, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(translate('login_msg'), style: TextStyle(color: _textSecColor, fontSize: 16)),
      ],
    );
  }

  Widget _buildLoginCard(bool isLoading) {
    final translate = ref.read(localeProvider.notifier).translate;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kSurfaceColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kInputBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate('mobile_number'), style: TextStyle(color: _kHintTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildPhoneField(),
              if (_phoneError != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(_phoneError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
              const SizedBox(height: 24),
              Text(translate('four_digit_pin'), style: TextStyle(color: _kHintTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildPinSection(),
              if (_pinError != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(_pinError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
              const SizedBox(height: 32),
              _buildSignInButton(isLoading),
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 24),
              _buildGoogleButton(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => context.push('/signup'),
          child: Text.rich(
            TextSpan(
              text: translate('new_here'),
              style: TextStyle(color: _textSecColor),
              children: [
                TextSpan(text: translate('sign_up'), style: TextStyle(color: _kPrimaryPurple, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: _kBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _phoneError != null ? Colors.red : _kInputBorderColor),
      ),
      child: TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        maxLength: 11,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(color: _textColor),
        decoration: InputDecoration(
          hintText: '03001234567',
          hintStyle: TextStyle(color: _kHintTextColor),
          counterText: '',
          prefixIcon: Icon(Icons.phone_android_outlined, color: _kHintTextColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPinSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) => _buildPinBox(index)),
    );
  }

  Widget _buildPinBox(int index) {
    return SizedBox(
      width: 50,
      height: 50,
      child: GestureDetector(
        onTapDown: (_) {
          int firstEmpty = -1;
          for (int i = 0; i < 4; i++) {
            if (_pinControllers[i].text.isEmpty) { firstEmpty = i; break; }
          }
          _pinFocusNodes[firstEmpty != -1 && firstEmpty < index ? firstEmpty : index].requestFocus();
        },
        child: AbsorbPointer(
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _pinFocusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '●',
            style: TextStyle(color: _textColor, fontSize: 18),
            decoration: InputDecoration(
              counterText: '',
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _pinError != null ? Colors.red : _kInputBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _pinError != null ? Colors.red : _kPrimaryPurple),
              ),
              fillColor: _kBackgroundColor.withOpacity(0.5),
              filled: true,
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 3) {
                _pinFocusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _pinFocusNodes[index - 1].requestFocus();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(bool isLoading) {
    final translate = ref.read(localeProvider.notifier).translate;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _login,
        style: ElevatedButton.styleFrom(backgroundColor: _kPrimaryPurple, foregroundColor: _kBackgroundColor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: isLoading 
          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: _kBackgroundColor, strokeWidth: 2))
          : Text(translate('sign_in'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          final result = await notifier.signInWithGoogle(context);
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
