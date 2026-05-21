import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool? isStatus;
  final bool? isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isStatus = false,
    this.isError = false,
  });

  bool get status => isStatus ?? false;
  bool get error => isError ?? false;
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isProcessing;
  final List<String> sessionInputs;

  ChatState({
    required this.messages,
    this.isProcessing = false,
    this.sessionInputs = const [],
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isProcessing,
    List<String>? sessionInputs,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      sessionInputs: sessionInputs ?? this.sessionInputs,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState(messages: [
    ChatMessage(
      text: "Welcome to Haazir! I'm your AI concierge. Do you need a service, or something delivered?",
      isUser: false,
    )
  ], sessionInputs: const []));

  void addMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void addSessionInput(String input) {
    state = state.copyWith(sessionInputs: [...state.sessionInputs, input]);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void removeMessage(int index) {
    final newList = List<ChatMessage>.from(state.messages);
    newList.removeAt(index);
    state = state.copyWith(messages: newList);
  }

  void removeLastMessageIfError() {
    if (state.messages.isNotEmpty && state.messages.last.error) {
      final newList = List<ChatMessage>.from(state.messages);
      newList.removeLast();
      state = state.copyWith(messages: newList);
    }
  }

  void clearChat() {
    state = ChatState(
      messages: [
        ChatMessage(
          text: "Welcome to Haazir! I'm your AI concierge. Do you need a service, or something delivered?",
          isUser: false,
        )
      ],
      sessionInputs: const [],
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
