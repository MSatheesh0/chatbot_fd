import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import 'appointment_details_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/appointments'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _appointments = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load appointments');
      }
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelAppointment(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/appointments/$id/cancel'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fee = data['cancellationFee'];
        final refund = data['refundAmount'];
        
        _fetchAppointments();
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Appointment Cancelled', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your appointment has been cancelled.'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cancellation Fee (2/3):'),
                            Text('₹${fee.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Refund Amount (1/3):'),
                            Text('₹${refund.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF009688), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error cancelling: $e');
    }
  }

  Future<void> _deleteAppointment(String id) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/appointments/$id'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        setState(() {
          _appointments.removeWhere((a) => a['_id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment history deleted')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final upcoming = _appointments.where((a) {
      final date = DateTime.parse(a['date']);
      return a['status'] == 'confirmed' && date.isAfter(now);
    }).toList();

    final cancelled = _appointments.where((a) => a['status'] == 'cancelled').toList();

    final completed = _appointments.where((a) {
      final date = DateTime.parse(a['date']);
      return a['status'] == 'completed' || (a['status'] == 'confirmed' && (date.isBefore(now) || date.isAtSameMomentAs(now)));
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Appointments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Cancelled'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF009688)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentList(upcoming, 'upcoming', isDark),
                _buildAppointmentList(cancelled, 'cancelled', isDark),
                _buildAppointmentList(completed, 'completed', isDark),
              ],
            ),
    );
  }

  Widget _buildAppointmentList(List<dynamic> appointments, String type, bool isDark) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'upcoming' ? Icons.calendar_today : (type == 'cancelled' ? Icons.cancel_outlined : Icons.check_circle_outline),
                size: 60,
                color: const Color(0xFF009688).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No $type appointments',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAppointments,
      color: const Color(0xFF009688),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          final date = DateTime.parse(appointment['date']);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentDetailsScreen(appointment: appointment),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appointment['doctorName'],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF2D3142),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    appointment['hospitalName'],
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(type),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, thickness: 0.5),
                        ),
                        Row(
                          children: [
                            Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM d, yyyy').format(date),
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            ),
                            const SizedBox(width: 20),
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('h:mm a').format(date),
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (type == 'upcoming')
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showCancelConfirmation(appointment['_id']),
                                  icon: const Icon(Icons.cancel, size: 18),
                                  label: const Text('Cancel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFEBEE),
                                    foregroundColor: const Color(0xFFD32F2F),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            if (type == 'upcoming') const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showDeleteConfirmation(appointment['_id']),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[600],
                                  side: BorderSide(color: Colors.grey[300]!),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String type) {
    Color color;
    String label;
    Color bgColor;
    
    switch (type) {
      case 'upcoming':
        color = const Color(0xFF2196F3);
        bgColor = const Color(0xFFE3F2FD);
        label = 'Upcoming';
        break;
      case 'cancelled':
        color = const Color(0xFFD32F2F);
        bgColor = const Color(0xFFFFEBEE);
        label = 'Cancelled';
        break;
      case 'completed':
        color = const Color(0xFF388E3C);
        bgColor = const Color(0xFFE8F5E9);
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        bgColor = Colors.grey[100]!;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  void _showCancelConfirmation(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Appointment?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'A cancellation fee of 2/3 of the total amount will be charged. You will receive a 1/3 refund.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep it', style: TextStyle(color: Color(0xFF009688), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelAppointment(id);
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete History?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will permanently remove this appointment from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF009688))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAppointment(id);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
