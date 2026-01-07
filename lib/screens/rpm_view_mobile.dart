import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:convert';

class RpmView extends StatefulWidget {
  final Function(String) onAvatarExported;

  const RpmView({super.key, required this.onAvatarExported});

  @override
  State<RpmView> createState() => _RpmViewState();
}

class _RpmViewState extends State<RpmView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            // Inject script to listen for Ready Player Me events and capture logs
            controller.runJavaScript('''
              // Override console.log to send logs to Flutter
              var oldLog = console.log;
              console.log = function(message) {
                AvatarChannel.postMessage('LOG: ' + message);
                oldLog.apply(console, arguments);
              };

              window.addEventListener('message', function(event) {
                if (event.data) {
                  // Ready Player Me sends data as a string or object
                  if (typeof event.data === 'string') {
                    AvatarChannel.postMessage(event.data);
                  } else {
                    AvatarChannel.postMessage(JSON.stringify(event.data));
                  }
                }
              });
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'AvatarChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleAvatarMessage(message.message);
        },
      );

    // Enable debugging and relax media restrictions on Android
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    
    controller.clearCache();
    // Use frameApi=true to enable postMessage communication and hide the default UI
    controller.loadRequest(Uri.parse('https://readyplayer.me/avatar?frameApi=true&clearCache=true'));

    _controller = controller;
  }

  void _handleAvatarMessage(String message) {
    // Handle console logs from WebView
    if (message.startsWith('LOG: ')) {
      debugPrint('WebView Console: ${message.substring(5)}');
      return;
    }

    debugPrint('RPM Message Received: $message'); 

    try {
      // 1. Try to parse as JSON
      final Map<String, dynamic> eventData = jsonDecode(message);
      
      // 2. Check for Ready Player Me source
      if (eventData['source'] == 'readyplayerme') {
        final String? eventName = eventData['eventName'];
        
        // 3. Check for export event (v1 or v2)
        if (eventName == 'v1.avatar.exported' || eventName == 'v2.avatar.exported') {
          final String avatarUrl = eventData['data']['url'];
          debugPrint('✅ Avatar URL captured: $avatarUrl');
          widget.onAvatarExported(avatarUrl);
        } else {
          debugPrint('ℹ️ Ignored RPM event: $eventName');
        }
      }
    } catch (e) {
      // 4. Fallback: Check if message IS the URL (sometimes happens with direct postMessage)
      if (message.startsWith('https://') && message.contains('.glb')) {
         debugPrint('✅ Direct Avatar URL captured: $message');
         widget.onAvatarExported(message);
      } else {
         // Don't spam errors for non-JSON messages (like some internal webview messages)
         // debugPrint('⚠️ Error parsing message: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF8B5CF6),
            ),
          ),
      ],
    );
  }
}
