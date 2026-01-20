import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

class AvatarViewUnity extends StatefulWidget {
  final String action;
  final String emotion;
  final double speed;
  final String eyeState;

  const AvatarViewUnity({
    super.key,
    this.action = 'idle',
    this.emotion = 'neutral',
    this.speed = 1.0,
    this.eyeState = 'normal',
  });

  @override
  State<AvatarViewUnity> createState() => _AvatarViewUnityState();
}

class _AvatarViewUnityState extends State<AvatarViewUnity> {
  UnityWidgetController? _unityWidgetController;
  bool _isUnityLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _unityWidgetController?.dispose();
    super.dispose();
  }

  void _onUnityCreated(UnityWidgetController controller) {
    _unityWidgetController = controller;
    setState(() {
      _isUnityLoaded = true;
    });
    // Send initial state
    _updateAvatarState();
  }

  void _updateAvatarState() {
    if (_unityWidgetController != null) {
      // Format: "action|emotion|speed|eyeState"
      String message = "${widget.action}|${widget.emotion}|${widget.speed}|${widget.eyeState}";
      
      _unityWidgetController!.postMessage(
        'Avatar', // Name of the GameObject in Unity
        'SetAvatarState', // Name of the method in C# script
        message,
      );
    }
  }

  @override
  void didUpdateWidget(AvatarViewUnity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action ||
        oldWidget.emotion != widget.emotion ||
        oldWidget.speed != widget.speed ||
        oldWidget.eyeState != widget.eyeState) {
      _updateAvatarState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UnityWidget(
          onUnityCreated: _onUnityCreated,
          useAndroidViewSurface: true, // Often needed for better performance/compatibility
          borderRadius: BorderRadius.zero,
        ),
        if (!_isUnityLoaded)
          Container(
            color: Colors.white, // Or your app background color
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Loading 3D Engine..."),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
