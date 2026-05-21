class AppDictionary {
  static const Map<String, Map<String, String>> strings = {
    'welcome_back': {
      'en': 'Welcome Back',
      'ur': 'خوش آمدید',
    },
    'sign_in_desc': {
      'en': 'Sign in to request services',
      'ur': 'سروسز کے لیے سائن ان کریں',
    },
    'phone_hint': {
      'en': 'Phone Number (e.g., 0300...)',
      'ur': 'فون نمبر',
    },
    'pin_hint': {
      'en': '4-Digit PIN',
      'ur': 'پِن کوڈ',
    },
    'login_btn': {
      'en': 'Login',
      'ur': 'لاگ ان',
    },
    'create_account': {
      'en': 'Create Account',
      'ur': 'نیا اکاؤنٹ بنائیں',
    },
    'no_account': {
      'en': 'Don\'t have an account? ',
      'ur': 'اکاؤنٹ نہیں ہے؟ ',
    },
    'chat_hint': {
      'en': 'Example: I need a plumber in F-8...',
      'ur': 'مثال: مجھے پلمبر چاہیے...',
    },
    'ai_working': {
      'en': 'AI is working on your request...',
      'ur': 'اے آئی کام کر رہا ہے...',
    }
  };
}

extension AppDictionaryExtension on String {
  String tr(String locale) {
    return AppDictionary.strings[this]?[locale] ?? this;
  }
}
