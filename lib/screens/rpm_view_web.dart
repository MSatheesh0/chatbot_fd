import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web; // Use dart:ui_web for platformViewRegistry
import 'package:flutter/material.dart';

class RpmView extends StatefulWidget {
  final Function(String) onAvatarExported;

  const RpmView({super.key, required this.onAvatarExported});

  @override
  State<RpmView> createState() => _RpmViewState();
}

class _RpmViewState extends State<RpmView> {
  final String _viewType = 'rpm-iframe';

  late final StreamSubscription<html.MessageEvent> _subscription;

  @override
  void initState() {
    super.initState();
    // Register the iframe view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..id = 'rpm-iframe-$viewId'
          ..src = 'https://readyplayer.me/avatar?frameApi=true&clearCache=true'
          ..style.border = 'none'
          ..allow = 'camera; microphone; clipboard-write'
          ..style.width = '100%'
          ..style.height = '100%';
        
        return iframe;
      },
    );

    // Listen for messages from the iframe
    _subscription = html.window.onMessage.listen(_handleMessage);
    
    // Also inject a script to ensure we catch all events
    _injectEventListener();
  }
  
  void _injectEventListener() {
    // Add a global listener for debugging
    html.window.addEventListener('message', (event) {
      final messageEvent = event as html.MessageEvent;
      debugPrint('🌐 Global window message: ${messageEvent.data}');
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _handleMessage(html.MessageEvent event) {
    try {
      var data = event.data;
      Map<String, dynamic>? eventData;

      // Debug: Log all incoming messages
      debugPrint('📨 RPM Message received - Type: ${data.runtimeType}');
      
      if (data is String) {
        debugPrint('📨 String data: $data');
        
        // Check if it's a direct avatar URL (Ready Player Me sometimes sends just the URL)
        if (data.startsWith('https://models.readyplayer.me/') || 
            data.startsWith('https://api.readyplayer.me/')) {
          debugPrint('🎉 AVATAR URL DETECTED (plain string)!');
          debugPrint('🎉 Avatar URL: $data');
          widget.onAvatarExported(data);
          return;
        }
        
        // Try to parse as JSON
        try {
          eventData = jsonDecode(data);
          debugPrint('📨 Parsed JSON: $eventData');
        } catch (e) {
          debugPrint('📨 Not JSON string: $e');
        }
      } else if (data is Map) {
        // It's already a Map (converted from JS object)
        eventData = Map<String, dynamic>.from(data);
        debugPrint('📨 Map data: $eventData');
      } else {
        debugPrint('📨 Unknown data type: ${data.runtimeType}');
      }

      if (eventData != null) {
        debugPrint('📨 Event source: ${eventData['source']}');
        debugPrint('📨 Event name: ${eventData['eventName']}');
        
        // Ready Player Me sends events in this format
        if (eventData['source'] == 'readyplayerme') {
          debugPrint('✅ Ready Player Me event detected!');
          
          final eventName = eventData['eventName'];
          
          // Handle both v1 and v2 avatar exported events
          if (eventName == 'v1.avatar.exported' || eventName == 'v2.avatar.exported') {
            debugPrint('🎉 AVATAR EXPORTED EVENT ($eventName)!');
            
            final data = eventData['data'];
            if (data != null && data['url'] != null) {
              final String avatarUrl = data['url'];
              debugPrint('🎉 Avatar URL: $avatarUrl');
              widget.onAvatarExported(avatarUrl);
            } else {
              debugPrint('❌ No URL in avatar export data: $data');
            }
          } else {
            debugPrint('ℹ️ Other RPM event: $eventName');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling RPM message: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
