import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AvatarView extends StatefulWidget {
  final String avatarUrl;
  final String action;
  final String emotion;

  const AvatarView({
    super.key,
    required this.avatarUrl,
    this.action = 'idle',
    this.emotion = 'neutral',
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action || oldWidget.emotion != widget.emotion) {
      _updateAvatarState();
    }
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _controller.loadHtmlString(_getHtmlContent());
    }
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_getHtmlContent());
  }

  void _updateAvatarState() {
    _controller.runJavaScript('updateState("${widget.action}", "${widget.emotion}")');
  }

  String _getHtmlContent() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body { margin: 0; overflow: hidden; background: transparent; }
        canvas { width: 100vw; height: 100vh; display: block; }
    </style>
    <script async src="https://unpkg.com/es-module-shims@1.6.3/dist/es-module-shims.js"></script>
    <script type="importmap">
    {
        "imports": {
            "three": "https://unpkg.com/three@0.154.0/build/three.module.js",
            "three/addons/": "https://unpkg.com/three@0.154.0/examples/jsm/"
        }
    }
    </script>
</head>
<body>
    <script type="module">
        import * as THREE from 'three';
        import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

        let scene, camera, renderer, model, mixer;
        let animations = {};

        init();

        function init() {
            scene = new THREE.Scene();
            
            camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
            camera.position.set(0, 1.4, 2.5);

            renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
            renderer.setPixelRatio(window.devicePixelRatio);
            renderer.setSize(window.innerWidth, window.innerHeight);
            renderer.outputColorSpace = THREE.SRGBColorSpace;
            document.body.appendChild(renderer.domElement);

            const ambientLight = new THREE.AmbientLight(0xffffff, 0.8);
            scene.add(ambientLight);

            const dirLight = new THREE.DirectionalLight(0xffffff, 1);
            dirLight.position.set(5, 5, 5);
            scene.add(dirLight);

            const loader = new GLTFLoader();
            loader.load('${widget.avatarUrl}', (gltf) => {
                model = gltf.scene;
                scene.add(model);
                
                mixer = new THREE.AnimationMixer(model);
                gltf.animations.forEach((clip) => {
                    animations[clip.name] = mixer.clipAction(clip);
                });

                if (animations['idle']) animations['idle'].play();
                
                animate();
            });

            window.addEventListener('resize', onWindowResize);
        }

        function onWindowResize() {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        }

        function animate() {
            requestAnimationFrame(animate);
            if (mixer) mixer.update(0.016);
            renderer.render(scene, camera);
        }

        window.updateState = (action, emotion) => {
            // Placeholder for animation switching logic
            console.log('Action:', action, 'Emotion:', emotion);
            if (animations[action]) {
                Object.values(animations).forEach(a => a.fadeOut(0.5));
                animations[action].reset().fadeIn(0.5).play();
            }
        };
    </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
