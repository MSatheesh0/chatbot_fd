import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../widgets/avatar_view.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:alarm/alarm.dart';

class ReminderOverlayWidget extends StatefulWidget {
  const ReminderOverlayWidget({super.key});

  @override
  State<ReminderOverlayWidget> createState() => _ReminderOverlayWidgetState();
}

class _ReminderOverlayWidgetState extends State<ReminderOverlayWidget> {
  String _title = "Reminder";
  String _body = "Time to check your reminder!";
  int? _reminderId;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        if (mounted) {
          setState(() {
             if (event['title'] != null) _title = event['title'];
             if (event['body'] != null) _body = event['body'];
             if (event['reminderId'] != null) _reminderId = event['reminderId'];
          });
          _speak("$_title. $_body");
        }
      }
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _stopAlarm() async {
    await _flutterTts.stop();
    if (_reminderId != null) {
      await Alarm.stop(_reminderId!);
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 340, // Wider
          height: 550, // Taller
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            children: [
              // Avatar Section
              Expanded(
                flex: 1, // Reduced flex to give more space to text
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Image.asset(
                    'assets/app_icon.png', // Fallback image
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Text Section
              Expanded(
                flex: 1, // Increased flex
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _body,
                        style: const TextStyle(
                          fontSize: 16, 
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await _flutterTts.stop();
                                await FlutterOverlayWindow.shareData("snooze");
                                await _stopAlarm();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Snooze", style: TextStyle(color: Color(0xFFEF4444))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await FlutterOverlayWindow.shareData("stop");
                                await _stopAlarm();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              child: const Text("Stop", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
