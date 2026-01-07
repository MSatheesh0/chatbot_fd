import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/settings_service.dart';

class ModeSelectionScreen extends StatelessWidget {
  final String currentMode;
  final Function(String) onModeSelected;

  const ModeSelectionScreen({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
  });

  List<Map<String, dynamic>> _getModes(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      {
        'key': 'funny',
        'name': 'Funny',
        'icon': Icons.emoji_emotions_outlined,
        'description': l10n.translate('funny_desc'),
        'color': Colors.orangeAccent,
      },
      {
        'key': 'search',
        'name': 'Search',
        'icon': Icons.search_outlined,
        'description': l10n.translate('search_desc'),
        'color': Colors.blueAccent,
      },
      {
        'key': 'mental_health',
        'name': 'Mental Health',
        'icon': Icons.favorite_outline,
        'description': l10n.translate('mental_health_desc'),
        'color': Colors.pinkAccent,
      },
      {
        'key': 'study',
        'name': 'Study',
        'icon': Icons.book_outlined,
        'description': l10n.translate('study_desc'),
        'color': Colors.greenAccent,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modes = _getModes(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('select_ai_mode')),
        backgroundColor: isDark ? Colors.black : const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: SettingsService().locale,
        builder: (context, locale, _) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.black : const Color(0xFFF3E5F5),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: modes.length,
              itemBuilder: (context, index) {
                final mode = modes[index];
                final isSelected = mode['name'] == currentMode;

                return GestureDetector(
                  onTap: () {
                    onModeSelected(mode['name']);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? mode['color'] : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: mode['color'].withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: mode['color'].withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(mode['icon'], color: mode['color'], size: 30),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate(mode['key']),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode['description'],
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: mode['color'], size: 28),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
