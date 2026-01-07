import 'package:flutter/material.dart';
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
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFE0F2F1),
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: isDark ? Colors.black : const Color(0xFF009688),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _getStatusColor(appointment['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _getStatusColor(appointment['status'])),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(appointment['status']),
                    color: _getStatusColor(appointment['status']),
                  ),
                  const SizedBox(width: 10),
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
            const SizedBox(height: 20),

            // Doctor Details
            const Text(
              'Doctor Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _buildRow('Doctor Name', appointment['doctorName']),
                    const Divider(),
                    _buildRow('Hospital', appointment['hospitalName']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Appointment Info
            const Text(
              'Appointment Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _buildRow('Date', DateFormat('MMM d, yyyy').format(date)),
                    const Divider(),
                    _buildRow('Time', DateFormat('h:mm a').format(date)),
                    const Divider(),
                    _buildRow('Booking ID', appointment['_id'].toString().substring(0, 8).toUpperCase()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Info
            const Text(
              'Payment Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _buildRow('Amount Paid', '₹${appointment['amount']}'),
                    const Divider(),
                    _buildRow('Payment ID', appointment['paymentId'] ?? 'N/A'),
                    const Divider(),
                    _buildRow('Payment Method', 'Online (Stripe/UPI)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // QR Code Section
            Center(
              child: Column(
                children: [
                  const Text(
                    'Scan for Entry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData ?? 'No Data',
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        ),
                      ),
                      const SizedBox(width: 20),
                      OutlinedButton.icon(
                        onPressed: () => _shareQrCode(context, qrData),
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _shareQrCode(BuildContext context, String? qrData) async {
    if (qrData == null) return;
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
