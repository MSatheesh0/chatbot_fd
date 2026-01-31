import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/avatar_service.dart';
import 'dart:async';

class AvatarWidget extends StatefulWidget {
  final bool showControls;
  final bool showDebugOptions;
  
  const AvatarWidget({
    Key? key,
    this.showControls = true,
    this.showDebugOptions = false,
  }) : super(key: key);

  @override
  _AvatarWidgetState createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> with SingleTickerProviderStateMixin {
  final AvatarService _avatarService = AvatarService();
  late AnimationController _animationController;
  bool _isInitialized = false;
  bool _showEmergencyButton = false;
  Timer? _emergencyButtonTimer;

  @override
  void initState() {
    super.initState();
    _initializeAvatar();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _initializeAvatar() async {
    await _avatarService.initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emergencyButtonTimer?.cancel();
    _avatarService.dispose();
    super.dispose();
  }

  void _handleEmergencyPress() {
    _showEmergencyOptions();
  }

  void _showEmergencyOptions() {
    setState(() => _showEmergencyButton = true);
    _emergencyButtonTimer?.cancel();
    _emergencyButtonTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _showEmergencyButton = false);
      }
    });
  }

  Widget _buildEmergencyButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: _handleEmergencyPress,
        backgroundColor: Colors.red,
        child: const Icon(Icons.emergency, color: Colors.white),
      ),
    );
  }

  Widget _buildEmergencyOptions() {
    if (!_showEmergencyButton) return const SizedBox.shrink();

    return Positioned(
      bottom: 90,
      right: 30,
      child: Column(
        children: [
          _buildEmergencyOptionButton(
            icon: Icons.medical_services,
            label: 'Call Doctor',
            onTap: () => _handleCallDoctor(),
          ),
          const SizedBox(height: 10),
          _buildEmergencyOptionButton(
            icon: Icons.local_hospital,
            label: 'Nearest Hospital',
            onTap: () => _handleFindHospital(),
          ),
          const SizedBox(height: 10),
          _buildEmergencyOptionButton(
            icon: Icons.contact_emergency,
            label: 'Emergency Contact',
            onTap: () => _handleEmergencyContact(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.red),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCallDoctor() async {
    // Implement call doctor logic
    debugPrint('Calling doctor...');
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Doctor'),
        content: const Text('Would you like to call a doctor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Make the call
      // final url = 'tel:1234567890';
      // if (await canLaunchUrl(Uri.parse(url))) {
      //   await launchUrl(Uri.parse(url));
      // }
    }
  }

  Future<void> _handleFindHospital() async {
    // Implement find hospital logic
    debugPrint('Finding nearest hospital...');
    // Open maps with nearby hospitals
    // final url = 'https://www.google.com/maps/search/hospital';
    // if (await canLaunchUrl(Uri.parse(url))) {
    //   await launchUrl(Uri.parse(url));
    // }
  }

  Future<void> _handleEmergencyContact() async {
    // Implement emergency contact logic
    debugPrint('Calling emergency contact...');
    // final prefs = await SharedPreferences.getInstance();
    // final emergencyContact = prefs.getString('emergency_contact') ?? '';
    // if (emergencyContact.isNotEmpty) {
    //   final url = 'tel:$emergencyContact';
    //   if (await canLaunchUrl(Uri.parse(url))) {
    //     await launchUrl(Uri.parse(url));
    //   }
    // }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ChangeNotifierProvider.value(
      value: _avatarService,
      child: Consumer<AvatarService>(
        builder: (context, avatarService, _) {
          return Stack(
            children: [
              // Main Avatar Display
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (!avatarService.isListening) {
                      avatarService.startListening();
                    } else {
                      avatarService.stopListening();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: avatarService.isListening ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar visualization (replace with your actual avatar widget)
                        _buildAvatarVisualization(avatarService),
                        const SizedBox(height: 20),
                        // Current emotion/action text
                        Text(
                          '${avatarService.currentEmotion.toUpperCase()} | ${avatarService.currentAction.replaceAll('_', ' ').toUpperCase()}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        // Debug info
                        if (widget.showDebugOptions) ..._buildDebugInfo(avatarService),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Emergency button (always visible)
              _buildEmergencyButton(),
              
              // Emergency options (shown when emergency button is pressed)
              _buildEmergencyOptions(),
              
              // Voice input indicator
              if (avatarService.isListening)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 16),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatarVisualization(AvatarService avatarService) {
    // This is a placeholder - replace with your actual avatar rendering logic
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: _getEmotionColor(avatarService.currentEmotion),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getEmojiForEmotion(avatarService.currentEmotion),
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'happy':
        return Colors.yellow[200]!;
      case 'sad':
        return Colors.blue[200]!;
      case 'angry':
        return Colors.red[200]!;
      case 'surprised':
        return Colors.purple[200]!;
      case 'calm':
        return Colors.green[200]!;
      default:
        return Colors.grey[200]!;
    }
  }

  String _getEmojiForEmotion(String emotion) {
    switch (emotion) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'surprised':
        return '😲';
      case 'calm':
        return '😌';
      default:
        return '😐';
    }
  }

  List<Widget> _buildDebugInfo(AvatarService avatarService) {
    return [
      const SizedBox(height: 10),
      Text('Language: ${avatarService.currentLanguage}'),
      Text('Risk Level: ${(avatarService.riskLevel * 100).toStringAsFixed(1)}%'),
      Text('Speaking: ${avatarService.isSpeaking}'),
      Text('Listening: ${avatarService.isListening}'),
      Text('Emergency Mode: ${avatarService.isEmergencyMode}'),
    ];
  }
}
