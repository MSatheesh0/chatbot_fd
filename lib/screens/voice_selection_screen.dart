import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../services/tts_service.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _ttsService.init();
      final voices = _ttsService.voices;
      
      if (voices.isEmpty) {
        setState(() {
          _errorMessage = l10n.translate('no_system_voices');
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
    final l10n = AppLocalizations.of(context);
    setState(() => _selectedVoiceId = voice['id']);
    await _ttsService.updateSettings(
      voiceId: voice['id'],
      voiceName: voice['name'],
      gender: voice['gender'],
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.translate('selected_voice_msg')}${voice['name']}')),
      );
    }
  }

  Future<void> _previewVoice(Map<String, String> voice) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _playingVoiceId = voice['id']);
    try {
      String text = l10n.translate('hello_voice').replaceAll('{name}', voice['name'] ?? 'AI');
      await _ttsService.speak(text, voice: voice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('preview_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _playingVoiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFFDFBFF),
      appBar: AppBar(
        title: Text(l10n.translate('select_voice'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.blue[300] : const Color(0xFF6A11CB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: isDark ? Colors.blue[300] : const Color(0xFF6A11CB),
          tabs: [
            Tab(text: l10n.translate('female'), icon: const Icon(Icons.female)),
            Tab(text: l10n.translate('male'), icon: const Icon(Icons.male)),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return _isLoading
              ? Center(child: CircularProgressIndicator(color: isDark ? Colors.blue[300] : const Color(0xFF6A11CB)))
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: Text(l10n.translate('retry')),
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
                    );
        },
      ),
    );
  }

  Widget _buildVoiceList(String gender) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter voices. If gender is unknown, maybe show in both or a separate list?
    // For now, let's include 'unknown' in 'female' if it looks like it, or just split.
    // My TTSService guesses gender.
    
    final filteredVoices = _voices.where((v) => v['gender'] == gender).toList();
    
    // If we have very few voices, maybe show all in both tabs? No.
    
    if (filteredVoices.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).translate('no_voices_available')));
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
          color: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: isSelected ? BorderSide(color: isDark ? Colors.blue[300]! : const Color(0xFF6A11CB), width: 2) : BorderSide.none,
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isSelected ? (isDark ? Colors.blue[700] : const Color(0xFF6A11CB)) : (isDark ? Colors.grey[800] : Colors.grey.shade200),
              child: Icon(
                gender == 'female' ? Icons.female : Icons.male,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            title: Text(
              voice['name'] ?? AppLocalizations.of(context).translate('unknown'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? (isDark ? Colors.blue[300] : const Color(0xFF6A11CB)) : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            subtitle: Text(voice['locale'] ?? '', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill),
                  color: isDark ? Colors.blue[300] : const Color(0xFF2575FC),
                  onPressed: () => isPlaying ? _ttsService.stop() : _previewVoice(voice),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.green)
                else
                  ElevatedButton(
                    onPressed: () => _selectVoice(voice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                      foregroundColor: isDark ? Colors.blue[300] : const Color(0xFF6A11CB),
                      elevation: 0,
                      side: BorderSide(color: isDark ? Colors.blue[300]! : const Color(0xFF6A11CB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(AppLocalizations.of(context).translate('select')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
