import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class AvatarView extends StatefulWidget {
  final String avatarUrl;
  final String action;
  final String emotion;

  final double speed;
  final String eyeState;

  const AvatarView({
    super.key,
    required this.avatarUrl,
    this.action = 'idle',
    this.emotion = 'neutral',
    this.speed = 1.0,
    this.eyeState = 'normal',
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  final String _viewType = 'avatar-3d-view';
  late html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
  }

  void _registerViewFactory() {
    ui_web.platformViewRegistry.registerViewFactory(
      '$_viewType-${widget.avatarUrl.hashCode}',
      (int viewId) {
        _iframe = html.IFrameElement()
          ..id = 'avatar-iframe-$viewId'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.pointerEvents = 'none'
          ..srcdoc = _getHtmlContent();
        
        return _iframe;
      },
    );
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action || 
        oldWidget.emotion != widget.emotion ||
        oldWidget.speed != widget.speed ||
        oldWidget.eyeState != widget.eyeState) {
      _updateAvatarState();
    }
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _iframe.srcdoc = _getHtmlContent();
    }
  }

  void _updateAvatarState() {
    try {
      final script = 'updateState("${widget.action}", "${widget.emotion}", ${widget.speed}, "${widget.eyeState}")';
      _iframe.contentWindow?.postMessage(script, '*');
    } catch (e) {
      debugPrint('Error updating avatar state: $e');
    }
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
        let currentActionName = 'idle';
        let morphTargetMesh = null;
        
        // Target weights for smooth interpolation
        let targetMorphs = {}; 
        
        // Standard ARKit/RPM Blendshapes mapping
        const emotionMap = {
            'happy': { 'mouthSmile': 1.0, 'eyeSquintLeft': 0.5, 'eyeSquintRight': 0.5, 'browInnerUp': 0.0 },
            'sad': { 'mouthFrownLeft': 1.0, 'mouthFrownRight': 1.0, 'browInnerUp': 1.0, 'eyeSquintLeft': 0.0 },
            'angry': { 'browDownLeft': 1.0, 'browDownRight': 1.0, 'mouthFrownLeft': 0.5, 'mouthFrownRight': 0.5 },
            'surprised': { 'jawOpen': 0.3, 'browOuterUpLeft': 1.0, 'browOuterUpRight': 1.0 },
            'excited': { 'mouthSmile': 0.8, 'eyeWideLeft': 0.6, 'eyeWideRight': 0.6, 'jawOpen': 0.1 },
            'neutral': { 'mouthSmile': 0.0, 'browInnerUp': 0.0, 'browDownLeft': 0.0, 'jawOpen': 0.0 }
        };

        const eyeStateMap = {
            'normal': { 'eyeBlinkLeft': 0.0, 'eyeBlinkRight': 0.0, 'eyeWideLeft': 0.0, 'eyeWideRight': 0.0 },
            'focused': { 'eyeSquintLeft': 0.6, 'eyeSquintRight': 0.6 },
            'soft': { 'eyeSquintLeft': 0.3, 'eyeSquintRight': 0.3 },
            'blink': { 'eyeBlinkLeft': 1.0, 'eyeBlinkRight': 1.0 }
        };

        let lastBlinkTime = 0;
        let blinkState = 'open'; // open, closing, opening
        let blinkDuration = 0.15; // seconds
        let blinkTimer = 0;
        
        // Blink intervals (min, max) in seconds
        const blinkIntervals = {
            'normal': [3.0, 5.0],
            'soft': [4.0, 6.0],
            'focused': [6.0, 10.0]
        };
        let nextBlinkTime = 3.0;

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
                
                model.traverse((child) => {
                    if (child.isMesh && child.morphTargetDictionary) {
                        morphTargetMesh = child;
                    }
                });

                mixer = new THREE.AnimationMixer(model);
                gltf.animations.forEach((clip) => {
                    let name = clip.name.toLowerCase();
                    // Map common names
                    if (name.includes('idle')) name = 'idle';
                    else if (name.includes('talk')) name = 'talk';
                    else if (name.includes('walk')) name = 'walk';
                    else if (name.includes('wave')) name = 'wave';
                    
                    animations[name] = mixer.clipAction(clip);
                    animations[clip.name] = mixer.clipAction(clip); // Keep original too
                });

                if (!animations['idle'] && gltf.animations.length > 0) {
                    animations['idle'] = mixer.clipAction(gltf.animations[0]);
                }

                if (animations['idle']) {
                    animations['idle'].play();
                    currentActionName = 'idle';
                }
                
                animate();
            });

            window.addEventListener('resize', onWindowResize);
            window.addEventListener('message', handleMessage);
        }

        function handleMessage(event) {
            if (typeof event.data === 'string' && event.data.startsWith('updateState')) {
                try {
                    eval(event.data);
                } catch (e) {
                    console.error('Error executing command:', e);
                }
            }
        }

        function onWindowResize() {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        }

        function animate() {
            requestAnimationFrame(animate);
            
            const delta = 0.016; // Approx 60fps
            if (mixer) mixer.update(delta);
            
            // --- Blink Logic ---
            lastBlinkTime += delta;
            if (blinkState === 'open' && lastBlinkTime > nextBlinkTime) {
                blinkState = 'closing';
                blinkTimer = 0;
            } else if (blinkState === 'closing') {
                blinkTimer += delta;
                if (blinkTimer >= blinkDuration / 2) {
                    blinkState = 'opening';
                }
            } else if (blinkState === 'opening') {
                blinkTimer += delta;
                if (blinkTimer >= blinkDuration) {
                    blinkState = 'open';
                    lastBlinkTime = 0;
                    // Set next blink time based on current eye state
                    // We need to access eyeState from somewhere, let's store it globally
                    const state = window.currentEyeState || 'normal';
                    const range = blinkIntervals[state] || blinkIntervals['normal'];
                    nextBlinkTime = range[0] + Math.random() * (range[1] - range[0]);
                }
            }

            // --- Morph Target Interpolation ---
            if (morphTargetMesh && morphTargetMesh.morphTargetDictionary) {
                // 1. Calculate base targets from emotion/state
                let currentTargets = { ...targetMorphs };
                
                // 2. Apply Blink Override
                if (blinkState !== 'open') {
                    let blinkWeight = 0;
                    if (blinkState === 'closing') {
                        blinkWeight = blinkTimer / (blinkDuration / 2);
                    } else {
                        blinkWeight = 1.0 - ((blinkTimer - (blinkDuration / 2)) / (blinkDuration / 2));
                    }
                    // Apply to both eyes
                    currentTargets['eyeBlinkLeft'] = Math.max(currentTargets['eyeBlinkLeft'] || 0, blinkWeight);
                    currentTargets['eyeBlinkRight'] = Math.max(currentTargets['eyeBlinkRight'] || 0, blinkWeight);
                }

                // 3. Apply to Mesh
                for (const [name, targetValue] of Object.entries(currentTargets)) {
                    const index = morphTargetMesh.morphTargetDictionary[name];
                    if (index !== undefined) {
                        const currentValue = morphTargetMesh.morphTargetInfluences[index];
                        morphTargetMesh.morphTargetInfluences[index] = THREE.MathUtils.lerp(currentValue, targetValue, 0.1);
                    }
                }
            }
            
            renderer.render(scene, camera);
        }

        window.updateState = (action, emotion, speed, eyeState) => {
            console.log('UpdateState:', { action, emotion, speed, eyeState });
            window.currentEyeState = eyeState; // Store for blink logic
            
            // --- 1. Handle Animation (Safe Mode) ---
            try {
                let animName = action.toLowerCase();
                
                // Map gestures to available animations
                if (animName === 'talk_hands') animName = 'talk'; 
                else if (animName === 'explain_hands') animName = 'talk'; 
                else if (animName === 'encourage_hands') animName = 'talk'; 
                
                // Resolve animation name
                let targetAnim = null;
                if (animations[animName]) {
                    targetAnim = animations[animName];
                } else if (animations[action]) {
                    targetAnim = animations[action];
                    animName = action;
                }

                // Play Animation if found
                if (targetAnim && animName !== currentActionName) {
                    if (animations[currentActionName]) {
                        animations[currentActionName].fadeOut(0.5);
                    }
                    targetAnim.reset().fadeIn(0.5).play();
                    currentActionName = animName;
                } else if (!targetAnim && animations['idle'] && currentActionName !== 'idle') {
                    // Fallback to idle if requested action not found
                    if (animations[currentActionName]) animations[currentActionName].fadeOut(0.5);
                    animations['idle'].reset().fadeIn(0.5).play();
                    currentActionName = 'idle';
                }
                
                // Apply Speed (Safe Check)
                if (animations[currentActionName]) {
                    animations[currentActionName].timeScale = speed || 1.0;
                }
            } catch (e) {
                console.warn("Animation update failed:", e);
            }
            
            // --- 2. Handle Emotion & Eye State (Morph Targets) ---
            try {
                if (morphTargetMesh) {
                    const emotionTargets = emotionMap[emotion] || emotionMap['neutral'];
                    const eyeTargets = eyeStateMap[eyeState] || eyeStateMap['normal'];
                    
                    // Reset targets
                    const allKeys = new Set([...Object.keys(emotionMap).flatMap(k => Object.keys(emotionMap[k])), ...Object.keys(eyeStateMap).flatMap(k => Object.keys(eyeStateMap[k]))]);
                    allKeys.forEach(key => targetMorphs[key] = 0.0);

                    // Set new targets
                    Object.entries(emotionTargets).forEach(([key, val]) => targetMorphs[key] = val);
                    Object.entries(eyeTargets).forEach(([key, val]) => {
                        targetMorphs[key] = Math.max(targetMorphs[key] || 0, val);
                    });
                }
            } catch (e) {
                console.warn("Morph target update failed:", e);
            }
        };
    </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: '$_viewType-${widget.avatarUrl.hashCode}',
    );
  }
}
