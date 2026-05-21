import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, roman, urdu }

class AppLocaleState {
  final AppLanguage language;
  final bool isDarkMode;
  final bool isEyesProtectionEnabled;
  final bool isMockMode;

  AppLocaleState({
    this.language = AppLanguage.en,
    this.isDarkMode = true,
    this.isEyesProtectionEnabled = false,
    this.isMockMode = false,
  });

  AppLocaleState copyWith({
    AppLanguage? language,
    bool? isDarkMode,
    bool? isEyesProtectionEnabled,
    bool? isMockMode,
  }) {
    return AppLocaleState(
      language: language ?? this.language,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isEyesProtectionEnabled: isEyesProtectionEnabled ?? this.isEyesProtectionEnabled,
      isMockMode: isMockMode ?? this.isMockMode,
    );
  }
}

class AppLocaleNotifier extends StateNotifier<AppLocaleState> {
  AppLocaleNotifier() : super(AppLocaleState()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? true;
      final langIndex = prefs.getInt('language') ?? 0;
      final isMock = prefs.getBool('isMockMode') ?? false;
      final isEyes = prefs.getBool('isEyesProtectionEnabled') ?? false;
      
      state = AppLocaleState(
        isDarkMode: isDark,
        language: AppLanguage.values[langIndex],
        isMockMode: isMock,
        isEyesProtectionEnabled: isEyes,
      );
    } catch (e) {
      // Ignore
    }
  }

  void setLanguage(AppLanguage lang) {
    state = state.copyWith(language: lang);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('language', lang.index);
    });
  }

  void toggleDarkMode() {
    final newMode = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newMode);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isDarkMode', newMode);
    });
  }

  void toggleEyesProtection() {
    final newProtection = !state.isEyesProtectionEnabled;
    state = state.copyWith(isEyesProtectionEnabled: newProtection);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isEyesProtectionEnabled', newProtection);
    });
  }

  void toggleMockMode() {
    final newMock = !state.isMockMode;
    state = state.copyWith(isMockMode: newMock);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isMockMode', newMock);
    });
  }

  String translate(String key) {
    // Extensive translation map for core UI, headings, form labels, errors and dialogs
    final Map<String, Map<AppLanguage, String>> _map = {
      // Common App Bar & Statuses
      'status': {AppLanguage.en: 'Status', AppLanguage.roman: 'Status', AppLanguage.urdu: 'حالت'},
      'online': {AppLanguage.en: 'ONLINE', AppLanguage.roman: 'Online', AppLanguage.urdu: 'آن لائن'},
      'offline': {AppLanguage.en: 'OFFLINE', AppLanguage.roman: 'Offline', AppLanguage.urdu: 'آف لائن'},
      'status_msg': {
        AppLanguage.en: 'You are currently',
        AppLanguage.roman: 'Aap is waqt',
        AppLanguage.urdu: 'آپ اس وقت'
      },
      'recent_jobs': {AppLanguage.en: 'Recent Jobs', AppLanguage.roman: 'Halya Kaam', AppLanguage.urdu: 'حالیہ کام'},
      'earnings': {AppLanguage.en: 'Earnings', AppLanguage.roman: 'Kamai', AppLanguage.urdu: 'کمائی'},
      'history': {AppLanguage.en: 'History', AppLanguage.roman: 'History', AppLanguage.urdu: 'تاریخ'},
      'profile': {AppLanguage.en: 'Profile', AppLanguage.roman: 'Profile', AppLanguage.urdu: 'پروفائل'},
      'home': {AppLanguage.en: 'Home', AppLanguage.roman: 'Home', AppLanguage.urdu: 'ہوم'},
      'jobs_done': {AppLanguage.en: 'Jobs Done', AppLanguage.roman: 'Kaam Khatam', AppLanguage.urdu: 'مکمل کام'},
      'no_data': {AppLanguage.en: 'No Data Available', AppLanguage.roman: 'Data mojood nahi', AppLanguage.urdu: 'ڈیٹا دستیاب نہیں'},
      'no_data_available': {
        AppLanguage.en: 'NO data is available, load mock data and simulate the provider profile',
        AppLanguage.roman: 'Data mojood nahi, mock data load karein aur profile dekhein',
        AppLanguage.urdu: 'ڈیٹا دستیاب نہیں ہے، فرضی ڈیٹا لوڈ کریں اور پروفائل دیکھیں'
      },
      'edit_profile': {AppLanguage.en: 'Edit Profile', AppLanguage.roman: 'Profile badlein', AppLanguage.urdu: 'پروفائل میں ترمیم کریں'},
      'settings': {AppLanguage.en: 'Settings', AppLanguage.roman: 'Settings', AppLanguage.urdu: 'ترتیبات'},
      'help_support': {AppLanguage.en: 'Help & Support', AppLanguage.roman: 'Madad aur Support', AppLanguage.urdu: 'مدد اور سپورٹ'},
      'forgot_password': {AppLanguage.en: 'Forgot Password', AppLanguage.roman: 'Password bhool gaye?', AppLanguage.urdu: 'پاس ورڈ بھول گئے؟'},
      'change_pin': {AppLanguage.en: 'Change PIN', AppLanguage.roman: 'PIN badlein', AppLanguage.urdu: 'پن تبدیل کریں'},
      'reupload_cnic': {AppLanguage.en: 'Re-upload CNIC', AppLanguage.roman: 'CNIC dobara bhejein', AppLanguage.urdu: 'شناختی کارڈ دوبارہ اپ لوڈ کریں'},
      'dark_mode': {AppLanguage.en: 'Dark Mode', AppLanguage.roman: 'Dark Mode', AppLanguage.urdu: 'ڈارک موڈ'},
      'eye_protection': {AppLanguage.en: 'Eye Protection', AppLanguage.roman: 'Aankhon ki hifazat', AppLanguage.urdu: 'آنکھوں کی حفاظت'},
      'withdraw': {AppLanguage.en: 'Withdraw Funds', AppLanguage.roman: 'Raqam nikalain', AppLanguage.urdu: 'رقم نکلوائیں'},
      'total_balance': {AppLanguage.en: 'TOTAL BALANCE', AppLanguage.roman: 'KUL RAQAM', AppLanguage.urdu: 'کل بیلنس'},
      'last_7_days': {AppLanguage.en: 'Last 7 Days', AppLanguage.roman: 'Pichly 7 din', AppLanguage.urdu: 'گزشتہ 7 دن'},
      'rating_dist': {AppLanguage.en: 'Rating Distribution', AppLanguage.roman: 'Rating ki tafseel', AppLanguage.urdu: 'ریٹنگ کی تقسیم'},
      'performance': {AppLanguage.en: 'Performance & Feedback', AppLanguage.roman: 'Karkardagi aur Feedback', AppLanguage.urdu: 'کارکردگی اور تاثرات'},
      'mock_disclaimer': {
        AppLanguage.en: 'Mock data is only to show how the app looks with real data.',
        AppLanguage.roman: 'Mock data sirf yeh dekhny k liye hai k yeh application with real data kaisi lagi gi.',
        AppLanguage.urdu: 'فرضی ڈیٹا صرف یہ دکھانے کے لیے ہے کہ اصلی ڈیٹا کے ساتھ ایپلی کیشن کیسی لگے گی۔'
      },
      'today_earnings': {AppLanguage.en: "TODAY'S EARNINGS", AppLanguage.roman: "AAJ KI KAMAI", AppLanguage.urdu: "آج کی آمدنی"},
      'acceptance': {AppLanguage.en: "ACCEPTANCE", AppLanguage.roman: "ACCEPTANCE", AppLanguage.urdu: "قبولیت"},
      'avg_rating': {AppLanguage.en: "AVG RATING", AppLanguage.roman: "AVG RATING", AppLanguage.urdu: "اوسط ریٹنگ"},
      'logout': {AppLanguage.en: 'Logout', AppLanguage.roman: 'Log out', AppLanguage.urdu: 'لاگ آؤٹ'},
      'change_phone': {AppLanguage.en: 'Change Phone Number', AppLanguage.roman: 'Phone badlein', AppLanguage.urdu: 'فون نمبر تبدیل کریں'},

      // Login & Sign In Screen
      'welcome': {AppLanguage.en: 'WELCOME!', AppLanguage.roman: 'Khush Amdeed!', AppLanguage.urdu: 'خوش آمدید!'},
      'login_msg': {AppLanguage.en: 'Log in to your account', AppLanguage.roman: 'Apne account mein log in karein', AppLanguage.urdu: 'اپنے اکاؤنٹ میں لاگ ان کریں'},
      'mobile_number': {AppLanguage.en: 'MOBILE NUMBER', AppLanguage.roman: 'MOBILE NUMBER', AppLanguage.urdu: 'موبائل نمبر'},
      'four_digit_pin': {AppLanguage.en: '4-DIGIT PIN', AppLanguage.roman: '4-DIGIT PIN', AppLanguage.urdu: '4 ہندسوں کا پن'},
      'sign_in': {AppLanguage.en: 'Sign In', AppLanguage.roman: 'Sign In', AppLanguage.urdu: 'سائن ان'},
      'or': {AppLanguage.en: 'OR', AppLanguage.roman: 'Ya', AppLanguage.urdu: 'یا'},
      'continue_google': {AppLanguage.en: 'Continue with Google', AppLanguage.roman: 'Google ke saath jari rakhein', AppLanguage.urdu: 'گوگل کے ساتھ جاری رکھیں'},
      'new_here': {AppLanguage.en: 'New here? ', AppLanguage.roman: 'Yahan naye hain? ', AppLanguage.urdu: 'یہاں نئے ہیں؟ '},
      'sign_up': {AppLanguage.en: 'Sign Up', AppLanguage.roman: 'Sign Up', AppLanguage.urdu: 'سائن اپ'},
      'select_language': {AppLanguage.en: 'Select Language', AppLanguage.roman: 'Language select karein', AppLanguage.urdu: 'زبان منتخب کریں'},

      // Sign Up Screen
      'create_account': {AppLanguage.en: 'Create Account', AppLanguage.roman: 'Account banayein', AppLanguage.urdu: 'اکاؤنٹ بنائیں'},
      'customer': {AppLanguage.en: 'Customer', AppLanguage.roman: 'Customer', AppLanguage.urdu: 'گاہک'},
      'provider': {AppLanguage.en: 'Provider', AppLanguage.roman: 'Provider', AppLanguage.urdu: 'سروس فراہم کنندہ'},
      'full_name': {AppLanguage.en: 'Full Name', AppLanguage.roman: 'Poora Naam', AppLanguage.urdu: 'پورا نام'},
      'mobile_number_hint': {AppLanguage.en: 'Mobile Number', AppLanguage.roman: 'Mobile Number', AppLanguage.urdu: 'موبائل نمبر'},
      'home_address_hint': {AppLanguage.en: 'Home Address', AppLanguage.roman: 'Ghar ka Pata', AppLanguage.urdu: 'گھر کا پتہ'},
      'cnic_number_hint': {AppLanguage.en: 'CNIC Number', AppLanguage.roman: 'CNIC Number', AppLanguage.urdu: 'شناختی کارڈ نمبر'},
      'shop_address_hint': {AppLanguage.en: 'Shop Address', AppLanguage.roman: 'Dukan ka Pata', AppLanguage.urdu: 'دکان کا پتہ'},
      'experience_years_hint': {AppLanguage.en: 'Experience (Years)', AppLanguage.roman: 'Tajurba (Saal)', AppLanguage.urdu: 'تجربہ (سال)'},
      'upload_cnic_prompt': {AppLanguage.en: 'Upload CNIC Front Side image', AppLanguage.roman: 'CNIC ki samney wali pic upload karein', AppLanguage.urdu: 'شناختی کارڈ کے سامنے کی تصویر اپ لوڈ کریں'},
      'click_to_scan': {AppLanguage.en: 'Click to scan or upload from gallery', AppLanguage.roman: 'Scan ya gallery se upload karne ke liye click karein', AppLanguage.urdu: 'اسکین یا گیلری سے اپ لوڈ کرنے کے لیے کلک کریں'},
      'use_current_location': {AppLanguage.en: 'Use Current Location', AppLanguage.roman: 'Mojooda jagah istemal karein', AppLanguage.urdu: 'موجودہ مقام استعمال کریں'},
      'use_current_shop_location': {AppLanguage.en: 'Use Current Shop Location', AppLanguage.roman: 'Dukan ki mojooda jagah istemal karein', AppLanguage.urdu: 'دکان کا موجودہ مقام استعمال کریں'},
      'tap_to_pin_home': {AppLanguage.en: 'Tap to pin exact home location', AppLanguage.roman: 'Ghar ki sahi jagah pin karne ke liye tap karein', AppLanguage.urdu: 'گھر کا صحیح مقام پن کرنے کے لیے ٹیپ کریں'},
      'tap_to_pin_shop': {AppLanguage.en: 'Tap to pin shop location', AppLanguage.roman: 'Dukan ki jagah pin karne ke liye tap karein', AppLanguage.urdu: 'دکان کا مقام پن کرنے کے لیے ٹیپ کریں'},
      'location_pinned_label': {AppLanguage.en: 'Location Pinned: ', AppLanguage.roman: 'Location Pin ho gayi: ', AppLanguage.urdu: 'مقام پن ہو گیا: '},
      'shop_pinned_label': {AppLanguage.en: 'Shop Pinned: ', AppLanguage.roman: 'Dukan Pin ho gayi: ', AppLanguage.urdu: 'دکان پن ہو گئی: '},
      'pin_home_title': {AppLanguage.en: 'Pin Home Location', AppLanguage.roman: 'Ghar ka Pata Pin karein', AppLanguage.urdu: 'گھر کا مقام پن کریں'},
      'pin_shop_title': {AppLanguage.en: 'Pin Shop Location', AppLanguage.roman: 'Dukan ka Pata Pin karein', AppLanguage.urdu: 'دکان کا مقام پن کریں'},
      'search_area_placeholder': {AppLanguage.en: 'Search area...', AppLanguage.roman: 'Area search karein...', AppLanguage.urdu: 'علاقہ تلاش کریں...'},
      'pin_here': {AppLanguage.en: 'Pin here', AppLanguage.roman: 'Yahan pin karein', AppLanguage.urdu: 'یہاں پن کریں'},
      'confirm_location': {AppLanguage.en: 'Confirm Location', AppLanguage.roman: 'Location confirm karein', AppLanguage.urdu: 'مقام کی تصدیق کریں'},
      // Validation Errors
      'number_tou_enter_kro': {AppLanguage.en: 'Mobile Number is required.', AppLanguage.roman: 'number tou enter kro', AppLanguage.urdu: 'نمبر تو درج کریں'},
      'pin_tou_enter_kro': {AppLanguage.en: 'PIN is required.', AppLanguage.roman: 'pin tou enter kro', AppLanguage.urdu: 'پن تو درج کریں'},
      'err_phone_length': {AppLanguage.en: '11 digit ka phone number hota hai', AppLanguage.roman: '11 digit ka phone number hota hai', AppLanguage.urdu: 'موبائل نمبر 11 ہندسوں کا ہونا ضروری ہے'},
      'err_pin_length': {AppLanguage.en: 'PIN must be exactly 4 digits.', AppLanguage.roman: 'PIN 4 digits ka hona chahiye', AppLanguage.urdu: 'پن 4 ہندسوں کا ہونا ضروری ہے'},
      'err_phone_empty': {AppLanguage.en: 'Mobile Number is required', AppLanguage.roman: 'Mobile Number is required', AppLanguage.urdu: 'موبائل نمبر درج کرنا ضروری ہے'},
      'err_pin_empty': {AppLanguage.en: 'Security PIN is required', AppLanguage.roman: 'Security PIN is required', AppLanguage.urdu: 'سیکیورٹی پن درج کرنا ضروری ہے'},
      'err_name_empty': {AppLanguage.en: 'Full Name is required', AppLanguage.roman: 'Full Name is required', AppLanguage.urdu: 'مکمل نام درج کرنا ضروری ہے'},
      'err_confirm_pin_empty': {AppLanguage.en: 'Confirm Security PIN is required', AppLanguage.roman: 'Confirm Security PIN is required', AppLanguage.urdu: 'پن کی تصدیق کرنا ضروری ہے'},
      'err_pin_mismatch': {AppLanguage.en: 'pins not same', AppLanguage.roman: 'pins not same', AppLanguage.urdu: 'پن برابر نہیں ہیں'},
      'err_address_empty': {AppLanguage.en: 'Home Address is required', AppLanguage.roman: 'Home Address is required', AppLanguage.urdu: 'گھر کا پتہ درج کرنا ضروری ہے'},
      'err_shop_address_empty': {AppLanguage.en: 'Shop Address is required', AppLanguage.roman: 'Shop Address is required', AppLanguage.urdu: 'دکان کا پتہ درج کرنا ضروری ہے'},
      'err_cnic_empty': {AppLanguage.en: 'CNIC Number is required', AppLanguage.roman: 'CNIC Number is required', AppLanguage.urdu: 'شناختی کارڈ نمبر درج کرنا ضروری ہے'},
      'err_cnic_length': {AppLanguage.en: 'CNIC number must be exactly 13 digits.', AppLanguage.roman: 'CNIC 13 digits ka hona chahiye', AppLanguage.urdu: 'شناختی کارڈ نمبر 13 ہندسوں کا ہونا ضروری ہے'},
      'err_trade_empty': {AppLanguage.en: 'Trade Category is required', AppLanguage.roman: 'Trade Category is required', AppLanguage.urdu: 'پیشہ منتخب کرنا ضروری ہے'},
      'err_experience_empty': {AppLanguage.en: 'Experience is required', AppLanguage.roman: 'Experience is required', AppLanguage.urdu: 'تجربہ درج کرنا ضروری ہے'},
      'err_cnic_file_empty': {AppLanguage.en: 'CNIC Photo is required', AppLanguage.roman: 'CNIC Photo is required', AppLanguage.urdu: 'شناختی کارڈ کی تصویر اپ لوڈ کرنا ضروری ہے'},
      'err_home_map_empty': {AppLanguage.en: 'Map Location is required', AppLanguage.roman: 'Map Location is required', AppLanguage.urdu: 'نقشے پر مقام پن کرنا ضروری ہے'},
      'err_shop_map_empty': {AppLanguage.en: 'Map Location is required', AppLanguage.roman: 'Map Location is required', AppLanguage.urdu: 'نقشے پر مقام پن کرنا ضروری ہے'},

      // Success Dialog Mappings
      'success_title': {AppLanguage.en: 'Success!', AppLanguage.roman: 'Kamyaabi!', AppLanguage.urdu: 'کامیابی!'},
      'error_title': {AppLanguage.en: 'Error!', AppLanguage.roman: 'Ghalti!', AppLanguage.urdu: 'غلطی!'},
      'No user found with this phone number.': {
        AppLanguage.en: 'No user found with this phone number.',
        AppLanguage.roman: 'Is mobile number se koi account nahi mila.',
        AppLanguage.urdu: 'اس موبائل نمبر کے ساتھ کوئی اکاؤنٹ نہیں ملا۔'
      },
      'Incorrect PIN.': {
        AppLanguage.en: 'Incorrect PIN.',
        AppLanguage.roman: 'Ghalat PIN enter kiya hai.',
        AppLanguage.urdu: 'غلط پن درج کیا گیا ہے۔'
      },
      'This phone number is already registered.': {
        AppLanguage.en: 'This phone number is already registered.',
        AppLanguage.roman: 'Yeh mobile number pehle se registered hai.',
        AppLanguage.urdu: 'یہ موبائل نمبر پہلے سے رجسٹرڈ ہے۔'
      },
      'PIN must be at least 4 digits.': {
        AppLanguage.en: 'PIN must be at least 4 digits.',
        AppLanguage.roman: 'PIN kam az kam 4 digits ka hona chahiye.',
        AppLanguage.urdu: 'پن کم از کم 4 ہندسوں کا ہونا ضروری ہے۔'
      },
      'Invalid phone number format.': {
        AppLanguage.en: 'Invalid phone number format.',
        AppLanguage.roman: 'Mobile number ka format ghalat hai.',
        AppLanguage.urdu: 'موبائل نمبر کا فارمیٹ غلط ہے۔'
      },
      'Authentication failed.': {
        AppLanguage.en: 'Authentication failed.',
        AppLanguage.roman: 'Shanaakht nakam ho gayi.',
        AppLanguage.urdu: 'تصدیق ناکام ہو گئی۔'
      },

      'changes_saved': {AppLanguage.en: 'Changes Saved', AppLanguage.roman: 'changes saved', AppLanguage.urdu: 'تبدیلیاں محفوظ ہوگئیں'},
      'changes_saved_msg': {
        AppLanguage.en: 'Your profile details have been saved successfully.',
        AppLanguage.roman: 'Aap ki profile details kamyaabi se save ho gayi hain.',
        AppLanguage.urdu: 'آپ کی پروفائل کی تفصیلات کامیابی سے محفوظ کر لی گئی ہیں۔'
      },
      'profile_pic_updated_msg': {
        AppLanguage.en: 'Profile picture updated successfully!',
        AppLanguage.roman: 'Profile pic kamyaabi se update ho gayi!',
        AppLanguage.urdu: 'پروفائل کی تصویر کامیابی سے تبدیل کر دی گئی!'
      },
      'cnic_uploaded_msg': {
        AppLanguage.en: 'CNIC uploaded successfully!',
        AppLanguage.roman: 'CNIC kamyaabi se upload ho gaya!',
        AppLanguage.urdu: 'شناختی کارڈ کامیابی سے اپ لوڈ ہو گیا!'
      },
      'address_saved': {AppLanguage.en: 'Address Saved', AppLanguage.roman: 'Address Save ho gaya', AppLanguage.urdu: 'پتہ محفوظ ہو گیا'},
      'address_saved_msg': {
        AppLanguage.en: 'Your new address was successfully added.',
        AppLanguage.roman: 'Aap ka naya address kamyaabi se save ho gaya hai.',
        AppLanguage.urdu: 'آپ کا نیا پتہ کامیابی سے شامل کر دیا گیا ہے۔'
      },
      'address_deleted': {AppLanguage.en: 'Address Deleted', AppLanguage.roman: 'Address Delete ho gaya', AppLanguage.urdu: 'پتہ حذف ہو گیا'},
      'address_deleted_msg': {
        AppLanguage.en: 'The address has been successfully deleted.',
        AppLanguage.roman: 'Address kamyaabi se delete kar diya gaya hai.',
        AppLanguage.urdu: 'پتہ کامیابی سے حذف کر دیا گیا ہے۔'
      },
      'confirm_delete': {AppLanguage.en: 'Confirm Delete', AppLanguage.roman: 'Delete confirm karein', AppLanguage.urdu: 'حذف کرنے کی تصدیق کریں'},
      'confirm_delete_msg': {
        AppLanguage.en: 'Are you sure you want to delete this address?',
        AppLanguage.roman: 'Kya aap waqai yeh address delete karna chahte hain?',
        AppLanguage.urdu: 'کیا آپ واقعی اس پتے کو حذف کرنا چاہتے ہیں؟'
      },
      'cancel': {AppLanguage.en: 'Cancel', AppLanguage.roman: 'Cancel', AppLanguage.urdu: 'منسوخ کریں'},
      'delete': {AppLanguage.en: 'Delete', AppLanguage.roman: 'Delete', AppLanguage.urdu: 'حذف کریں'},
      'ok': {AppLanguage.en: 'OK', AppLanguage.roman: 'OK', AppLanguage.urdu: 'ٹھیک ہے'},
      'save_changes': {
        AppLanguage.en: 'Save Changes',
        AppLanguage.roman: 'Save Changes',
        AppLanguage.urdu: 'تبدیلیاں محفوظ کریں'
      },

      // Home Screen Localization
      'hi': {AppLanguage.en: 'Hi', AppLanguage.roman: 'Assalam-o-Alaikum', AppLanguage.urdu: 'السلام علیکم'},
      'how_assist': {AppLanguage.en: 'How can I assist you today?', AppLanguage.roman: 'Main aaj aap ki kya madad kar sakta hoon?', AppLanguage.urdu: 'میں آج آپ کی کیا مدد کر سکتا ہوں؟'},
      'clear_chat': {AppLanguage.en: 'Clear Chat', AppLanguage.roman: 'Chat saaf karein', AppLanguage.urdu: 'چیٹ صاف کریں'},
      'copied': {AppLanguage.en: 'Copied to clipboard', AppLanguage.roman: 'Copy ho gaya', AppLanguage.urdu: 'کاپی ہو گیا'},
      'urdu_banner': {
        AppLanguage.en: 'Do you need any help? Is the sink leaking or is the tap broken?',
        AppLanguage.roman: 'Kya aap ko kisi madad ki zaroorat hai? sink leak kar raha hai ya nal kharab ho gaya hai?',
        AppLanguage.urdu: 'کیا آپ کو کسی مدد کی ضرورت ہے؟ سنک لیک کر رہا ہے یا نل خراب ہو گیا ہے؟'
      },
      'saved_addresses_title': {AppLanguage.en: 'Saved Addresses', AppLanguage.roman: 'Saved Addresses', AppLanguage.urdu: 'محفوظ کردہ پتے'},
      'no_addresses_saved': {AppLanguage.en: 'No addresses saved yet.', AppLanguage.roman: 'Koi address save nahi hai abhi.', AppLanguage.urdu: 'ابھی تک کوئی پتہ محفوظ نہیں ہے۔'},
      'add_new_address_btn': {AppLanguage.en: 'Add New Address', AppLanguage.roman: 'Naya Address Add Karein', AppLanguage.urdu: 'نیا پتہ شامل کریں'},
      'address_details_label': {AppLanguage.en: 'Address Details', AppLanguage.roman: 'Address ki details', AppLanguage.urdu: 'پتے کی تفصیلات'},
      'label_placeholder': {AppLanguage.en: 'Label (e.g. Home, Work)', AppLanguage.roman: 'Label (jaisay Home, Work)', AppLanguage.urdu: 'لیبل (جیسے گھر، کام)'},
      'save_address_btn': {AppLanguage.en: 'Save Address', AppLanguage.roman: 'Save Address', AppLanguage.urdu: 'پتہ محفوظ کریں'},
      'set_default_popup': {AppLanguage.en: 'Set as Default', AppLanguage.roman: 'Default set karein', AppLanguage.urdu: 'ڈیفالٹ کے طور پر سیٹ کریں'},
    };

    if (!_map.containsKey(key)) return key;
    return _map[key]![state.language] ?? key;
  }
}

final localeProvider = StateNotifierProvider<AppLocaleNotifier, AppLocaleState>((ref) {
  return AppLocaleNotifier();
});
