import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/booking_provider.dart';
import '../widgets/customer_app_bar.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/customer_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  
  // Voice & Speech
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _lastWords = "";

  // Queue for processing
  final Queue<String> _inputQueue = Queue<String>();
  bool _stopRequested = false;
  http.Client? _activeClient;

  // Dark Colors
  static const Color _kDarkBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kDarkSurfaceColor = Color(0xFF161B2E);
  static const Color _kDarkPrimaryPurple = Color(0xFFBDB2FF);
  static const Color _kDarkInputBorderColor = Color(0xFF2E344A);
  static const Color _kDarkHintTextColor = Color(0xFF6B7280);
  static const Color _kDarkAccentGreen = Color(0xFF4ADE80);

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  void _initTTS() async {
    await _tts.setLanguage("ur-PK"); // Default to Urdu
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
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
        onError: (val) => debugPrint('STT Error: $val'),
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
              _onUserSubmit(_lastWords);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
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

  void _onUserSubmit(String text) {
    if (text.trim().isEmpty) return;
    
    _inputQueue.add(text.trim());
    _controller.clear();
    
    final chatState = ref.read(chatProvider);
    if (!chatState.isProcessing) {
      _processNextInQueue();
    }
  }

  Future<void> _processNextInQueue() async {
    if (_inputQueue.isEmpty || _stopRequested) {
      ref.read(chatProvider.notifier).setProcessing(false);
      _stopRequested = false;
      return;
    }

    ref.read(chatProvider.notifier).setProcessing(true);
    final text = _inputQueue.removeFirst();

    ref.read(chatProvider.notifier).addMessage(ChatMessage(text: text, isUser: true));
    ref.read(chatProvider.notifier).addSessionInput(text.trim());
    _scrollToBottom();

    bool hasError = false;
    String errorMsg = "";

    try {
      final user = ref.read(authProvider).user;
      final chatState = ref.read(chatProvider);
      final combinedMessage = chatState.sessionInputs.join(". ");
      
      final history = chatState.messages.map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text
      }).toList();

      _activeClient = http.Client();
      final response = await _activeClient!.post(
        Uri.parse('http://127.0.0.1:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': combinedMessage,
          'user_id': user?.id ?? 'guest_user',
          'history': history,
        }),
      ).timeout(const Duration(seconds: 30));

      if (_stopRequested) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          ref.read(chatProvider.notifier).addMessage(ChatMessage(
            text: "Finding available Providers near ${data['booking']?['location'] ?? 'your location'}...",
            isUser: false,
            isStatus: true,
          ));
          
          if (_stopRequested) return;

          ref.read(chatProvider.notifier).addMessage(ChatMessage(text: data['reply'], isUser: false));
          
          // Populate the booking provider state with real data from backend
          final user = ref.read(authProvider).user;
          ref.read(bookingProvider.notifier).setBookingFromResult(data, text, user);

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_stopRequested) {
              ref.read(chatProvider.notifier).clearChat();
              context.push('/processing-pipeline');
            }
          });
        } else if (data['status'] == 'clarification_needed') {
          ref.read(chatProvider.notifier).addMessage(ChatMessage(text: data['reply'], isUser: false));
        } else {
          hasError = true;
          errorMsg = data['reply'] ?? "Server encountered an error.";
        }
      } else {
        hasError = true;
        errorMsg = "Server error (${response.statusCode}). Please try again.";
      }
    } catch (e) {
      if (_stopRequested) return;
      debugPrint("CHAT_ERROR: $e");
      hasError = true;
      errorMsg = e.toString().contains('TimeoutException') 
          ? "Request timed out. Please check your internet or retry."
          : "Connection error: ${e.toString().contains('SocketException') ? 'Cannot reach server.' : 'Lost connection'}";
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }

    if (hasError && !_stopRequested) {
      ref.read(chatProvider.notifier).addMessage(ChatMessage(
        text: errorMsg, 
        isUser: false,
        isError: true,
      ));
    }

    _scrollToBottom();
    if (!_stopRequested) _processNextInQueue();
  }

  void _onStop() {
    setState(() {
      _stopRequested = true;
      _inputQueue.clear();
      _activeClient?.close();
      _activeClient = null;
    });
    ref.read(chatProvider.notifier).setProcessing(false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous != null && previous.user != null && next.user == null) {
        ref.read(chatProvider.notifier).clearChat();
      }
    });

    final isDark = ref.watch(localeProvider).isDarkMode;
    final user = ref.watch(authProvider).user;
    final chatState = ref.watch(chatProvider);
    final userName = user?.name.split(' ')[0] ?? 'User';

    final backgroundColor = isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? _kDarkSurfaceColor : Colors.white;
    final primaryPurple = isDark ? _kDarkPrimaryPurple : const Color(0xFF4F46E5);
    final inputBorderColor = isDark ? _kDarkInputBorderColor : const Color(0xFFE2E8F0);
    final hintTextColor = isDark ? _kDarkHintTextColor : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CustomerAppBar(),
      drawer: const CustomerDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 20),
                  _buildGreeting(userName, chatState.isProcessing, isDark, primaryPurple, hintTextColor, textColor),
                  const SizedBox(height: 20),
                  _buildUrduBanner(surfaceColor, textColor, inputBorderColor),
                  const SizedBox(height: 24),
                  ...chatState.messages.asMap().entries.map((entry) => _buildMessageBubble(entry.value, entry.key, isDark, surfaceColor, primaryPurple, inputBorderColor, hintTextColor, textColor, backgroundColor)),
                  if (chatState.isProcessing) _buildLoadingIndicator(isDark, surfaceColor),
                ],
              ),
            ),
            _buildInputArea(chatState.isProcessing, isDark, surfaceColor, inputBorderColor, hintTextColor, textColor, primaryPurple),
          ],
        ),
      ),
      bottomNavigationBar: const CustomerBottomNav(currentIndex: 0),
    );
  }

  Widget _buildGreeting(String name, bool isProcessing, bool isDark, Color primaryPurple, Color hintTextColor, Color textColor) {
    final translate = ref.read(localeProvider.notifier).translate;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${translate('hi')}, $name!',
                style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                translate('how_assist'),
                style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 16),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: isProcessing ? null : () => ref.read(chatProvider.notifier).clearChat(),
          child: Text(
            translate('clear_chat'),
            style: TextStyle(
              color: isProcessing ? hintTextColor : primaryPurple,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrduBanner(Color surfaceColor, Color textColor, Color borderColor) {
    final translate = ref.read(localeProvider.notifier).translate;
    final isUrduScript = ref.read(localeProvider).language == AppLanguage.urdu;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        translate('urdu_banner'),
        textAlign: isUrduScript ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: textColor, fontSize: 16),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    int index,
    bool isDark,
    Color surfaceColor,
    Color primaryPurple,
    Color borderColor,
    Color hintTextColor,
    Color textColor,
    Color backgroundColor,
  ) {
    if (message.isError == true) {
      return _buildErrorTile(message.text, surfaceColor, borderColor);
    }
    if (message.isStatus == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.cyan, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isDark ? Colors.cyan : Colors.cyan.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubbleBg = message.isUser ? primaryPurple : (isDark ? surfaceColor : const Color(0xFFF1F5F9));
    final bubbleText = message.isUser 
        ? (isDark ? backgroundColor : Colors.white) 
        : textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) 
                GestureDetector(
                  onTap: () => _speak(message.text),
                  child: _buildAvatar(Icons.volume_up, Colors.cyan, isDark, surfaceColor, backgroundColor),
                ),
              const SizedBox(width: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(color: bubbleText, fontSize: 15),
                  ),
                ),
              ),
              if (message.isUser) const SizedBox(width: 12),
              if (message.isUser) _buildAvatar(Icons.person, primaryPurple, isDark, surfaceColor, backgroundColor, isUser: true),
            ],
          ),
          if (message.isUser)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildMessageAction(Icons.copy_rounded, isDark, surfaceColor, borderColor, primaryPurple, () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                  }),
                  const SizedBox(width: 8),
                  _buildMessageAction(Icons.edit_outlined, isDark, surfaceColor, borderColor, primaryPurple, () {
                    _controller.text = message.text;
                    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageAction(IconData icon, bool isDark, Color surfaceColor, Color borderColor, Color primaryPurple, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, color: primaryPurple.withOpacity(0.8), size: 14),
      ),
    );
  }

  Widget _buildErrorTile(String error, Color surfaceColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final chatNotifier = ref.read(chatProvider.notifier);
                final chatState = ref.read(chatProvider);
                
                final errorIndex = chatState.messages.indexWhere((m) => m.text == error && m.isError == true);
                if (errorIndex != -1) {
                  chatNotifier.removeMessage(errorIndex);
                }

                final lastUserMsg = chatState.messages.lastWhere((m) => m.isUser, orElse: () => ChatMessage(text: "", isUser: true)).text;
                if (lastUserMsg.isNotEmpty) {
                  _onUserSubmit(lastUserMsg);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(IconData icon, Color color, bool isDark, Color surfaceColor, Color backgroundColor, {bool isUser = false}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isUser ? color : surfaceColor,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1),
      ),
      child: Icon(icon, color: isUser ? backgroundColor : color, size: 18),
    );
  }

  Widget _buildLoadingIndicator(bool isDark, Color surfaceColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(Icons.smart_toy_outlined, Colors.cyan, isDark, surfaceColor, isDark ? _kDarkBackgroundColor : const Color(0xFFF8FAFC)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
    bool isProcessing,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color hintTextColor,
    Color textColor,
    Color primaryPurple,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !isProcessing,
                style: TextStyle(color: isProcessing ? hintTextColor : textColor),
                decoration: InputDecoration(
                  hintText: isProcessing ? 'Processing request...' : 'Type or speak your request...',
                  hintStyle: TextStyle(color: hintTextColor),
                  border: InputBorder.none,
                ),
                onSubmitted: isProcessing ? null : _onUserSubmit,
              ),
            ),
            if (!isProcessing)
              GestureDetector(
                onTap: _listen,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    _isListening ? Icons.stop_circle : Icons.mic, 
                    color: _isListening ? Colors.red : (isDark ? _kDarkAccentGreen : const Color(0xFF10B981)),
                    size: 28,
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                isProcessing ? Icons.stop_circle_rounded : Icons.send, 
                color: isProcessing ? Colors.redAccent : ( _controller.text.isEmpty ? hintTextColor : primaryPurple)
              ),
              onPressed: isProcessing ? _onStop : () => _onUserSubmit(_controller.text),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
