import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/dialog_helper.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> signupData;

  const OtpScreen({super.key, required this.signupData});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _otpCtrl = TextEditingController();
  
  Color _kBackgroundColor = const Color(0xFF0A0F1D);
  Color _kSurfaceColor = const Color(0xFF161B2E);
  Color _kPrimaryPurple = const Color(0xFFBDB2FF);
  Color _kInputBorderColor = const Color(0xFF2E344A);
  Color _textColor = Colors.white;
  Color _textSecColor = Colors.white70;

  void _verifyOtp() async {
    if (_otpCtrl.text.length < 6) return;

    try {
      await ref.read(authProvider.notifier).verifyOTPAndComplete(
        smsCode: _otpCtrl.text.trim(),
        name: widget.signupData['name'] ?? '',
        phone: widget.signupData['phone'] ?? '',
        role: widget.signupData['role'] ?? 'customer',
        extraData: widget.signupData['extraData'],
      );
      
      if (mounted) {
        final user = ref.read(authProvider).user;
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
    _textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    _textSecColor = isDark ? Colors.white70 : const Color(0xFF4B5563);

    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 80, color: _kPrimaryPurple),
              const SizedBox(height: 32),
              Text(
                'Verification Code',
                style: TextStyle(color: _textColor, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code sent to\n${widget.signupData['phone']}',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecColor, fontSize: 16),
              ),
              const SizedBox(height: 48),
              
              // Standard Flutter TextField as fallback for problematic PinCodeTextField
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: _kSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kInputBorderColor),
                ),
                child: TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor, 
                    fontSize: 32, 
                    letterSpacing: 20, 
                    fontWeight: FontWeight.bold
                  ),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "000000",
                    hintStyle: TextStyle(color: _textColor.withOpacity(0.2), letterSpacing: 20),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    if (v.length == 6) _verifyOtp();
                  },
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryPurple,
                    foregroundColor: _kBackgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading 
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: _kBackgroundColor, strokeWidth: 2),
                      )
                    : const Text('Verify & Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('Change Phone Number', style: TextStyle(color: _kPrimaryPurple)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
