import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:avatar_glow/avatar_glow.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/locale_provider.dart';
import '../providers/booking_provider.dart';

class ProviderJobDiagnosisScreen extends ConsumerStatefulWidget {
  const ProviderJobDiagnosisScreen({super.key});

  @override
  ConsumerState<ProviderJobDiagnosisScreen> createState() => _ProviderJobDiagnosisScreenState();
}

class _ProviderJobDiagnosisScreenState extends ConsumerState<ProviderJobDiagnosisScreen> {
  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);
  static const Color _kDarkHintTextColor = Color(0xFF6B7280);
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _transcription = "Tap the mic and describe the issue (e.g. \"pipe is cracked near the joint leaking all over\"). The AI will parse details.";
  int _severity = 3;

  bool _isDiagnosing = false;
  List<String> _partsRecommended = [];
  int _partsCost = 0;
  int _additionalLabor = 0;
  int _updatedFare = 1500;
  int _originalFare = 1500;
  String _diagnosisSummaryEn = "";
  String _diagnosisSummaryUr = "";

  String _customerName = "Ahmad Raza";
  String _serviceCategory = "Plumbing";
  String _serviceType = "Leaky Sink";
  String _bookingId = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookingState = ref.read(bookingProvider);
      if (bookingState.result != null) {
        final booking = bookingState.result!.booking;
        setState(() {
          _bookingId = booking.bookingId;
          _customerName = booking.customerName;
          _serviceCategory = booking.serviceCategory;
          _serviceType = booking.serviceType;
          
          String priceStr = booking.priceEstimate.replaceAll(RegExp(r'[^0-9]'), '');
          if (priceStr.isNotEmpty) {
            _originalFare = int.tryParse(priceStr) ?? 1500;
            _updatedFare = _originalFare;
          }
        });
      }
    });
  }

  Future<void> _runAIDiagnosis(String text) async {
    if (text.isEmpty || text.startsWith("Tap the mic")) return;
    setState(() => _isDiagnosing = true);

    final urls = [
      'http://127.0.0.1:8000/diagnose',
      'http://10.0.2.2:8000/diagnose',
    ];

    Map<String, dynamic>? data;

    for (var urlStr in urls) {
      try {
        final response = await http.post(
          Uri.parse(urlStr),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transcription': text,
            'base_fare': _originalFare,
            'service_type': _serviceCategory,
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          if (data?['status'] == 'success') {
            break;
          }
        }
      } catch (e) {
        debugPrint("Failed to connect to $urlStr: $e");
      }
    }

    if (data != null && data['status'] == 'success') {
      setState(() {
        _severity = data!['severity'] ?? 3;
        _partsRecommended = List<String>.from(data['parts_recommended'] ?? []);
        _partsCost = data['parts_cost'] ?? 0;
        _additionalLabor = data['additional_labor'] ?? 0;
        _updatedFare = data['updated_fare'] ?? _originalFare;
        _diagnosisSummaryEn = data['summary_en'] ?? "";
        _diagnosisSummaryUr = data['summary_ur'] ?? "";
        _isDiagnosing = false;
      });
    } else {
      // Offline fallback parsing inside the App in case the backend server is not running
      int severity = 3;
      List<String> parts = [];
      int partsCost = 0;
      int labor = 300;

      final lowerText = text.toLowerCase();
      if (lowerText.contains("leak") || lowerText.contains("pipe") || lowerText.contains("sink") || lowerText.contains("toti")) {
        severity = 3;
        parts = ["PVC Pipe Joint", "Leak Sealant Tape"];
        partsCost = 650;
        labor = 500;
      } else if (lowerText.contains("compressor") || lowerText.contains("ac") || lowerText.contains("condenser") || lowerText.contains("cooling") || lowerText.contains("cool")) {
        severity = 5;
        parts = ["AC Compressor (Panasonic)", "R410a Gas Refill"];
        partsCost = 9500;
        labor = 2500;
      } else if (lowerText.contains("gas") || lowerText.contains("leakage") || lowerText.contains("gas leakage")) {
        severity = 4;
        parts = ["Freon Gas Recharging"];
        partsCost = 4500;
        labor = 1500;
      } else if (lowerText.contains("short") || lowerText.contains("wire") || lowerText.contains("spark") || lowerText.contains("switch")) {
        severity = 4;
        parts = ["Copper Wiring Roll", "Insulation Tape"];
        partsCost = 1800;
        labor = 1000;
      }

      setState(() {
        _severity = severity;
        _partsRecommended = parts;
        _partsCost = partsCost;
        _additionalLabor = labor;
        _updatedFare = _originalFare + partsCost + labor;
        _diagnosisSummaryEn = "Diagnosed locally: ${parts.join(', ')}";
        _diagnosisSummaryUr = "لوکل تشخیص: ${parts.join(', ')}";
        _isDiagnosing = false;
      });
    }
  }

  Future<void> _finalizeInvoice() async {
    try {
      final isMock = ref.read(localeProvider).isMockMode;
      if (isMock || _bookingId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mock Invoice finalized! Sent successfully.'),
            backgroundColor: Colors.teal,
          ),
        );
        context.go('/provider_dashboard');
        return;
      }

      final db = FirebaseFirestore.instance;

      // Update globally under Bookings
      await db.collection('Bookings').doc(_bookingId).update({
        'status': 'COMPLETED',
        'severity': _severity,
        'partsCost': _partsCost,
        'partsRecommended': _partsRecommended,
        'additionalLabor': _additionalLabor,
        'priceEstimate': 'Rs. $_updatedFare',
        'updatedFare': _updatedFare,
        'diagnosisSummaryEn': _diagnosisSummaryEn,
        'diagnosisSummaryUr': _diagnosisSummaryUr,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Retrieve customer_id to update sub-collection
      final bookingDoc = await db.collection('Bookings').doc(_bookingId).get();
      final customerId = bookingDoc.data()?['customer_id'] ?? bookingDoc.data()?['customerId'];

      if (customerId != null) {
        await db.collection('Users').doc(customerId).collection('Bookings').doc(_bookingId).update({
          'status': 'COMPLETED',
          'severity': _severity,
          'parts_cost': _partsCost,
          'parts_recommended': _partsRecommended,
          'additional_labor': _additionalLabor,
          'price_estimate': 'Rs. $_updatedFare',
          'updated_fare': _updatedFare,
          'diagnosis_summary_en': _diagnosisSummaryEn,
          'diagnosis_summary_ur': _diagnosisSummaryUr,
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice of Rs. $_updatedFare sent successfully to $_customerName!'),
          backgroundColor: Colors.teal,
        ),
      );
      context.go('/provider_dashboard');
    } catch (e) {
      debugPrint("Error finalizing invoice: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Could not finalize invoice. ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;

    final backgroundColor = isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final accentColor = isDark ? _kDarkAccentCyan : const Color(0xFF4F46E5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final hintTextColor = isDark ? _kDarkHintTextColor : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text('AI Diagnostics', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ref.read(localeProvider.notifier).setLanguage(
                ref.read(localeProvider).language == AppLanguage.urdu ? AppLanguage.en : AppLanguage.urdu
              );
            },
            icon: Icon(Icons.language, color: textSecondaryColor),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildCustomerInfo(surfaceColor, accentColor, textColor, textSecondaryColor, hintTextColor, borderColor),
                  const SizedBox(height: 30),
                  Text('Voice Diagnosis', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    'Describe the problem. The Agent will translate it, identify severity, and compute exact fare updates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: hintTextColor, fontSize: 13),
                  ),
                  const SizedBox(height: 30),
                  _buildMicButton(backgroundColor, accentColor),
                  const SizedBox(height: 30),
                  _buildTranscriptionBox(surfaceColor, accentColor, textColor),
                  if (_isDiagnosing)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
                          ),
                          const SizedBox(width: 10),
                          Text('AI Agent calculating pricing...', style: TextStyle(color: accentColor, fontSize: 12)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                  _buildBillingCard(surfaceColor, accentColor, textColor, textSecondaryColor, borderColor),
                ],
              ),
            ),
          ),
          _buildFinalizeButton(),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(
    Color surfaceColor,
    Color accentColor,
    Color textColor,
    Color textSecondaryColor,
    Color hintTextColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 25, backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=customer')),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_customerName, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('🔧 $_serviceType', style: TextStyle(color: accentColor, fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor, width: 0.5),
                ),
                child: const Text('DIAGNOSING', style: TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: borderColor),
          const SizedBox(height: 12),
          Text(
            'Initial estimate: Rs. $_originalFare. Status will transition to complete on invoice finalize.',
            style: TextStyle(color: hintTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(Color backgroundColor, Color accentColor) {
    return AvatarGlow(
      animate: _isListening,
      glowColor: accentColor,
      duration: const Duration(milliseconds: 2000),
      repeat: true,
      child: GestureDetector(
        onTap: () async {
          if (!_isListening) {
            bool available = await _speech.initialize();
            if (available) {
              setState(() => _isListening = true);
              _speech.listen(onResult: (val) {
                setState(() => _transcription = val.recognizedWords);
                if (val.finalResult) {
                  setState(() => _isListening = false);
                  _runAIDiagnosis(_transcription);
                }
              });
            } else {
              // Simulator / browser debug mode - simulate voice input on tap
              setState(() => _isListening = true);
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _isListening) {
                  String testPhrase = "AC compressor is damaged and leaking cooling gas, needs charging.";
                  if (_serviceCategory.toLowerCase().contains("plumb")) {
                    testPhrase = "Main pipe is cracked and leaking under the kitchen sink, needs joint replacement.";
                  } else if (_serviceCategory.toLowerCase().contains("elect")) {
                    testPhrase = "Short circuit spark inside the main switch board, needs standard wire and switch replacement.";
                  }
                  setState(() {
                    _isListening = false;
                    _transcription = testPhrase;
                  });
                  _runAIDiagnosis(testPhrase);
                }
              });
            }
          } else {
            setState(() => _isListening = false);
            _speech.stop();
          }
        },
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2),
            boxShadow: [
              BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Icon(_isListening ? Icons.stop : Icons.mic_none, color: accentColor, size: 32),
        ),
      ),
    );
  }

  Widget _buildTranscriptionBox(Color surfaceColor, Color accentColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Text(
        _transcription,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: textColor.withOpacity(0.8), fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildBillingCard(
    Color surfaceColor,
    Color accentColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Issue Severity', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (index) {
                  bool filled = index < _severity;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _severity = index + 1;
                      _updatedFare = _originalFare + _partsCost + (_severity * 250);
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? Colors.amber : (borderColor),
                        border: Border.all(color: filled ? Colors.orange : Colors.grey, width: 0.5),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_partsRecommended.isNotEmpty) ...[
            Text('REPLACEMENT PARTS:', style: TextStyle(color: textSecondaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            ..._partsRecommended.map((part) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                  const SizedBox(width: 8),
                  Text(part, style: TextStyle(color: textColor, fontSize: 13)),
                ],
              ),
            )),
            const SizedBox(height: 16),
          ],
          Divider(color: borderColor),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UPDATED FARE', style: TextStyle(color: textSecondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Rs. $_updatedFare', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Base: Rs. $_originalFare', style: TextStyle(color: textSecondaryColor, fontSize: 11)),
                  Text('Parts: + Rs. $_partsCost', style: TextStyle(color: textSecondaryColor, fontSize: 11)),
                  Text('Labor: + Rs. $_additionalLabor', style: TextStyle(color: textSecondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinalizeButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFF00B59C), Color(0xFF00D1FF)]),
        ),
        child: ElevatedButton(
          onPressed: _finalizeInvoice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Finalize & Send Invoice', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
