import 'package:flutter/material.dart';

class ModeSelectionScreen extends StatelessWidget {
  final String currentMode;
  final Function(String) onModeSelected;

  const ModeSelectionScreen({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
  });

  final List<Map<String, dynamic>> _modes = const [
    {
      'name': 'Funny',
      'icon': Icons.emoji_emotions_outlined,
      'description': 'AI with a sense of humor and jokes.',
      'color': Colors.orangeAccent,
    },
    {
      'name': 'Search',
      'icon': Icons.search_outlined,
      'description': 'Focused on finding facts and info.',
      'color': Colors.blueAccent,
    },
    {
      'name': 'Mental Health',
      'icon': Icons.favorite_outline,
      'description': 'Empathetic and supportive listener.',
      'color': Colors.pinkAccent,
    },
    {
      'name': 'Study',
      'icon': Icons.book_outlined,
      'description': 'Helps with learning and explanations.',
      'color': Colors.greenAccent,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select AI Mode'),
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _modes.length,
          itemBuilder: (context, index) {
            final mode = _modes[index];
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
                  color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? mode['color'] : Colors.white24,
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
                            mode['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mode['description'],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
