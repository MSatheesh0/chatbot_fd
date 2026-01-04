import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../widgets/avatar_view.dart';

class ReminderOverlayWidget extends StatefulWidget {
  const ReminderOverlayWidget({super.key});

  @override
  State<ReminderOverlayWidget> createState() => _ReminderOverlayWidgetState();
}

class _ReminderOverlayWidgetState extends State<ReminderOverlayWidget> {
  String _title = "Reminder";
  String _body = "Time to check your reminder!";

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        if (mounted) {
          setState(() {
             if (event['title'] != null) _title = event['title'];
             if (event['body'] != null) _body = event['body'];
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 300,
          height: 450,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              // Avatar Section
              Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: const AvatarView(
                    avatarUrl: 'https://models.readyplayer.me/64b73e0e3c7943482d8c9735.glb', // Default for overlay
                    action: 'talking',
                    emotion: 'happy',
                  ),
                ),
              ),
              // Text Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _body,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                FlutterOverlayWindow.shareData("snooze");
                                FlutterOverlayWindow.closeOverlay();
                              },
                              child: const Text("Snooze"),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                FlutterOverlayWindow.shareData("stop");
                                FlutterOverlayWindow.closeOverlay();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Stop"),
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
