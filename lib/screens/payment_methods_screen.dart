import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final List<Map<String, dynamic>> _methods = [
    {
      'id': '1',
      'type': 'Visa',
      'number': '**** **** **** 4892',
      'expiry': '12/28',
      'holder': 'CLARA CUSTOMER',
      'isDefault': true,
      'gradient': [Color(0xFF80C2FF), Color(0xFF4F46E5)],
    },
    {
      'id': '2',
      'type': 'NayaPay',
      'number': '0300-1234567',
      'expiry': 'N/A',
      'holder': 'CLARA CUSTOMER',
      'isDefault': false,
      'gradient': [Color(0xFFFFA2F2), Color(0xFFEC4899)],
    },
    {
      'id': '3',
      'type': 'Cash on Delivery',
      'number': 'Pay after work completion',
      'expiry': 'N/A',
      'holder': '',
      'isDefault': false,
      'gradient': [Color(0xFFBDB2FF), Color(0xFF10B981)],
    },
  ];

  static const Color _kBackgroundColor = Color(0xFF0A0F1D);
  static const Color _kSurfaceColor = Color(0xFF161B2E);
  static const Color _kPrimaryPurple = Color(0xFFBDB2FF);
  static const Color _kInputBorderColor = Color(0xFF2E344A);
  static const Color _kHintTextColor = Color(0xFF6B7280);

  void _addNewMethod() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final cardCtrl = TextEditingController();
        final holderCtrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Visa/Mastercard',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: holderCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cardholder Name',
                  labelStyle: const TextStyle(color: _kHintTextColor),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kInputBorderColor)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _kPrimaryPurple)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cardCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  labelStyle: const TextStyle(color: _kHintTextColor),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kInputBorderColor)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _kPrimaryPurple)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (holderCtrl.text.isNotEmpty && cardCtrl.text.isNotEmpty) {
                      setState(() {
                        _methods.insert(0, {
                          'id': DateTime.now().toString(),
                          'type': 'Visa',
                          'number': '**** **** **** ${cardCtrl.text.substring(cardCtrl.text.length - 4)}',
                          'expiry': '05/30',
                          'holder': holderCtrl.text.toUpperCase(),
                          'isDefault': false,
                          'gradient': [Color(0xFF80C2FF), Color(0xFF8B5CF6)],
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryPurple,
                    foregroundColor: _kBackgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add Card', style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Payment Methods', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _methods.length,
                itemBuilder: (context, index) {
                  final method = _methods[index];
                  final List<Color> colors = method['gradient'] as List<Color>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(24),
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colors.last.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              method['type'] as String,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                            ),
                            if (method['isDefault'] as bool)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('PRIMARY', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        Text(
                          method['number'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CARD HOLDER', style: TextStyle(color: Colors.white60, fontSize: 8)),
                                const SizedBox(height: 4),
                                Text(
                                  method['holder'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (method['expiry'] != 'N/A')
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('EXPIRES', style: TextStyle(color: Colors.white60, fontSize: 8)),
                                  const SizedBox(height: 4),
                                  Text(
                                    method['expiry'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addNewMethod,
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Add Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryPurple,
                    foregroundColor: _kBackgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
