import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/dialog_helper.dart';

class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  IconData _getIconData(String label) {
    final l = label.toLowerCase();
    if (l.contains('home') || l.contains('ghar')) return Icons.home_outlined;
    if (l.contains('work') || l.contains('office') || l.contains('daftar')) return Icons.work_outline;
    if (l.contains('parent') || l.contains('abbu') || l.contains('ammi') || l.contains('family')) return Icons.people_outline;
    return Icons.location_on_outlined;
  }

  Future<void> _deleteAddress(String label) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    
    try {
      await _db.collection('addresses').doc(user.id).collection('labels').doc(label).delete();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  void _addNewAddress() {
    final translate = ref.read(localeProvider.notifier).translate;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final labelCtrl = TextEditingController();
        final addressCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Address', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: labelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Label (e.g. Home, Office)',
                  labelStyle: TextStyle(color: Color(0xFF6B7280)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E344A))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBDB2FF))),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Address',
                  labelStyle: TextStyle(color: Color(0xFF6B7280)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2E344A))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFBDB2FF))),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (labelCtrl.text.isNotEmpty && addressCtrl.text.isNotEmpty) {
                      await _db.collection('addresses').doc(user.id).collection('labels').doc(labelCtrl.text.trim()).set({
                        'address': addressCtrl.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBDB2FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Address', style: TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = ref.watch(localeProvider).isDarkMode;
    final translate = ref.read(localeProvider.notifier).translate;

    final bgColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF9FAFB);
    final surfaceColor = isDark ? const Color(0xFF161B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Saved Addresses', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: user == null 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: _db.collection('addresses').doc(user.id).collection('labels').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No addresses saved yet.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final label = docs[index].id;
                  final data = docs[index].data() as Map<String, dynamic>;
                  final address = data['address'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF2E344A) : const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(_getIconData(label), color: const Color(0xFFBDB2FF), size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(address, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteAddress(label),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewAddress,
        backgroundColor: const Color(0xFFBDB2FF),
        icon: const Icon(Icons.add, color: Color(0xFF0A0F1D)),
        label: const Text('Add New', style: TextStyle(color: Color(0xFF0A0F1D), fontWeight: FontWeight.bold)),
      ),
    );
  }
}
