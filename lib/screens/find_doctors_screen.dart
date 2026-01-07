import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';
import '../utils/indian_locations.dart';
import 'doctor_chatbot_screen.dart';
import 'book_appointment_screen.dart';

class FindDoctorsScreen extends StatefulWidget {
  const FindDoctorsScreen({super.key});

  @override
  State<FindDoctorsScreen> createState() => _FindDoctorsScreenState();
}

class _FindDoctorsScreenState extends State<FindDoctorsScreen> {
  List<dynamic> _doctors = [];
  bool _isLoading = false;
  bool _showMap = true;
  LatLng? _userLocation;
  String? _errorMessage;
  bool _permissionAsked = false;
  String? _selectedLocationName;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Show location options dialog immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationOptionsDialog();
    });
  }

  Future<void> _showLocationOptionsDialog() async {
    if (_permissionAsked) return;
    _permissionAsked = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Choose Location Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you like to find nearby doctors?'),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.my_location, color: Colors.blue),
              title: const Text('Use My Current Location'),
              subtitle: const Text('Auto-detect via GPS'),
              onTap: () => Navigator.pop(context, 'gps'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_city, color: Colors.green),
              title: const Text('Enter Location Manually'),
              subtitle: const Text('Select your city'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );

    if (result == 'gps') {
      await _useGPSLocation();
    } else if (result == 'manual') {
      await _showCitySelectionDialog();
    }
  }

  Future<void> _useGPSLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please select city manually.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        await _showCitySelectionDialog();
        return;
      }

      // Get user location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      await _fetchNearbyDoctors(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting GPS location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get GPS location. Please select city manually.'),
            duration: Duration(seconds: 3),
          ),
        );
        await _showCitySelectionDialog();
      }
    }
  }

  Future<void> _showCitySelectionDialog() async {
    // Step 1: Select State
    final state = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your State'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: IndianLocations.getStates().length,
            itemBuilder: (context, index) {
              final stateName = IndianLocations.getStates()[index];
              return ListTile(
                leading: const Icon(Icons.location_city, color: Color(0xFF6A11CB)),
                title: Text(stateName),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.pop(context, stateName),
              );
            },
          ),
        ),
      ),
    );

    if (state == null) {
      // If user cancels, show dialog again
      await _showLocationOptionsDialog();
      return;
    }

    // Step 2: Select City in the chosen state
    final cities = IndianLocations.getCitiesForState(state);
    final city = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select City in $state'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cities.length,
            itemBuilder: (context, index) {
              final cityName = cities[index];
              return ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFF6A11CB)),
                title: Text(cityName),
                onTap: () => Navigator.pop(context, cityName),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
        ],
      ),
    );

    if (city != null) {
      final coords = IndianLocations.getCoordinates(state, city)!;
      setState(() {
        _userLocation = coords;
        _selectedLocationName = '$city, $state';
      });
      await _fetchNearbyDoctors(coords.latitude, coords.longitude);
    } else {
      // If user cancels, show state selection again
      await _showCitySelectionDialog();
    }
  }

  Future<void> _fetchNearbyDoctors(double lat, double lng) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/doctors/nearby?'
          'lat=$lat&'
          'lng=$lng&'
          'radius=50000', // 50km radius
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _doctors = jsonDecode(response.body);
          _isLoading = false;
          _showMap = true; // Always show map after getting location
        });
      } else {
        throw Exception('Failed to load doctors');
      }
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
      setState(() {
        _errorMessage = 'Could not load doctors. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: SettingsService().locale,
          builder: (context, locale, _) {
            return Text(AppLocalizations.of(context).translate('find_doctors_title'));
          },
        ),
        backgroundColor: isDark ? Colors.black : const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_userLocation != null)
            IconButton(
              icon: Icon(_showMap ? Icons.list : Icons.map),
              onPressed: () {
                setState(() => _showMap = !_showMap);
              },
              tooltip: _showMap ? 'List View' : 'Map View',
            ),
          IconButton(
            icon: const Icon(Icons.location_searching),
            onPressed: () {
              _permissionAsked = false;
              _showLocationOptionsDialog();
            },
            tooltip: 'Change Location',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          final l10n = AppLocalizations.of(context);
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : const Color(0xFFCFFAFE),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                if (_userLocation != null) {
                                  _fetchNearbyDoctors(_userLocation!.latitude, _userLocation!.longitude);
                                } else {
                                  _showLocationOptionsDialog();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF6A11CB),
                              ),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                : _userLocation == null
                    ? _buildWelcomeScreen()
                    : _doctors.isEmpty
                        ? _buildNoDoctorsScreen(l10n)
                        : _showMap
                            ? _buildMapView(l10n)
                            : _buildListView(l10n, isDark),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_searching,
              size: 100,
              color: Colors.white70,
            ),
            const SizedBox(height: 24),
            const Text(
              'Find Nearby Psychiatrists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose how to find doctors near you',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _permissionAsked = false;
                _showLocationOptionsDialog();
              },
              icon: const Icon(Icons.search),
              label: const Text('Get Started'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6A11CB),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDoctorsScreen(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'No doctors found nearby',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try selecting a different location',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _permissionAsked = false;
                _showLocationOptionsDialog();
              },
              icon: const Icon(Icons.location_searching),
              label: const Text('Change Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6A11CB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(AppLocalizations l10n) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation!,
            initialZoom: 13.0,
            minZoom: 10.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mentalhealth',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _userLocation!,
                  width: 80,
                  height: 80,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            MarkerLayer(
              markers: _doctors.map((doctor) {
                final coords = doctor['location']['coordinates'];
                final point = LatLng(coords[1], coords[0]);

                return Marker(
                  point: point,
                  width: 100,
                  height: 100,
                  child: GestureDetector(
                    onTap: () => _showDoctorBottomSheet(doctor),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            doctor['name'].split(' ').last,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.local_hospital,
                          color: Colors.red,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_hospital, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_doctors.length} Psychiatrists Nearby',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedLocationName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A11CB),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _selectedLocationName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListView(AppLocalizations l10n, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF06B6D4),
              child: Text(
                doctor['name'][0],
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            title: Text(
              doctor['name'],
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor['specialty'], style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${doctor['rating']} • ${doctor['experience']} ${l10n.translate('yrs_exp')}',
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                if (doctor['distance'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${doctor['distance'].toStringAsFixed(1)} km away',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DoctorProfileScreen(doctor: doctor),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : const Color(0xFF06B6D4),
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(l10n.translate('view')),
            ),
          ),
        );
      },
    );
  }

  void _showDoctorBottomSheet(Map<String, dynamic> doctor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF06B6D4),
                    child: Text(
                      doctor['name'][0],
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(doctor['specialty'] ?? 'Psychiatrist'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      Text('${doctor['rating']}'),
                    ],
                  ),
                  if (doctor['consultationFee'] != null)
                    Column(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.green),
                        Text('₹${doctor['consultationFee']}'),
                      ],
                    ),
                  if (doctor['distance'] != null)
                    Column(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        Text('${doctor['distance'].toStringAsFixed(1)} km'),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorProfileScreen(doctor: doctor),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'View Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DoctorProfileScreen extends StatelessWidget {
  final dynamic doctor;
  const DoctorProfileScreen({super.key, required this.doctor});

  String _formatAvailability() {
    try {
      if (doctor['availability'] == null) {
        return 'Contact for availability';
      }

      final availability = doctor['availability'] as List;
      if (availability.isEmpty) {
        return 'Contact for availability';
      }

      // Format availability nicely
      List<String> formattedDays = [];
      for (var dayData in availability) {
        if (dayData is Map) {
          final day = dayData['day'] ?? '';
          final slots = dayData['slots'] as List? ?? [];
          
          if (slots.isNotEmpty) {
            final timeRanges = slots.map((slot) {
              if (slot is Map) {
                return '${slot['start']}-${slot['end']}';
              }
              return '';
            }).where((s) => s.isNotEmpty).join(', ');
            
            if (timeRanges.isNotEmpty) {
              formattedDays.add('$day: $timeRanges');
            }
          }
        }
      }

      return formattedDays.isEmpty 
          ? 'Contact for availability' 
          : formattedDays.join('\n');
    } catch (e) {
      return 'Contact for availability';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(doctor['name']),
        backgroundColor: isDark ? Colors.black : const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          final l10n = AppLocalizations.of(context);
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.black : const Color(0xFFCFFAFE),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: isDark ? Colors.white24 : const Color(0xFF06B6D4),
                        child: const Icon(Icons.person, size: 80, color: Colors.white),
                      ),
                    const SizedBox(height: 24),
                      Text(
                        doctor['name'],
                        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 8),
                      Text(
                        doctor['specialty'] ?? 'Psychiatrist',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 20),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildInfoChip(context, Icons.star, '${doctor['rating']} Rating'),
                        const SizedBox(width: 12),
                        _buildInfoChip(context, Icons.work, '${doctor['experience']} Yrs'),
                      ],
                    ),
                    if (doctor['consultationFee'] != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoChip(context, Icons.attach_money, '₹${doctor['consultationFee']} Fee'),
                    ],
                    const SizedBox(height: 30),
                    
                    // Hospital Information
                    if (doctor['hospital'] != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isDark ? null : [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_hospital, color: isDark ? Colors.white70 : const Color(0xFF06B6D4), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Hospital',
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              doctor['hospital']['name'] ?? 'N/A',
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on, color: isDark ? Colors.white54 : Colors.grey, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    doctor['hospital']['address'] ?? 'N/A',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.phone, color: isDark ? Colors.white54 : Colors.grey, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  doctor['hospital']['phone'] ?? 'N/A',
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Availability
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isDark ? null : [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: isDark ? Colors.white70 : const Color(0xFF06B6D4), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Availability',
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatAvailability(),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    
                    // Languages
                    if (doctor['languages'] != null && (doctor['languages'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isDark ? null : [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.language, color: isDark ? Colors.white70 : const Color(0xFF06B6D4), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Languages',
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (doctor['languages'] as List).join(', '),
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Book Appointment Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookAppointmentScreen(
                                doctor: doctor,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : const Color(0xFF06B6D4),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Chat with Doctor Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DoctorChatbotScreen(
                                doctorId: doctor['_id'],
                                doctorName: doctor['name'],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Chat with Doctor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : const Color(0xFF06B6D4),
                          side: BorderSide(color: isDark ? Colors.white : const Color(0xFF06B6D4), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.2) : const Color(0xFF06B6D4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
