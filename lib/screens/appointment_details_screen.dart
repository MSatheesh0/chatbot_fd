import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AppointmentDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailsScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateTime.parse(appointment['date']);
    final qrData = appointment['qrCodeData'];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(appointment['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _getStatusColor(appointment['status']).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(appointment['status']),
                    color: _getStatusColor(appointment['status']),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Status: ${appointment['status'].toString().toUpperCase()}',
                    style: TextStyle(
                      color: _getStatusColor(appointment['status']),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Doctor Details
            _buildSectionTitle('Doctor Details', isDark),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildRow('Doctor Name', appointment['doctorName']),
              const Divider(height: 1),
              _buildRow('Hospital', appointment['hospitalName']),
            ], isDark),
            const SizedBox(height: 24),

            // Appointment Info
            _buildSectionTitle('Appointment Info', isDark),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildRow('Date', DateFormat('MMM d, yyyy').format(date)),
              const Divider(height: 1),
              _buildRow('Time', DateFormat('h:mm a').format(date)),
              const Divider(height: 1),
              _buildRow('Booking ID', appointment['_id'].toString().substring(0, 8).toUpperCase()),
            ], isDark),
            const SizedBox(height: 24),

            // Payment Info
            _buildSectionTitle('Payment Info', isDark),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildRow('Amount Paid', '₹${appointment['amount']}'),
              const Divider(height: 1),
              _buildRow('Payment ID', appointment['paymentId'] ?? 'N/A'),
              const Divider(height: 1),
              _buildRow('Payment Method', 'Online (Stripe/UPI)'),
            ], isDark),
            const SizedBox(height: 32),

            // QR Code Section
            Center(
              child: Column(
                children: [
                  Text(
                    'Scan for Entry',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData ?? 'No Data',
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _downloadQrCode(context, qrData),
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009688),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () => _shareQrCode(context, qrData),
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF009688),
                          side: const BorderSide(color: Color(0xFF009688)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18, 
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF2D3142),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: children),
      ),
    );
  }

  Future<void> _shareQrCode(BuildContext context, String? qrData) async {
    if (qrData == null) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing not supported on Web')),
      );
      return;
    }
    try {
      final image = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      ).toImage(875);
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await file.writeAsBytes(buffer);

      await Share.shareXFiles([XFile(file.path)], text: 'My Appointment QR Code');
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share QR code: $e')),
        );
      }
    }
  }

  Future<void> _downloadQrCode(BuildContext context, String? qrData) async {
    if (qrData == null) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading not supported on Web')),
      );
      return;
    }
    try {
      final image = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      ).toImage(875);
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/appointment_qr.png').create();
      await file.writeAsBytes(buffer);

      await Share.shareXFiles([XFile(file.path)], text: 'Save this QR Code');

    } catch (e) {
      debugPrint('Error downloading QR code: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download QR code: $e')),
        );
      }
    }
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.task_alt;
      default:
        return Icons.info;
    }
  }
}
