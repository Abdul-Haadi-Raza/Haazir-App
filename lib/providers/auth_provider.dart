import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
export '../models/user_model.dart';

class GoogleAuthResult {
  final bool needsDetails;
  final String email;
  final String? name;
  final String? role;

  GoogleAuthResult({
    required this.needsDetails,
    required this.email,
    this.name,
    this.role,
  });
}

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isInitialized;
  final String? verificationId;
  final String? profileImageUrl;
  
  bool get isAuthenticated => user != null;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isInitialized = false,
    this.verificationId,
    this.profileImageUrl,
  });

  AuthState copyWith({
    UserModel? user, 
    bool? isLoading, 
    bool? isInitialized,
    String? verificationId,
    String? profileImageUrl,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      verificationId: verificationId ?? this.verificationId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  AuthState logoutState() {
    return AuthState(
      user: null,
      isLoading: false,
      isInitialized: isInitialized,
      verificationId: null,
      profileImageUrl: null,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() async {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final lastActiveStr = prefs.getString('lastActiveTime');
          if (lastActiveStr != null) {
            final lastActive = DateTime.tryParse(lastActiveStr);
            if (lastActive != null) {
              final diff = DateTime.now().difference(lastActive).inDays;
              if (diff >= 90) {
                await logout();
                await prefs.remove('lastActiveTime');
                return;
              }
            }
          }
          await prefs.setString('lastActiveTime', DateTime.now().toIso8601String());
        } catch (e) {
          debugPrint("Error checking inactivity logout: $e");
        }

        final doc = await _db.collection('Users').doc(firebaseUser.uid).get();
        if (doc.exists) {
          final data = doc.data();
          List<Map<String, dynamic>> savedAddresses = [];
          if (data?['saved_addresses'] != null) {
            savedAddresses = List<Map<String, dynamic>>.from(data!['saved_addresses']);
          } else if (data?['address'] != null && (data?['address'] as String).isNotEmpty) {
            savedAddresses = [
              {
                'id': 'signup_home',
                'label': 'Home',
                'icon': 'home',
                'address': data?['address'],
                'isDefault': true,
              }
            ];
            _db.collection('Users').doc(firebaseUser.uid).update({
              'saved_addresses': savedAddresses
            });
          }

          state = state.copyWith(
            user: UserModel(
              id: firebaseUser.uid,
              phone: data?['phone'] ?? '',
              name: data?['name'] ?? '',
              role: data?['role'] ?? 'customer',
              address: data?['address'],
              pinnedLocation: data?['pinnedLocation'],
              profileImageUrl: data?['profileImageUrl'],
              cnic: data?['cnic'],
              cnicUrl: data?['cnic_url'],
              savedAddresses: savedAddresses,
            ),
            profileImageUrl: data?['profileImageUrl'],
            isInitialized: true,
          );
        } else {
          state = state.copyWith(isInitialized: true);
        }
      } else {
        state = state.logoutState().copyWith(isInitialized: true);
      }
    });
  }

  Future<void> updateProfile({
    required String name,
    required String address,
    required String pinnedLocation,
  }) async {
    if (state.user == null) return;
    
    state = state.copyWith(isLoading: true);
    try {
      final uid = state.user!.id;
      final updates = {
        'name': name,
        'address': address,
        'pinnedLocation': pinnedLocation,
      };
      
      // Update Firestore
      await _db.collection('Users').doc(uid).update(updates);
      
      if (state.user!.role == 'provider') {
        await _db.collection('ProviderProfiles').doc(uid).update(updates);
      }
      
      // Sync update with Firebase Authentication
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(name);
      }
      
      state = state.copyWith(
        user: state.user!.copyWith(
          name: name,
          address: address,
          pinnedLocation: pinnedLocation,
        ),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception("Failed to update profile: $e");
    }
  }

  Future<void> uploadProfilePicture(File imageFile) async {
    if (state.user == null) return;
    
    state = state.copyWith(isLoading: true);
    try {
      final sanitizedPhone = state.user!.phone.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final identifier = sanitizedPhone.isNotEmpty ? sanitizedPhone : state.user!.id;
      final ref = _storage.ref().child('profile_pictures').child('${identifier}.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      
      await _db.collection('Users').doc(state.user!.id).update({'profileImageUrl': url});
      if (state.user!.role == 'provider') {
        await _db.collection('ProviderProfiles').doc(state.user!.id).update({'profileImageUrl': url});
      }
      
      state = state.copyWith(
        profileImageUrl: url,
        user: state.user!.copyWith(profileImageUrl: url),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception("Failed to upload image: $e");
    }
  }

  // Step 1: Verify Phone Number & Send OTP (Simulated for PIN flow)
  Future<void> sendOTP(String phone, Function(String) onCodeSent) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(seconds: 1));
    state = state.copyWith(isLoading: false, verificationId: "simulated_id");
    onCodeSent("simulated_id");
  }

  // Step 2: Verify OTP & Complete Signup/Login (Expected by OTP Screen)
  Future<void> verifyOTPAndComplete({
    required String smsCode,
    required String name,
    required String phone,
    required String role,
    Map<String, dynamic>? extraData,
  }) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(seconds: 1));
    
    // For simplicity, any 6-digit code works in simulation
    if (smsCode.length != 6) {
      state = state.copyWith(isLoading: false);
      throw Exception("Invalid OTP. Please enter 6 digits.");
    }

    // Since we are using PIN flow, we'll use a default PIN for this simulated account
    await signup(
      name: name,
      phone: phone,
      pin: "1234", // Default PIN for OTP-verified users
      role: role,
      extraData: extraData,
    );
    
    state = state.copyWith(isLoading: false);
  }

  Future<void> login(String phone, String pin) async {
    state = state.copyWith(isLoading: true);
    try {
      final email = "${phone.replaceAll(' ', '').replaceAll('+', '')}@haazir.com";
      // Firebase requires at least 6 characters for passwords, so we pad it.
      final password = pin.padRight(6, '0');
      
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastActiveTime', DateTime.now().toIso8601String());
      } catch (e) {
        debugPrint("Error writing login timestamp: $e");
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception(_handleAuthError(e));
    }
  }

  Future<void> signup({
    required String name,
    required String phone,
    required String pin,
    required String role,
    Map<String, dynamic>? extraData,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final email = "${phone.replaceAll(' ', '').replaceAll('+', '')}@haazir.com";
      final password = pin.padRight(6, '0');
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastActiveTime', DateTime.now().toIso8601String());
      } catch (e) {
        debugPrint("Error writing signup timestamp: $e");
      }

      final uid = result.user!.uid;
      
      final address = extraData != null ? extraData['address'] : null;
      List<Map<String, dynamic>> savedAddresses = [];
      if (address != null && (address as String).isNotEmpty) {
        savedAddresses = [
          {
            'id': 'signup_home',
            'label': 'Home',
            'icon': 'home',
            'address': address,
            'isDefault': true,
          }
        ];
      }

      final userData = {
        'uid': uid,
        'name': name,
        'phone': phone,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        if (savedAddresses.isNotEmpty) 'saved_addresses': savedAddresses,
        ...?extraData,
      };

      await _db.collection('Users').doc(uid).set(userData);

      // Save initial address to the new hierarchical 'addresses' table
      if (address != null && (address as String).isNotEmpty) {
        await _db.collection('addresses').doc(uid).collection('labels').doc('Home').set({
          'address': address,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (role == 'provider') {
        await _db.collection('ProviderProfiles').doc(uid).set({
          ...userData,
          'rating': 4.0,
          'total_jobs': 0,
          'is_verified': false,
        });
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception(_handleAuthError(e));
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // Robust fallback if Firebase Auth is not accessible or offline
      // debugPrint is always available in Flutter
    }
    state = state.logoutState();
  }

  Future<GoogleAuthResult?> signInWithGoogle(BuildContext context, {String? defaultRole}) async {
    state = state.copyWith(isLoading: true);
    try {
      // Show Google Account Chooser Dialog
      final selectedAccount = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return const _GoogleAccountChooserDialog();
        },
      );

      if (selectedAccount == null) {
        state = state.copyWith(isLoading: false);
        return null; // User cancelled
      }

      final email = selectedAccount['email']!.trim().toLowerCase();
      final displayName = selectedAccount['name']!.trim();

      // Attempt to sign in via Firebase Auth under the hood using a mock password
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: "google_password_mock_123456",
        );
        
        final uid = credential.user!.uid;
        final doc = await _db.collection('Users').doc(uid).get();
        
        if (doc.exists) {
          final data = doc.data()!;
          List<Map<String, dynamic>> savedAddresses = [];
          if (data['saved_addresses'] != null) {
            savedAddresses = List<Map<String, dynamic>>.from(data['saved_addresses']);
          } else if (data['address'] != null && (data['address'] as String).isNotEmpty) {
            savedAddresses = [
              {
                'id': 'signup_home',
                'label': 'Home',
                'icon': 'home',
                'address': data['address'],
                'isDefault': true,
              }
            ];
            _db.collection('Users').doc(uid).update({
              'saved_addresses': savedAddresses
            });
          }

          state = state.copyWith(
            user: UserModel(
              id: uid,
              name: data['name'] ?? '',
              phone: data['phone'] ?? '',
              role: data['role'] ?? 'customer',
              address: data['address'],
              pinnedLocation: data['pinnedLocation'],
              profileImageUrl: data['profileImageUrl'],
              cnic: data['cnic'],
              cnicUrl: data['cnic_url'],
              savedAddresses: savedAddresses,
            ),
            profileImageUrl: data['profileImageUrl'],
            isLoading: false,
            isInitialized: true,
          );

          return GoogleAuthResult(
            needsDetails: false,
            email: email,
            name: data['name'],
            role: data['role'],
          );
        } else {
          // Firebase Auth account exists but Firestore doc doesn't (rare case).
          // Treat as needing details.
          state = state.copyWith(isLoading: false);
          return GoogleAuthResult(
            needsDetails: true,
            email: email,
            name: displayName,
            role: defaultRole,
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
          // User does not exist in Firebase Auth yet.
          // Let them go to google details to complete registration.
          state = state.copyWith(isLoading: false);
          return GoogleAuthResult(
            needsDetails: true,
            email: email,
            name: displayName,
            role: defaultRole,
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Google Sign-In Failed: ${_handleAuthError(e)}")),
        );
      }
      return null;
    }
  }

  Future<void> completeGoogleSignup({
    required String email,
    required String name,
    required String phone,
    required String role,
    required Map<String, dynamic> extraData,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      UserCredential credential;
      try {
        // Try creating standard Firebase Auth user under the hood
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: "google_password_mock_123456",
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Already in Firebase Auth, sign in
          credential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: "google_password_mock_123456",
          );
        } else {
          rethrow;
        }
      }

      final uid = credential.user!.uid;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastActiveTime', DateTime.now().toIso8601String());
      } catch (e) {
        debugPrint("Error writing Google login timestamp: $e");
      }

      final address = extraData != null ? extraData['address'] : null;
      List<Map<String, dynamic>> savedAddresses = [];
      if (address != null && (address as String).isNotEmpty) {
        savedAddresses = [
          {
            'id': 'signup_home',
            'label': 'Home',
            'icon': 'home',
            'address': address,
            'isDefault': true,
          }
        ];
      }

      final userData = {
        'uid': uid,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        if (savedAddresses.isNotEmpty) 'saved_addresses': savedAddresses,
        ...extraData,
      };

      await _db.collection('Users').doc(uid).set(userData);

      // Save initial address to the new hierarchical 'addresses' table
      if (address != null && (address as String).isNotEmpty) {
        await _db.collection('addresses').doc(uid).collection('labels').doc('Home').set({
          'address': address,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (role == 'provider') {
        await _db.collection('ProviderProfiles').doc(uid).set({
          ...userData,
          'rating': 4.0,
          'total_jobs': 0,
          'is_verified': false,
        });
      }

      state = state.copyWith(
        user: UserModel(
          id: uid,
          name: name,
          phone: phone,
          role: role,
          address: extraData != null ? extraData['address'] : null,
          pinnedLocation: extraData != null ? extraData['pinnedLocation'] : null,
          profileImageUrl: extraData != null ? extraData['profileImageUrl'] : null,
          cnic: extraData != null ? extraData['cnic'] : null,
          cnicUrl: extraData != null ? extraData['cnic_url'] : null,
          savedAddresses: savedAddresses,
        ),
        profileImageUrl: extraData != null ? extraData['profileImageUrl'] : null,
        isLoading: false,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception("Failed to complete Google registration: $e");
    }
  }

  Future<void> updateSavedAddresses(List<Map<String, dynamic>> addresses) async {
    if (state.user == null) return;
    try {
      final uid = state.user!.id;
      await _db.collection('Users').doc(uid).update({
        'saved_addresses': addresses
      });
      state = state.copyWith(
        user: state.user!.copyWith(savedAddresses: addresses),
      );
    } catch (e) {
      debugPrint("Error updating saved addresses: $e");
      throw Exception("Failed to update saved addresses: $e");
    }
  }

  Future<void> uploadCnicPicture(File imageFile) async {
    if (state.user == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final sanitizedPhone = state.user!.phone.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final identifier = sanitizedPhone.isNotEmpty ? sanitizedPhone : state.user!.id;
      final ref = _storage.ref().child('cnic_pictures').child('${identifier}.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      
      await _db.collection('Users').doc(state.user!.id).update({'cnic_url': url});
      if (state.user!.role == 'provider') {
        await _db.collection('ProviderProfiles').doc(state.user!.id).update({'cnic_url': url});
      }
      
      state = state.copyWith(
        user: state.user!.copyWith(cnicUrl: url),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      throw Exception("Failed to upload CNIC image: $e");
    }
  }

  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'No user found with this phone number.';
        case 'wrong-password': return 'Incorrect PIN.';
        case 'email-already-in-use': return 'This phone number is already registered.';
        case 'weak-password': return 'PIN must be at least 4 digits.';
        case 'invalid-email': return 'Invalid phone number format.';
        default: return e.message ?? 'Authentication failed.';
      }
    }
    return e.toString();
  }
}

class _GoogleAccountChooserDialog extends StatefulWidget {
  const _GoogleAccountChooserDialog();

  @override
  State<_GoogleAccountChooserDialog> createState() => _GoogleAccountChooserDialogState();
}

class _GoogleAccountChooserDialogState extends State<_GoogleAccountChooserDialog> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _showCustomInput = false;

  final List<Map<String, String>> _mockAccounts = [
    {
      'name': 'Clara Customer',
      'email': 'clara.customer@gmail.com',
      'avatar': 'C',
      'color': '0xFF80C2FF'
    },
    {
      'name': 'Peter Plumber',
      'email': 'peter.plumber@gmail.com',
      'avatar': 'P',
      'color': '0xFFBDB2FF'
    },
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Center(
        child: Container(
          width: 340,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2E344A)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Google Accounts',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose an account to continue to Haazir',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!_showCustomInput) ...[
                  ..._mockAccounts.map((acc) {
                    final color = Color(int.parse(acc['color']!));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0F1D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2E344A)),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop({
                            'name': acc['name']!,
                            'email': acc['email']!,
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withOpacity(0.2),
                                child: Text(
                                  acc['avatar']!,
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc['name']!,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      acc['email']!,
                                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showCustomInput = true;
                      });
                    },
                    child: const Text(
                      'Use another account',
                      style: TextStyle(color: Color(0xFFBDB2FF), fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6B7280)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2E344A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFBDB2FF)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0F1D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Email Address',
                      hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6B7280)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2E344A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFBDB2FF)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0F1D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showCustomInput = false;
                          });
                        },
                        child: const Text('Back', style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_emailCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill name and email')),
                            );
                            return;
                          }
                          Navigator.of(context).pop({
                            'name': _nameCtrl.text.trim(),
                            'email': _emailCtrl.text.trim(),
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBDB2FF),
                          foregroundColor: const Color(0xFF0A0F1D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
