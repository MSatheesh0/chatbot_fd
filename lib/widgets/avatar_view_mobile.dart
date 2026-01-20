import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
        oldWidget.eyeState != widget.eyeState) {
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
      _controller.runJavaScript('if(window.updateState) updateState("${widget.action}", "${widget.emotion}", ${widget.speed}, "${widget.eyeState}")');
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
        body { margin: 0; overflow: hidden; background: transparent; } /* Transparent background */
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
            max-width: 80%;
            pointer-events: none;
        }
        #controls {
            position: absolute;
            top: 100px;
            left: 20px;
            z-index: 1001;
            display: flex;
            flex-wrap: wrap;
            gap: 5px;
        }
        button {
            background: rgba(0, 0, 0, 0.6); color: white; border: 1px solid #666;
            padding: 8px 12px; cursor: pointer; border-radius: 4px;
            font-size: 12px;
        }
    </style>
    <script>
        window.pendingState = null;
        window.isSceneReady = false;

        window.updateState = function(action, emotion, speed, eyeState) {
            if (!window.isSceneReady) {
                console.log("Queuing state update:", action);
                window.pendingState = { action, emotion, speed, eyeState };
                return;
            }
            if (window.moduleUpdateState) {
                window.moduleUpdateState(action, emotion, speed, eyeState);
            }
        };
    </script>
</head>
<body>
    <div id="status">Initializing WebView...</div>
    <div id="controls">
        <button onclick="testAnim('idle')">Idle</button>
        <button onclick="testAnim('wave')">Wave</button>
        <button onclick="testAnim('happy')">Happy</button>
        <button onclick="forceFallback()">Force Fallback</button>
        <button onclick="location.reload()">Reload</button>
    </div>
    <script type="module">
        window.onerror = function(message, source, lineno, colno, error) {
            const el = document.getElementById('status');
            if(el) el.innerHTML += "<br><span style='color:red'>JS Error: " + message + "</span>";
        };

        import * as THREE from 'https://esm.sh/three@0.154.0';
        import { GLTFLoader } from 'https://esm.sh/three@0.154.0/examples/jsm/loaders/GLTFLoader';
        import { FBXLoader } from 'https://esm.sh/three@0.154.0/examples/jsm/loaders/FBXLoader';

        let scene, camera, renderer, model, mixer;
        let animations = {};
        let currentActionName = 'idle';
        let morphTargetMesh = null;
        let targetMorphs = {};
        
        // PUBLIC FALLBACK URLS
        const fallbackAnims = {
            'idle': 'https://models.readyplayer.me/animations/idle.fbx',
            'wave': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/waving.fbx',
            'walk': 'https://models.readyplayer.me/animations/walking.fbx',
            'happy': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_happy.fbx',
            'angry': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_angry.fbx',
            'excited': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_happy.fbx',
            'talking_0': 'http://10.0.2.2:5000/animations/talking.fbx',
            'talking_1': 'http://10.0.2.2:5000/animations/talking.fbx',
            'talking_2': 'http://10.0.2.2:5000/animations/talking.fbx',
            'laughing': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_happy.fbx',
            'crying': 'https://models.readyplayer.me/animations/idle.fbx',
            'rumba': 'https://models.readyplayer.me/animations/idle.fbx'
        };

        const FALLBACK_AVATAR = 'https://models.readyplayer.me/64b73b537c6e7f7636363636.glb';

        function updateStatus(msg) {
            const el = document.getElementById('status');
            if(el) el.innerHTML = msg;
            console.log('[Status]', msg);
        }

        window.forceFallback = function() {
            updateStatus("Forcing Fallback Avatar...");
            loadAvatar(FALLBACK_AVATAR);
        };

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
        let blinkState = 'open'; 
        let blinkDuration = 0.15; 
        let blinkTimer = 0;
        let nextBlinkTime = 3.0;
        const blinkIntervals = { 'normal': [3.0, 5.0], 'soft': [4.0, 6.0], 'focused': [6.0, 10.0] };

        init();

        function init() {
            updateStatus("Initializing 3D Scene...");
            try {
                scene = new THREE.Scene();
                
                // Camera setup
                camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
                camera.position.set(0, 1.4, 2.5); // Standard RPM view

                renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
                renderer.setPixelRatio(window.devicePixelRatio);
                renderer.setSize(window.innerWidth, window.innerHeight);
                renderer.outputColorSpace = THREE.SRGBColorSpace;
                renderer.setClearColor(0x000000, 0); // Transparent clear color
                document.body.appendChild(renderer.domElement);

                // Lighting
                const ambientLight = new THREE.AmbientLight(0xffffff, 1.0);
                scene.add(ambientLight);

                const dirLight = new THREE.DirectionalLight(0xffffff, 1.5);
                dirLight.position.set(2, 2, 5);
                scene.add(dirLight);

                // Determine Avatar URL
                let avatarUrl = '${widget.avatarUrl}';
                if (!avatarUrl || avatarUrl === 'null' || avatarUrl.trim() === '' || !avatarUrl.startsWith('http')) {
                    avatarUrl = FALLBACK_AVATAR;
                    updateStatus("Invalid URL. Using Fallback.");
                } else {
                    updateStatus("URL Found. Loading...");
                }
                
                loadAvatar(avatarUrl);

            } catch (e) {
                updateStatus("Init Error: " + e.message);
            }

            window.addEventListener('resize', onWindowResize);
            window.addEventListener('message', handleMessage);
            
            window.testAnim = (name) => {
                 window.moduleUpdateState(name, 'neutral', 1.0, 'normal');
            };
            
            window.moduleUpdateState = (action, emotion, speed, eyeState) => {
                console.log('UpdateState:', { action, emotion, speed, eyeState });
                window.currentEyeState = eyeState; 
                
                try {
                    let animName = action.toLowerCase();
                    
                    if (animName.startsWith('talking')) {
                        window.isTalking = true;
                        if (!animations[animName] && !fallbackAnims[animName]) animName = 'idle';
                    } else {
                        window.isTalking = false;
                    }

                    if (animName === 'talk_hands') animName = 'idle'; 
                    else if (animName === 'explain_hands') animName = 'idle'; 
                    else if (animName === 'encourage_hands') animName = 'happy'; 
                    
                    if (!animations[animName] && animations[emotion]) animName = emotion;

                    // Safe Animation Fallback
                    if (!animations[animName] && !fallbackAnims[animName]) {
                        console.warn(`Animation '\${animName}' not found. Falling back to 'idle'.`);
                        animName = 'idle';
                    }

                    let targetAnim = animations[animName];
                    if (targetAnim) {
                        if (animName !== currentActionName) {
                            if (animations[currentActionName]) {
                                animations[currentActionName].fadeOut(0.5);
                            }
                            targetAnim.reset().fadeIn(0.5).play();
                            currentActionName = animName;
                        }
                    } else {
                        // Fallback to idle if requested animation is missing
                        if (currentActionName !== 'idle' && animations['idle']) {
                            if (animations[currentActionName]) animations[currentActionName].fadeOut(0.5);
                            animations['idle'].reset().fadeIn(0.5).play();
                            currentActionName = 'idle';
                        }
                    }
                    
                    if (animations[currentActionName]) {
                        animations[currentActionName].timeScale = speed || 1.0;
                    }

                } catch (e) { console.warn("Animation update failed:", e); }
                
                try {
                    if (morphTargetMesh) {
                        // Safe Emotion Fallback
                        let emotionTargets = emotionMap[emotion];
                        if (!emotionTargets) {
                             console.warn(`Emotion '\${emotion}' not found. Falling back to 'neutral'.`);
                             emotionTargets = emotionMap['neutral'];
                        }
                        const eyeTargets = eyeStateMap[eyeState] || eyeStateMap['normal'];
                        const allKeys = new Set([...Object.keys(emotionMap).flatMap(k => Object.keys(emotionMap[k])), ...Object.keys(eyeStateMap).flatMap(k => Object.keys(eyeStateMap[k]))]);
                        allKeys.forEach(key => targetMorphs[key] = 0.0);
                        Object.entries(emotionTargets).forEach(([key, val]) => targetMorphs[key] = val);
                        Object.entries(eyeTargets).forEach(([key, val]) => targetMorphs[key] = Math.max(targetMorphs[key] || 0, val));
                    }
                } catch (e) { console.warn("Morph target update failed:", e); }
            };
        }

        function loadAvatar(url) {
            if(model) {
                scene.remove(model);
                model = null;
                mixer = null;
                animations = {};
                morphTargetMesh = null;
            }

            const loader = new GLTFLoader();
            updateStatus("Loading: " + url.split('/').pop());
            
            loader.load(url, (gltf) => {
                updateStatus("Avatar Loaded. Setup...");
                model = gltf.scene;
                scene.add(model);
                
                // Center model
                const box = new THREE.Box3().setFromObject(model);
                const center = box.getCenter(new THREE.Vector3());
                model.position.x += (model.position.x - center.x);
                model.position.y -= box.min.y; // Put feet on ground
                
                let modelBones = {};
                model.traverse((child) => {
                    if (child.isBone) {
                        modelBones[child.name] = child;
                    }
                    if (child.isMesh) {
                        child.frustumCulled = false; 
                        if (child.morphTargetDictionary) {
                            morphTargetMesh = child;
                            console.log("Morph Targets Found:", Object.keys(child.morphTargetDictionary));
                        }
                    }
                });
                console.log("Bones Found:", Object.keys(modelBones));

                mixer = new THREE.AnimationMixer(model);
                
                // FIX 2: Avatar-First Loading
                // Show avatar immediately, load animations in background
                updateStatus("Ready. Companion Active.");
                setTimeout(() => { 
                    const statusEl = document.getElementById('status');
                    if(statusEl) statusEl.style.display = 'none'; 
                }, 500);

                window.isSceneReady = true;
                animate(); // Start rendering loop immediately

                // Load animations in background
                const backendUrl = 'http://172.16.0.200:5000/animations'; 
                
                const animsToLoad = [
                    { url: backendUrl + '/Breathing%20Idle.fbx', name: 'idle' },
                    { url: backendUrl + '/Happy%20Hand%20Gesture.fbx', name: 'wave' },
                    { url: backendUrl + '/Walking.fbx', name: 'walk' },
                    { url: backendUrl + '/Happy.fbx', name: 'happy' },
                    { url: backendUrl + '/Yelling.fbx', name: 'angry' },
                    { url: backendUrl + '/Excited.fbx', name: 'excited' }
                ];

                animsToLoad.forEach(anim => {
                    loadExternalAnimation(anim.url, anim.name, modelBones, () => {
                        // If idle loaded and we are currently idle, play it
                        if (anim.name === 'idle' && currentActionName === 'idle') {
                            if (animations['idle']) animations['idle'].play();
                        }
                    });
                });
                
                // Apply pending state if any
                if (window.pendingState) {
                    window.moduleUpdateState(
                        window.pendingState.action, 
                        window.pendingState.emotion, 
                        window.pendingState.speed, 
                        window.pendingState.eyeState
                    );
                    window.pendingState = null;
                }

            }, undefined, (err) => {
                updateStatus("Error Loading Avatar: " + err.message);
                console.error("Failed to load avatar:", err);
            });
        }

        function loadExternalAnimation(url, name, modelBones, onSuccess) {
            const isFbx = url.toLowerCase().endsWith('.fbx');
            const loader = isFbx ? new FBXLoader() : new GLTFLoader();
            
            const boneMap = {
                'Hips': 'Hips', 'Spine': 'Spine', 'Spine1': 'Spine1', 'Spine2': 'Spine2',
                'Neck': 'Neck', 'Head': 'Head', 'LeftShoulder': 'LeftShoulder', 'LeftArm': 'LeftArm',
                'LeftForeArm': 'LeftForeArm', 'LeftHand': 'LeftHand', 'RightShoulder': 'RightShoulder',
                'RightArm': 'RightArm', 'RightForeArm': 'RightForeArm', 'RightHand': 'RightHand',
                'LeftUpLeg': 'LeftUpLeg', 'LeftLeg': 'LeftLeg', 'LeftFoot': 'LeftFoot',
                'RightUpLeg': 'RightUpLeg', 'RightLeg': 'RightLeg', 'RightFoot': 'RightFoot',
                'mixamorigHips': 'Hips', 'mixamorigSpine': 'Spine', 'mixamorigLeftArm': 'LeftArm', 'mixamorigRightArm': 'RightArm'
            };

            loader.load(url, (asset) => {
                let clip = asset.animations[0];
                if (clip) {
                    // Retargeting logic
                    clip.tracks.forEach(track => {
                        let cleanName = track.name.replace(/mixamorig:|mixamorig1:/g, '');
                        let trackBoneName = cleanName.split('.')[0];
                        let property = cleanName.split('.').slice(1).join('.');
                        let targetBoneName = null;
                        if (modelBones[trackBoneName]) targetBoneName = trackBoneName;
                        else {
                            const lower = trackBoneName.toLowerCase();
                            const match = Object.keys(modelBones).find(k => k.toLowerCase() === lower);
                            if (match) targetBoneName = match;
                        }
                        if (!targetBoneName && boneMap[trackBoneName]) {
                            let mappedName = boneMap[trackBoneName];
                            if (modelBones[mappedName]) targetBoneName = mappedName;
                        }
                        if (targetBoneName) {
                            track.name = targetBoneName + '.' + property;
                        }
                    });

                    const action = mixer.clipAction(clip);
                    animations[name] = action;
                    if (name === 'idle' && currentActionName === 'idle') action.reset().play();
                    if (onSuccess) onSuccess();

        function handleMessage(event) {
             if (typeof event.data === 'string' && event.data.startsWith('updateState')) {
                try { eval(event.data); } catch (e) { console.error('Error executing command:', e); }
            }
        }
        function onWindowResize() {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        }
        function animate() {
            requestAnimationFrame(animate);
            const delta = 0.016; 
            if (mixer) mixer.update(delta);
            
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

            if (morphTargetMesh && morphTargetMesh.morphTargetDictionary) {
                let currentTargets = { ...targetMorphs };
                
                if (window.isTalking) {
                     const time = Date.now() * 0.015; 
                     const openAmount = (Math.sin(time) * 0.5 + 0.5) * (Math.cos(time * 0.8) * 0.5 + 0.5); 
                     let mouthTarget = morphTargetMesh.morphTargetDictionary['mouthOpen'] !== undefined ? 'mouthOpen' 
                                       : morphTargetMesh.morphTargetDictionary['viseme_aa'] !== undefined ? 'viseme_aa' : null;
                     
                     // Safe fallback: use the first available morph target if specific ones are missing (unlikely but safe)
                     if (!mouthTarget && Object.keys(morphTargetMesh.morphTargetDictionary).length > 0) {
                        mouthTarget = Object.keys(morphTargetMesh.morphTargetDictionary)[0];
                     }

                     if (mouthTarget) {
                         currentTargets[mouthTarget] = Math.max(currentTargets[mouthTarget] || 0, openAmount * 0.6);
                     }
                }

                if (blinkState !== 'open') {
                    let blinkWeight = 0;
                    if (blinkState === 'closing') blinkWeight = blinkTimer / (blinkDuration / 2);
                    else blinkWeight = 1.0 - ((blinkTimer - (blinkDuration / 2)) / (blinkDuration / 2));
                    currentTargets['eyeBlinkLeft'] = Math.max(currentTargets['eyeBlinkLeft'] || 0, blinkWeight);
                    currentTargets['eyeBlinkRight'] = Math.max(currentTargets['eyeBlinkRight'] || 0, blinkWeight);
                }
                
                Object.keys(currentTargets).forEach(key => {
                    if (morphTargetMesh.morphTargetDictionary[key] !== undefined) {
                        const idx = morphTargetMesh.morphTargetDictionary[key];
                        const current = morphTargetMesh.morphTargetInfluences[idx];
                        const target = currentTargets[key];
                        morphTargetMesh.morphTargetInfluences[idx] += (target - current) * 0.1; 
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
