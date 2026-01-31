import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants.dart';

class AvatarView extends StatefulWidget {
  final String avatarUrl;
  final String action;
  final String emotion;
  final double speed;
  final String eyeState;
  final bool isTalking;

  const AvatarView({
    super.key,
    required this.avatarUrl,
    this.action = 'idle',
    this.emotion = 'neutral',
    this.speed = 1.0,
    this.eyeState = 'normal',
    this.isTalking = false,
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  bool _isPageLoaded = false;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action || 
        oldWidget.emotion != widget.emotion ||
        oldWidget.speed != widget.speed ||
        oldWidget.eyeState != widget.eyeState ||
        oldWidget.isTalking != widget.isTalking) {
      _updateAvatarState();
    }
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      // FIX 1: Avoid reloading the entire HTML. Use JS to switch avatar.
      if (_isPageLoaded) {
          _controller.runJavaScript('loadAvatar("${widget.avatarUrl}")');
      }
    }
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            debugPrint('AvatarView: Page finished loading: $url');
            _isPageLoaded = true;
            // Apply initial state once loaded
            _updateAvatarState();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('AvatarView: Web resource error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'Console',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('AvatarView JS: ${message.message}');
        },
      )
      ..loadHtmlString(_getHtmlContent());
  }

  void _updateAvatarState() {
    if (_isPageLoaded) {
      // Ensure strings are escaped for JS
      final action = widget.action.replaceAll('"', '\\"');
      final emotion = widget.emotion.replaceAll('"', '\\"');
      final eyeState = widget.eyeState.replaceAll('"', '\\"');
      
      final script = 'if(window.updateState) window.updateState("$action", "$emotion", ${widget.speed}, "$eyeState", ${widget.isTalking})';
      debugPrint('AvatarView: Running JS: $script');
      _controller.runJavaScript(script);
    }
  }

  String _getHtmlContent() {
    // Clean base URL to avoid double slashes
    String baseUrl = ApiConstants.baseUrl;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body { margin: 0; overflow: hidden; background: transparent; }
        canvas { width: 100vw; height: 100vh; display: block; outline: none; }
        #status {
            position: absolute;
            top: 20px;
            left: 20px;
            color: #0f0;
            background: rgba(0, 0, 0, 0.8);
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
            font-size: 12px;
            z-index: 1000;
            display: none;
            pointer-events: none;
        }
    </style>
    <script>
        window.pendingState = null;
        window.isSceneReady = false;

        window.updateState = function(action, emotion, speed, eyeState, isTalking) {
            console.log("updateState called:", action, emotion);
            if (!window.isSceneReady) {
                console.log("Queuing state update:", action);
                window.pendingState = { action, emotion, speed, eyeState, isTalking };
                return;
            }
            if (window.moduleUpdateState) {
                window.moduleUpdateState(action, emotion, speed, eyeState, isTalking);
            }
        };
    </script>
</head>
<body>
    <div id="status">Initializing...</div>
    <script type="module">
        import * as THREE from 'https://esm.sh/three@0.154.0';
        import { GLTFLoader } from 'https://esm.sh/three@0.154.0/examples/jsm/loaders/GLTFLoader';
        import { FBXLoader } from 'https://esm.sh/three@0.154.0/examples/jsm/loaders/FBXLoader';

        let scene, camera, renderer, model, mixer;
        let animations = {};
        let currentActionName = 'idle';
        let morphTargetMesh = null;
        let targetMorphs = {};
        const BASE_URL = '$baseUrl';
        
        const fallbackAnims = {
            'idle': 'https://models.readyplayer.me/animations/idle.fbx',
            'wave': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/waving.fbx',
            'walk': 'https://models.readyplayer.me/animations/walking.fbx',
            'happy': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_happy.fbx',
            'angry': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_angry.fbx',
            'talking': BASE_URL + '/animations/Talking.fbx'
        };

        const FALLBACK_AVATAR = 'https://models.readyplayer.me/638df693d72bffc6fa17d4f2.glb';

        function updateStatus(msg) {
            console.log('[AvatarView]', msg);
            const el = document.getElementById('status');
            if(el) el.innerHTML = msg;
        }

        init();

        function init() {
            try {
                scene = new THREE.Scene();
                camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.1, 1000);
                camera.position.set(0, 1.45, 1.8); // Closer to face

                renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
                renderer.setPixelRatio(window.devicePixelRatio);
                renderer.setSize(window.innerWidth, window.innerHeight);
                renderer.outputColorSpace = THREE.SRGBColorSpace;
                renderer.toneMapping = THREE.ACESFilmicToneMapping;
                renderer.toneMappingExposure = 1.2;
                renderer.setClearColor(0x000000, 0);
                document.body.appendChild(renderer.domElement);

                // Enhanced Lighting System for better facial definition
                const hemiLight = new THREE.HemisphereLight(0xffffff, 0x444444, 1.5);
                hemiLight.position.set(0, 20, 0);
                scene.add(hemiLight);

                const dirLight = new THREE.DirectionalLight(0xffffff, 1.5);
                dirLight.position.set(3, 10, 10);
                dirLight.castShadow = true;
                scene.add(dirLight);

                // Key light for face
                const keyLight = new THREE.PointLight(0xffffff, 1.2);
                keyLight.position.set(1, 1.6, 2);
                scene.add(keyLight);

                // Rim light for definition
                const rimLight = new THREE.PointLight(0xffffff, 0.8);
                rimLight.position.set(-1, 1.6, -1);
                scene.add(rimLight);

                let avatarUrl = '${widget.avatarUrl}';
                if (!avatarUrl || avatarUrl === 'null' || avatarUrl.trim() === '' || !avatarUrl.startsWith('http')) {
                    avatarUrl = FALLBACK_AVATAR;
                } else {
                    // Force high quality parameters logic
                    if (!avatarUrl.includes('?')) {
                        avatarUrl += '?meshLod=0&textureSize=1024';
                    } else {
                        if (!avatarUrl.includes('meshLod')) avatarUrl += '&meshLod=0';
                        if (!avatarUrl.includes('textureSize')) avatarUrl += '&textureSize=1024';
                    }
                }
                
                loadAvatar(avatarUrl);
            } catch (e) {
                updateStatus("Init Error: " + e.message);
            }

            window.addEventListener('resize', () => {
                camera.aspect = window.innerWidth / window.innerHeight;
                camera.updateProjectionMatrix();
                renderer.setSize(window.innerWidth, window.innerHeight);
            });
        }

        function loadAvatar(url) {
            updateStatus("Loading Avatar...");
            const loader = new GLTFLoader();
            loader.load(url, (gltf) => {
                if(model) scene.remove(model);
                model = gltf.scene;
                scene.add(model);
                
                const box = new THREE.Box3().setFromObject(model);
                const center = box.getCenter(new THREE.Vector3());
                model.position.x += (model.position.x - center.x);
                model.position.y -= box.min.y;
                
                let modelBones = {};
                model.traverse((child) => {
                    if (child.isBone) modelBones[child.name] = child;
                    if (child.isMesh) {
                        child.frustumCulled = false;
                        child.castShadow = true;
                        child.receiveShadow = true;
                        
                        const materials = Array.isArray(child.material) ? child.material : [child.material];
                        materials.forEach(mat => {
                            if (mat) {
                                mat.transparent = true;
                                mat.depthWrite = true;
                                mat.roughness = 0.6; // Slightly more defined
                                mat.metalness = 0.05;
                                if (child.name.toLowerCase().includes('eye')) {
                                    mat.roughness = 0.05;
                                }
                                if (child.name.toLowerCase().includes('skin')) {
                                    mat.roughness = 0.8;
                                }
                            }
                        });
                        
                        if (child.morphTargetDictionary) morphTargetMesh = child;
                    }
                });

                mixer = new THREE.AnimationMixer(model);
                
                // Embedded animations
                if (gltf.animations && gltf.animations.length > 0) {
                    gltf.animations.forEach(clip => {
                        let name = clip.name.toLowerCase();
                        if (name.includes('idle')) name = 'idle';
                        animations[name] = mixer.clipAction(clip);
                    });
                }

                window.isSceneReady = true;
                animate();

                // Load external animations
                const animBase = BASE_URL + '/animations';
                const anims = [
                    { url: animBase + '/Breathing%20Idle.fbx', name: 'idle' },
                    { url: animBase + '/Happy%20Hand%20Gesture.fbx', name: 'wave' },
                    { url: animBase + '/Walking.fbx', name: 'walk' },
                    { url: animBase + '/Happy.fbx', name: 'happy' },
                    { url: animBase + '/Yelling.fbx', name: 'yell' },
                    { url: animBase + '/Talking.fbx', name: 'talking' },
                    { url: animBase + '/Sad%20Idle.fbx', name: 'sad' },
                    { url: animBase + '/Angry.fbx', name: 'angry' },
                    { url: animBase + '/Angry%20Point.fbx', name: 'angry_point' },
                    { url: animBase + '/Excited.fbx', name: 'excited' },
                    { url: animBase + '/Happy%20Walk.fbx', name: 'happy_walk' },
                    { url: animBase + '/Step%20Hip%20Hop%20Dance.fbx', name: 'dance' },
                    { url: animBase + '/Sleeping%20Idle.fbx', name: 'sleep' },
                    { url: animBase + '/Sitting%20Angry.fbx', name: 'sitting_angry' },
                    { url: animBase + '/Sitting%20Disbelief.fbx', name: 'sitting_disbelief' },
                    { url: animBase + '/Kneeling%20Idle.fbx', name: 'kneeling' },
                    { url: animBase + '/Male%20Laying%20Pose.fbx', name: 'laying' },
                    { url: animBase + '/Rejected.fbx', name: 'rejected' }
                ];

                anims.forEach(anim => {
                    loadExternalAnimation(anim.url, anim.name, modelBones);
                });

                if (window.pendingState) {
                    window.moduleUpdateState(window.pendingState.action, window.pendingState.emotion, window.pendingState.speed, window.pendingState.eyeState, window.pendingState.isTalking);
                    window.pendingState = null;
                }
                updateStatus("Ready");
                setTimeout(() => { document.getElementById('status').style.display = 'none'; }, 2000);
            }, undefined, (err) => {
                updateStatus("Load Error: " + err.message);
            });
        }

        window.queuedAction = null;
        window.queuedEmotion = null;

        window.moduleUpdateState = (action, emotion, speed, eyeState, isTalking) => {
            window.isTalking = isTalking;
            window.currentEyeState = eyeState;
            window.currentSpeed = speed || 1.0;
            
            let animName = action.toLowerCase();
            if (animName === 'talk' || animName === 'talking') animName = 'talking';
            
            // Map common variants
            const map = { 
                'sleep': 'sleep', 'sleeping': 'sleep', 
                'dance': 'dance', 'dancing': 'dance', 
                'walk': 'walk', 'walking': 'walk',
                'wave': 'wave', 'waving': 'wave'
            };
            if (map[animName]) animName = map[animName];

            // Update currentActionName
            const oldActionName = currentActionName;
            currentActionName = animName;

            if (animations[animName]) {
                window.queuedAction = null; // Clear queue if found
                if (animName !== oldActionName || ['wave', 'yell', 'angry_point', 'excited', 'dance'].includes(animName)) {
                    if (animations[oldActionName]) animations[oldActionName].fadeOut(0.3);
                    animations[animName].reset().fadeIn(0.3).play();
                }
                animations[animName].timeScale = window.currentSpeed;
            } else {
                // Animation not loaded yet, queue it
                console.log("Animation not loaded yet, queuing:", animName);
                window.queuedAction = animName;
                
                // Fallback to talking/idle while waiting
                const fallback = animations['talking'] ? 'talking' : 'idle';
                if (fallback && fallback !== oldActionName && animations[fallback]) {
                    if (animations[oldActionName]) animations[oldActionName].fadeOut(0.3);
                    animations[fallback].reset().fadeIn(0.3).play();
                }
            }

            // Morph targets for emotions
            if (morphTargetMesh) {
                const emotions = {
                    'happy': { 
                        'mouthSmile': 0.8, 
                        'mouthSmileLeft': 0.8, 
                        'mouthSmileRight': 0.8,
                        'eyeSquintLeft': 0.5, 
                        'eyeSquintRight': 0.5,
                        'cheekPuff': 0.2
                    },
                    'sad': { 
                        'mouthFrownLeft': 0.7, 
                        'mouthFrownRight': 0.7, 
                        'browInnerUp': 0.6,
                        'eyeSquintLeft': 0.2,
                        'eyeSquintRight': 0.2
                    },
                    'angry': { 
                        'browDownLeft': 1.0, 
                        'browDownRight': 1.0, 
                        'mouthFrownLeft': 0.5,
                        'mouthFrownRight': 0.5,
                        'eyeSquintLeft': 0.4,
                        'eyeSquintRight': 0.4
                    },
                    'surprised': { 
                        'jawOpen': 0.4, 
                        'browOuterUpLeft': 1.0, 
                        'browOuterUpRight': 1.0,
                        'eyeWideLeft': 0.6,
                        'eyeWideRight': 0.6
                    },
                    'excited': { 
                        'mouthSmile': 1.0, 
                        'mouthSmileLeft': 1.0,
                        'mouthSmileRight': 1.0,
                        'jawOpen': 0.2,
                        'eyeWideLeft': 0.4,
                        'eyeWideRight': 0.4
                    },
                    'neutral': {}
                };
                const targets = emotions[emotion] || emotions['neutral'];
                Object.keys(targetMorphs).forEach(k => targetMorphs[k] = 0);
                Object.entries(targets).forEach(([k, v]) => targetMorphs[k] = v);
            }
        };

        function loadExternalAnimation(url, name, modelBones) {
            const loader = new FBXLoader();
            loader.load(url, (asset) => {
                let clip = asset.animations[0];
                if (clip) {
                    clip.tracks = clip.tracks.filter(track => track.name.includes('.quaternion'));

                    clip.tracks.forEach(track => {
                        let cleanName = track.name.replace(/.*:|.*1:/g, '');
                        let trackBoneName = cleanName.split('.')[0];
                        let property = cleanName.split('.').slice(1).join('.');
                        
                        let targetBoneName = null;
                        if (modelBones[trackBoneName]) {
                            targetBoneName = trackBoneName;
                        } else {
                            const lower = trackBoneName.toLowerCase();
                            const match = Object.keys(modelBones).find(k => k.toLowerCase() === lower || k.toLowerCase().includes(lower.replace('mixamorig', '')));
                            if (match) targetBoneName = match;
                        }

                        if (targetBoneName) {
                            track.name = targetBoneName + '.' + property;
                        }
                    });

                    const action = mixer.clipAction(clip);
                    animations[name] = action;
                    
                    // If this was the queued action, play it now
                    if (name === window.queuedAction) {
                        console.log("Playing queued animation:", name);
                        if (animations[currentActionName]) animations[currentActionName].fadeOut(0.3);
                        action.reset().fadeIn(0.3).play();
                        action.timeScale = window.currentSpeed || 1.0;
                        currentActionName = name;
                        window.queuedAction = null;
                    } else if (name === 'idle' && currentActionName === 'idle') {
                        action.play();
                    }
                }
            }, undefined, (err) => {
                console.warn("Failed to load animation:", name, err);
                if (fallbackAnims[name] && fallbackAnims[name] !== url) {
                    loadExternalAnimation(fallbackAnims[name], name, modelBones);
                }
            });
        }

        let lastBlinkTime = 0;
        let blinkState = 'open';
        let blinkDuration = 0.12;
        let blinkTimer = 0;
        let nextBlinkTime = 3.0;
        const blinkIntervals = { 'normal': [3.0, 5.0], 'soft': [4.0, 6.0], 'focused': [6.0, 10.0] };

        function animate() {
            requestAnimationFrame(animate);
            const delta = 0.016;
            if (mixer) mixer.update(delta);

            if (morphTargetMesh) {
                // Blinking Logic
                lastBlinkTime += delta;
                if (blinkState === 'open' && lastBlinkTime > nextBlinkTime) {
                    blinkState = 'closing'; blinkTimer = 0;
                } else if (blinkState === 'closing') {
                    blinkTimer += delta; if (blinkTimer >= blinkDuration / 2) blinkState = 'opening';
                } else if (blinkState === 'opening') {
                    blinkTimer += delta;
                    if (blinkTimer >= blinkDuration) {
                        blinkState = 'open'; lastBlinkTime = 0;
                        const state = window.currentEyeState || 'normal';
                        const range = blinkIntervals[state] || blinkIntervals['normal'];
                        nextBlinkTime = range[0] + Math.random() * (range[1] - range[0]);
                    }
                }

                let currentTargets = { ...targetMorphs };

                // Talking animation - Enhanced with visemes if available
                if (window.isTalking) {
                    const open = (Math.sin(Date.now() * 0.01) * 0.5 + 0.5) * 0.6;
                    let mouthTarget = morphTargetMesh.morphTargetDictionary['mouthOpen'] !== undefined ? 'mouthOpen' 
                                     : morphTargetMesh.morphTargetDictionary['viseme_aa'] !== undefined ? 'viseme_aa' : null;
                    if (mouthTarget) currentTargets[mouthTarget] = Math.max(currentTargets[mouthTarget] || 0, open);
                    
                    // Add slight cheek movement for realism
                    if (morphTargetMesh.morphTargetDictionary['cheekPuff']) {
                        currentTargets['cheekPuff'] = Math.max(currentTargets['cheekPuff'] || 0, open * 0.2);
                    }
                }

                // Apply Blinking to currentTargets
                if (blinkState !== 'open') {
                    let bw = blinkState === 'closing' ? blinkTimer / (blinkDuration / 2) : 1.0 - ((blinkTimer - (blinkDuration / 2)) / (blinkDuration / 2));
                    currentTargets['eyeBlinkLeft'] = Math.max(currentTargets['eyeBlinkLeft'] || 0, bw);
                    currentTargets['eyeBlinkRight'] = Math.max(currentTargets['eyeBlinkRight'] || 0, bw);
                }
                
                // Apply all morphs smoothly
                Object.entries(currentTargets).forEach(([key, val]) => {
                    const idx = morphTargetMesh.morphTargetDictionary[key];
                    if (idx !== undefined) {
                        morphTargetMesh.morphTargetInfluences[idx] += (val - morphTargetMesh.morphTargetInfluences[idx]) * 0.15;
                    }
                });
            }
            renderer.render(scene, camera);
        }
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
