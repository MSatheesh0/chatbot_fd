import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../constants.dart';
import 'booking_success_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String hospitalName;
  final int amount;
  final DateTime appointmentDate;

  const PaymentScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.hospitalName,
    required this.amount,
    required this.appointmentDate,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isProcessing = false;
  String _selectedMethod = 'stripe'; // Default to stripe

  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadStripeKey();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/auth/profile'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _userProfile = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _loadStripeKey() async {
    final key = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    if (key != null) {
      Stripe.publishableKey = key;
    }
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Get Client Secret from Backend
      final clientSecret = await _createPaymentIntent();

      if (clientSecret == null) {
        throw Exception('Failed to get client secret');
      }

      // 2. Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Mental Health App',
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            name: _userProfile?['username'] ?? '',
            email: _userProfile?['email'] ?? '',
            phone: _userProfile?['phone'] ?? '',
            address: const Address(
              country: 'IN',
              city: 'India',
              line1: '',
              line2: '',
              postalCode: '',
              state: '',
            ),
          ),
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF06B6D4),
            ),
          ),
        ),
      );

      // 3. Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. On Success, Verify with Backend & Create Appointment
      await _handlePaymentSuccess(clientSecret);

    } on StripeException catch (e) {
      debugPrint('Stripe Error: ${e.error.localizedMessage}');
      _showErrorSnackBar('Payment cancelled or failed: ${e.error.localizedMessage}');
    } catch (e) {
      debugPrint('Error processing payment: $e');
      _showErrorSnackBar('An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<String?> _createPaymentIntent() async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/payments/create-intent'),
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? '',
      },
      body: jsonEncode({
        'amount': widget.amount,
        'metadata': {
          'doctorId': widget.doctorId,
          'doctorName': widget.doctorName,
          'hospitalName': widget.hospitalName,
          'appointmentDate': widget.appointmentDate.toIso8601String(),
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['clientSecret'];
    } else {
      debugPrint('Create Intent Failed: ${response.body}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Error: ${response.body}')),
        );
      }
      return null;
    }
  }

  Future<void> _handlePaymentSuccess(String clientSecret) async {
    // Verify payment status on backend (optional but recommended)
    // Extract paymentIntentId from clientSecret (pi_..._secret_...)
    final paymentIntentId = clientSecret.split('_secret_')[0];
    
    final token = await _storage.read(key: 'jwt_token');
    final verifyResponse = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/payments/verify'),
      headers: {
        'Content-Type': 'application/json',
        'x-auth-token': token ?? '',
      },
      body: jsonEncode({
        'paymentIntentId': paymentIntentId,
      }),
    );

    if (verifyResponse.statusCode == 200) {
      final verifyData = jsonDecode(verifyResponse.body);
      
      if (verifyData['status'] == 'succeeded') {
        // Backend should have created the appointment now
        final appointment = verifyData['appointment'];
        
        if (appointment != null) {
          if (!mounted) return;
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BookingSuccessScreen(
                doctorName: widget.doctorName,
                hospitalName: widget.hospitalName,
                appointmentId: appointment['_id'],
                date: DateFormat('MMM d, yyyy - h:mm a').format(DateTime.parse(appointment['createdAt'] ?? DateTime.now().toIso8601String())),
                qrData: appointment['qrCodeData'],
                appointmentDate: widget.appointmentDate,
              ),
            ),
          );
        } else {
           _showErrorSnackBar('Payment successful, but appointment details missing. Please check My Bookings.');
        }
      } else {
        _showErrorSnackBar('Payment verification failed. Status: ${verifyData['status']}');
      }
    } else {
      _showErrorSnackBar('Failed to verify payment with server.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: isDark ? Colors.black : const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : const Color(0xFFCFFAFE),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 30),
                      _buildSummaryRow('Doctor', widget.doctorName),
                      const SizedBox(height: 10),
                      _buildSummaryRow('Hospital', widget.hospitalName),
                      const SizedBox(height: 10),
                      _buildSummaryRow('Consultation Fee', '₹${widget.amount}'),
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${widget.amount}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF06B6D4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              const Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              // Payment Methods
              _buildPaymentMethodOption(
                id: 'stripe',
                title: 'Pay Online (UPI, Card, NetBanking)',
                icon: Icons.payment,
                isDark: isDark,
              ),
              
              const SizedBox(height: 15),
              
              const Text(
                'Secured by Stripe',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

              const Spacer(),

              // Pay Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: _isProcessing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Processing...', style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : Text(
                          'Pay ₹${widget.amount}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption({
    required String id,
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedMethod == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF06B6D4).withOpacity(0.1)
              : (isDark ? Colors.grey[800] : Colors.white),
          border: Border.all(
            color: isSelected ? const Color(0xFF06B6D4) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isDark && !isSelected)
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF06B6D4) : Colors.grey),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF06B6D4)
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF06B6D4)),
          ],
        ),
      ),
    );
  }
}
