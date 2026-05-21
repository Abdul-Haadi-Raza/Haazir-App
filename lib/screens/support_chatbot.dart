import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import '../providers/locale_provider.dart';

class SupportChatbot extends ConsumerStatefulWidget {
  const SupportChatbot({super.key});

  @override
  ConsumerState<SupportChatbot> createState() => _SupportChatbotState();
}

class _SupportChatbotState extends ConsumerState<SupportChatbot> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isError = false;
  String _lastSentText = '';

  // Voice & Speech
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _lastWords = "";

  http.Client? _activeClient;
  bool _isCancelled = false;

  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkAccentCyan = Color(0xFF00D1FF);

  static const Color _kLightBackgroundColor = Color(0xFFF8FAFC);
  static const Color _kLightSurfaceColor = Colors.white;
  static const Color _kLightAccentIndigo = Color(0xFF4F46E5);

  final String _systemPrompt = """
You are the HAAZIR app support bot. HAAZIR is a premier on-demand home service application connecting customers with highly skilled, verified providers such as plumbers, electricians, AC technicians, and more.
Key Features:
- AI-driven matching: Our 'Concierge Agent' understands customer problems via chat and assigns the best provider.
- Multilingual Support: App supports English, Roman Urdu, and Urdu script.
- Verified Professionals: Every provider undergoes CNIC verification for safety.
- Mock Mode: Users can explore app features using simulated data without real transactions.

Policies:
1. Cancellation: Free of charge as long as the provider hasn't started their journey.
2. Payment: We currently exclusively use Cash on Delivery. Online payments are in development.
3. Service Areas: Currently serving Islamabad and Rawalpindi.
4. Support Hours: 24/7 AI support; human support available 9 AM to 9 PM.

When the user asks about the app, explain these features politely. If they ask about a specific service like 'my AC isn't cooling', remind them they can book via the main home screen chat.
""";

  @override
  void initState() {
    super.initState();
    _initTTS();
    _addInitialGreeting();
  }

  void _initTTS() async {
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  void _addInitialGreeting() {
    _messages.add({
      'role': 'bot',
      'text': 'Assalam-o-Alaikum! Welcome to HAAZIR Customer Support. How can I assist you today? I can help with cancellation policies, mock mode, payment options, and service areas!',
      'timestamp': DateTime.now(),
    });
  }

  void _speak(String text) async {
    if (RegExp(r'[a-zA-Z]').hasMatch(text) && !text.contains(RegExp(r'[\u0600-\u06FF]'))) {
      await _tts.setLanguage("en-US");
    } else {
      await _tts.setLanguage("ur-PK");
    }
    await _tts.speak(text);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('STT Status: $val'),
        onError: (val) {
          debugPrint('STT Error: $val');
          setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: "ur_PK",
          onResult: (val) {
            setState(() {
              _lastWords = val.recognizedWords;
              _controller.text = _lastWords;
            });
            if (val.finalResult) {
              setState(() => _isListening = false);
              _sendMessage(textOverride: _lastWords);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _controller.text.trim();
    if (text.isEmpty) return;

    _lastSentText = text;

    setState(() {
      if (textOverride == null) _controller.clear();
      _messages.add({
        'role': 'user',
        'text': text,
        'timestamp': DateTime.now(),
      });
      _isLoading = true;
      _isError = false;
      _isCancelled = false;
    });

    _scrollToBottom();
    _activeClient = http.Client();

    try {
      const String apiKey = "AIzaSyAT-7CAXP5WsuHulJ80ZP8mPWTHWtJxBBs";
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey');

      // Map chat history to Gemini's expected contents structure
      final contents = _messages.map((m) {
        final role = m['role'] == 'user' ? 'user' : 'model';
        return {
          'role': role,
          'parts': [
            {'text': m['text']}
          ]
        };
      }).toList();

      final response = await _activeClient!.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'systemInstruction': {
            'parts': [
              {'text': _systemPrompt}
            ]
          }
        }),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (_isCancelled) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = '';
        try {
          reply = data['candidates'][0]['content']['parts'][0]['text'] ?? 'I am sorry, I could not process that.';
        } catch (e) {
          reply = 'I am sorry, I could not process that.';
        }

        setState(() {
          _messages.add({
            'role': 'bot',
            'text': reply,
            'timestamp': DateTime.now(),
          });
        });
        _speak(reply);
      } else {
        setState(() {
          _isError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_isCancelled) return;
      setState(() {
        _isError = true;
      });
    } finally {
      _activeClient = null;
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _stopResponse() {
    if (_isLoading) {
      setState(() {
        _isCancelled = true;
        _isLoading = false;
        _isError = false;
      });
      _activeClient?.close();
      _activeClient = null;
    }
  }

  @override
  void dispose() {
    _activeClient?.close();
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _retryMessage() {
    if (_lastSentText.isNotEmpty) {
      _sendMessage(textOverride: _lastSentText);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentsSheet() {
    final isDark = ref.read(localeProvider).isDarkMode;
    final primaryColor = isDark ? _kDarkAccentCyan : _kLightAccentIndigo;
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Add Diagnostic Attachment',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(Icons.image, 'Image/Photo', primaryColor, () {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo selected (Simulated)')));
                  }),
                  _buildAttachmentOption(Icons.mic, 'Voice Memo', primaryColor, () {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice note recorded (Simulated)')));
                  }),
                  _buildAttachmentOption(Icons.description, 'Receipt/Doc', primaryColor, () {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded (Simulated)')));
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = ref.read(localeProvider).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(localeProvider).isDarkMode;
    final backgroundColor = isDark ? _kDarkBackgroundColor : _kLightBackgroundColor;
    final surfaceColor = isDark ? _kDarkSurfaceColor : _kLightSurfaceColor;
    final accentColor = isDark ? _kDarkAccentCyan : _kLightAccentIndigo;
    final borderSideColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        iconTheme: IconThemeData(color: textColor),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HAAZIR Support Bot',
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'AI Assistance Active',
                  style: TextStyle(color: isDark ? _kDarkAccentCyan : const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderSideColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return _buildMessageBubble(msg, isUser, isDark, accentColor, borderSideColor);
                },
              ),
            ),

            if (_isError) _buildErrorCard(accentColor, surfaceColor, borderSideColor),

            if (_isLoading) _buildLoadingBubble(isDark, borderSideColor),

            // Pre-filled suggestion chips
            if (!_isLoading && !_isError) _buildSuggestionsList(accentColor),

            // Chat Input Bar
            _buildInputPanel(isDark, surfaceColor, accentColor, borderSideColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, bool isDark, Color accentColor, Color borderSideColor) {
    final bubbleBg = isUser ? accentColor : (isDark ? _kDarkSurfaceColor : const Color(0xFFF1F5F9));
    final textCol = isUser ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accentColor.withOpacity(0.15),
                  child: Icon(Icons.auto_awesome, color: accentColor, size: 14),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: msg['text']!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied to clipboard!')));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: bubbleBg,
                      border: isUser ? null : Border.all(color: borderSideColor),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(color: textCol, fontSize: 14, height: 1.5),
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  child: Icon(Icons.person_outline, color: isDark ? Colors.white70 : Colors.black87, size: 14),
                ),
              ],
            ],
          ),
          // Audio and copy utilities for Bot messages
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 38, bottom: 12, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _speak(msg['text']!),
                    child: Wrap(
                      children: [
                        Icon(Icons.volume_up, size: 14, color: isDark ? Colors.white30 : Colors.black38),
                        const SizedBox(width: 4),
                        Text('Listen', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg['text']!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                    },
                    child: Wrap(
                      children: [
                        Icon(Icons.copy, size: 14, color: isDark ? Colors.white30 : Colors.black38),
                        const SizedBox(width: 4),
                        Text('Copy', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(bool isDark, Color borderSideColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, bottom: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.blueAccent),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? _kDarkSurfaceColor : const Color(0xFFF1F5F9),
                border: Border.all(color: borderSideColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? _kDarkAccentCyan : _kLightAccentIndigo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Haazir AI is thinking...',
                    style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF475569), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(Color accentColor, Color surfaceColor, Color borderSideColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Technical error', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Failed to receive response from backend.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _retryMessage,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Sending', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(Color accentColor) {
    final suggestions = [
      'Cancellation Policy',
      'What payment methods?',
      'Serviced Areas',
      'Tell me about Mock Mode',
      'Talk to human support',
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              onPressed: () => _sendMessage(textOverride: text),
              label: Text(text, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
              backgroundColor: accentColor.withOpacity(0.08),
              side: BorderSide(color: accentColor.withOpacity(0.25)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputPanel(bool isDark, Color surfaceColor, Color accentColor, Color borderSideColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderSideColor)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isLoading ? null : _showAttachmentsSheet,
            icon: Icon(Icons.add_circle_outline, color: _isLoading ? Colors.grey : accentColor, size: 26),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoading,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: _isLoading ? 'Please wait for response...' : 'Ask anything about HAAZIR...',
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: borderSideColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: borderSideColor),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: borderSideColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: accentColor),
                ),
                fillColor: isDark ? _kDarkBackgroundColor : const Color(0xFFF1F5F9),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: _isLoading ? null : (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : _listen,
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isLoading ? Colors.grey : (_isListening ? Colors.redAccent : accentColor),
              size: 26,
            ),
          ),
          IconButton(
            onPressed: _isLoading ? _stopResponse : () => _sendMessage(),
            icon: Icon(
              _isLoading ? Icons.stop_circle_rounded : Icons.send_rounded,
              color: _isLoading ? Colors.redAccent : accentColor,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}
