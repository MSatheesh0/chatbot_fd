import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../services/tts_service.dart';

class VoiceSelectionScreen extends StatefulWidget {
  const VoiceSelectionScreen({super.key});

  @override
  State<VoiceSelectionScreen> createState() => _VoiceSelectionScreenState();
}

class _VoiceSelectionScreenState extends State<VoiceSelectionScreen> with SingleTickerProviderStateMixin {
  final TTSService _ttsService = TTSService();
  late TabController _tabController;
  
  List<Map<String, String>> _voices = [];
  bool _isLoading = true;
  String? _selectedVoiceId;
  String? _playingVoiceId; // To track which voice is currently previewing

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  String? _errorMessage;

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _ttsService.init();
      final voices = _ttsService.voices;
      
      if (voices.isEmpty) {
        setState(() {
          _errorMessage = "No system voices found. Please check your device settings.";
          _isLoading = false;
        });
      } else {
        setState(() {
          _voices = voices;
          _selectedVoiceId = _ttsService.currentVoice?['id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _selectVoice(Map<String, String> voice) async {
    setState(() => _selectedVoiceId = voice['id']);
    await _ttsService.updateSettings(
      voiceId: voice['id'],
      voiceName: voice['name'],
      gender: voice['gender'],
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected voice: ${voice['name']}')),
      );
    }
  }

  Future<void> _previewVoice(Map<String, String> voice) async {
    setState(() => _playingVoiceId = voice['id']);
    try {
      await _ttsService.speak("Hello, I am ${voice['name']}. How can I help you today?", voice: voice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: $e')),
        );
      }
    } finally {
      // We don't automatically reset _playingVoiceId because speak is async but might return before audio finishes?
      // flutter_tts awaitSpeakCompletion(true) is set in init, so it should wait.
      if (mounted) setState(() => _playingVoiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFF),
      appBar: AppBar(
        title: const Text('Select Voice', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6A11CB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6A11CB),
          tabs: const [
            Tab(text: 'Female', icon: Icon(Icons.female)),
            Tab(text: 'Male', icon: Icon(Icons.male)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVoiceList('female'),
                    _buildVoiceList('male'),
                  ],
                ),
    );
  }

  Widget _buildVoiceList(String gender) {
    // Filter voices. If gender is unknown, maybe show in both or a separate list?
    // For now, let's include 'unknown' in 'female' if it looks like it, or just split.
    // My TTSService guesses gender.
    
    final filteredVoices = _voices.where((v) => v['gender'] == gender).toList();
    
    // If we have very few voices, maybe show all in both tabs? No.
    
    if (filteredVoices.isEmpty) {
      return Center(child: Text('No $gender voices available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredVoices.length,
      itemBuilder: (context, index) {
        final voice = filteredVoices[index];
        final isSelected = voice['id'] == _selectedVoiceId;
        final isPlaying = voice['id'] == _playingVoiceId;

        return Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: isSelected ? const BorderSide(color: Color(0xFF6A11CB), width: 2) : BorderSide.none,
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isSelected ? const Color(0xFF6A11CB) : Colors.grey.shade200,
              child: Icon(
                gender == 'female' ? Icons.female : Icons.male,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            title: Text(
              voice['name'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF6A11CB) : Colors.black87,
              ),
            ),
            subtitle: Text(voice['locale'] ?? '', style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill),
                  color: const Color(0xFF2575FC),
                  onPressed: () => isPlaying ? _ttsService.stop() : _previewVoice(voice),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.green)
                else
                  ElevatedButton(
                    onPressed: () => _selectVoice(voice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6A11CB),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF6A11CB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Select'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
