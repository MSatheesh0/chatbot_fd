import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
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
  final String _viewType = 'avatar-3d-view-stable';
  html.IFrameElement? _iframe;
  static bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
  }

  void _registerViewFactory() {
    if (_isRegistered) return;
    
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..id = 'avatar-iframe'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = 'transparent'
          ..style.pointerEvents = 'none' // Allow clicks to pass through to Flutter
          ..srcdoc = _getHtmlContent();
        
        _iframe = iframe;
        return iframe;
      },
    );
    _isRegistered = true;
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
      // Use postMessage to change avatar instead of reloading iframe
      _iframe?.contentWindow?.postMessage({
        'type': 'loadAvatar',
        'url': widget.avatarUrl
      }, '*');
    }
  }

  void _updateAvatarState() {
    try {
      final data = {
        'type': 'updateState',
        'action': widget.action,
        'emotion': widget.emotion,
        'speed': widget.speed,
        'eyeState': widget.eyeState,
        'isTalking': widget.isTalking,
      };
      _iframe?.contentWindow?.postMessage(data, '*');
    } catch (e) {
      debugPrint('Error updating avatar state: $e');
    }
  }

  String _getHtmlContent() {
    String backendUrl = ApiConstants.baseUrl;
    if (backendUrl.endsWith('/')) {
      backendUrl = backendUrl.substring(0, backendUrl.length - 1);
    }
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="referrer" content="no-referrer">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body { 
            margin: 0; 
            overflow: hidden; 
            background: transparent; 
            width: 100vw; 
            height: 100vh; 
            transition: background 1.5s ease; /* Smooth environment transition */
        }
        canvas { 
            width: 100%; 
            height: 100%; 
            display: block; 
            outline: none; 
            pointer-events: none; 
        }
        #status {
            position: absolute;
            bottom: 120px;
            left: 20px;
            color: #0f0;
            background: rgba(0, 0, 0, 0.8);
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
            font-size: 12px;
            z-index: 1000;
            display: none; /* Hide status by default */
            pointer-events: none;
        }
    </style>
    <script>
        window.pendingState = null;
        window.isSceneReady = false;

        window.addEventListener('message', function(event) {
            const data = event.data;
            if (data && data.type === 'updateState') {
                if (!window.isSceneReady) {
                    window.pendingState = data;
                    return;
                }
                if (window.moduleUpdateState) {
                    window.moduleUpdateState(data.action, data.emotion, data.speed, data.eyeState, data.isTalking);
                }
            } else if (data && data.type === 'loadAvatar') {
                if (window.loadAvatar) window.loadAvatar(data.url);
            }
        });
    </script>
</head>
<body>
    <div id="status">Initializing 3D...</div>
    <script type="module">
        import * as THREE from 'https://esm.sh/three@0.154.0';
        import { GLTFLoader } from 'https://esm.sh/three@0.154.0/examples/jsm/loaders/GLTFLoader';
        import { FBXLoader } from 'https://esm.sh/three@0.154.0/examples/jsm/loaders/FBXLoader';

        let scene, camera, renderer, model, mixer;
        let animations = {};
        let currentActionName = 'idle';
        let morphTargetMesh = null;
        let targetMorphs = {};
        let initialPos = { x: 0, y: 0, z: 0 };
        
        const FALLBACK_AVATAR = 'https://models.readyplayer.me/638df693d72bffc6fa17d4f2.glb';
        
        const fallbackAnims = {
            'idle': 'https://models.readyplayer.me/animations/idle.fbx',
            'wave': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/waving.fbx',
            'walk': 'https://models.readyplayer.me/animations/walking.fbx',
            'happy': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_happy.fbx',
            'angry': 'https://raw.githubusercontent.com/readyplayerme/visage/master/animations/idle_angry.fbx',
            'talking': '$backendUrl/animations/talking.fbx'
        };

        const emotionMap = {
            'happy': { 
                'mouthSmile': 0.8, 
                'mouthSmileLeft': 0.8, 
                'mouthSmileRight': 0.8, 
                'eyeSquintLeft': 0.5, 
                'eyeSquintRight': 0.5,
                'cheekPuff': 0.2
            },
            'sad': { 
                'mouthFrownLeft': 0.8, 
                'mouthFrownRight': 0.8, 
                'browInnerUp': 0.8, 
                'eyeSquintLeft': 0.2, 
                'eyeSquintRight': 0.2 
            },
            'angry': { 
                'browDownLeft': 1.0, 
                'browDownRight': 1.0, 
                'mouthFrownLeft': 0.8, 
                'mouthFrownRight': 0.8, 
                'eyeSquintLeft': 0.5, 
                'eyeSquintRight': 0.5 
            },
            'surprised': { 
                'jawOpen': 0.4, 
                'browOuterUpLeft': 1.0, 
                'browOuterUpRight': 1.0, 
                'eyeWideLeft': 0.8, 
                'eyeWideRight': 0.8 
            },
            'excited': { 
                'mouthSmile': 1.0, 
                'mouthSmileLeft': 1.0, 
                'mouthSmileRight': 1.0, 
                'eyeWideLeft': 0.6, 
                'eyeWideRight': 0.6, 
                'jawOpen': 0.2,
                'cheekPuff': 0.3
            },
            'neutral': { 
                'mouthSmile': 0.0, 
                'mouthSmileLeft': 0.0, 
                'mouthSmileRight': 0.0, 
                'browInnerUp': 0.0, 
                'browDownLeft': 0.0, 
                'jawOpen': 0.0, 
                'eyeWideLeft': 0.0, 
                'eyeWideRight': 0.0 
            }
        };

        const eyeStateMap = {
            'normal': { 'eyeBlinkLeft': 0.0, 'eyeBlinkRight': 0.0, 'eyeWideLeft': 0.0, 'eyeWideRight': 0.0 },
            'focused': { 'eyeSquintLeft': 0.8, 'eyeSquintRight': 0.8, 'browDownLeft': 0.3, 'browDownRight': 0.3 },
            'soft': { 'eyeSquintLeft': 0.4, 'eyeSquintRight': 0.4, 'browInnerUp': 0.3 },
            'blink': { 'eyeBlinkLeft': 1.0, 'eyeBlinkRight': 1.0 }
        };

        // Environment Background Map
        const environmentMap = {
            'neutral': 'linear-gradient(135deg, #fdfcfb 0%, #e2d1c3 100%)',
            'happy': 'linear-gradient(120deg, #f6d365 0%, #fda085 100%)',
            'excited': 'linear-gradient(to top, #f093fb 0%, #f5576c 100%)',
            'sad': 'linear-gradient(to top, #cfd9df 0%, #e2ebf0 100%)',
            'angry': 'linear-gradient(to top, #ff0844 0%, #ffb199 100%)',
            'surprised': 'linear-gradient(120deg, #84fab0 0%, #8fd3f4 100%)',
            'dance': 'linear-gradient(-225deg, #2CD8D5 0%, #C5C1FF 56%, #FFBAC3 100%)',
            'sleeping': 'linear-gradient(to top, #09203f 0%, #537895 100%)',
            'laying': 'linear-gradient(to top, #a18cd1 0%, #fbc2eb 100%)'
        };
        function updateStatus(msg) {
            const el = document.getElementById('status');
            if(el) {
                el.style.display = 'block';
                el.innerHTML = msg;
            }
            console.log('[AvatarView] ' + msg);
        }

        init();

        function init() {
            try {
                scene = new THREE.Scene();
                
                camera = new THREE.PerspectiveCamera(35, window.innerWidth / window.innerHeight, 0.1, 1000);
                camera.position.set(0, 1.45, 1.8);
                camera.lookAt(0, 1.4, 0);

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
                dirLight.position.set(5, 10, 5);
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

                window.addEventListener('resize', onWindowResize);
                setTimeout(onWindowResize, 500);
                
                animate();
            } catch (e) {
                console.error("Init Error:", e);
                updateStatus("Init Error: " + e.message);
            }
        }

        function onWindowResize() {
            const width = window.innerWidth;
            const height = window.innerHeight;
            if (width === 0 || height === 0) return;
            camera.aspect = width / height;
            camera.updateProjectionMatrix();
            renderer.setSize(width, height);
        }

        let headBone = null;
        let neckBone = null;

        function loadAvatar(url) {
            console.log("Attempting to load avatar from:", url);
            updateStatus("Loading Model...");
            const loader = new GLTFLoader();
            loader.setCrossOrigin('anonymous');
            
            loader.load(url, (gltf) => {
                console.log("Avatar loaded successfully");
                if (model) scene.remove(model);
                
                model = gltf.scene;
                scene.add(model);
                
                const box = new THREE.Box3().setFromObject(model);
                const center = box.getCenter(new THREE.Vector3());
                
                initialPos.x = -center.x;
                initialPos.y = -box.min.y;
                initialPos.z = -center.z;
                
                model.position.set(initialPos.x, initialPos.y, initialPos.z);
                
                updateStatus("Model Ready");
                
                headBone = null;
                neckBone = null;

                model.traverse((child) => {
                    child.visible = true;
                    if (child.isBone) {
                        const name = child.name.toLowerCase();
                        if (name === 'head') headBone = child;
                        if (name === 'neck') neckBone = child;
                    }
                    if (child.isMesh) {
                        child.frustumCulled = false;
                        child.castShadow = true;
                        child.receiveShadow = true;
                        
                        const materials = Array.isArray(child.material) ? child.material : [child.material];
                        materials.forEach(mat => {
                            if (mat) {
                                mat.transparent = true;
                                mat.depthWrite = true;
                                mat.roughness = 0.6;
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
                
                if (gltf.animations && gltf.animations.length > 0) {
                    gltf.animations.forEach(clip => {
                        let name = clip.name.toLowerCase();
                        if (name.includes('idle')) name = 'idle';
                        else if (name.includes('talk')) name = 'talk';
                        else if (name.includes('walk')) name = 'walk';
                        else if (name.includes('wave')) name = 'wave';
                        animations[name] = mixer.clipAction(clip);
                    });
                }

                if (animations['idle']) {
                    animations['idle'].play();
                    currentActionName = 'idle';
                }

                window.isSceneReady = true;
                
                const animBase = '$backendUrl/animations';
                const animsToLoad = [
                    { url: animBase + '/Breathing%20Idle.fbx', name: 'idle' },
                    { url: animBase + '/Happy%20Hand%20Gesture.fbx', name: 'wave' },
                    { url: animBase + '/Walking.fbx', name: 'walk' },
                    { url: animBase + '/Happy.fbx', name: 'happy' },
                    { url: animBase + '/Angry.fbx', name: 'angry' },
                    { url: animBase + '/Yelling.fbx', name: 'yell' },
                    { url: animBase + '/Talking.fbx', name: 'talking' },
                    { url: animBase + '/Sad%20Idle.fbx', name: 'sad' },
                    { url: animBase + '/Angry%20Point.fbx', name: 'angry_point' },
                    { url: animBase + '/Excited.fbx', name: 'excited' },
                    { url: animBase + '/Happy%20Walk.fbx', name: 'happy_walk' },
                    { url: animBase + '/Kneeling%20Idle.fbx', name: 'kneeling' },
                    { url: animBase + '/Male%20Laying%20Pose.fbx', name: 'laying' },
                    { url: animBase + '/Rejected.fbx', name: 'rejected' },
                    { url: animBase + '/Sitting%20Angry.fbx', name: 'sitting_angry' },
                    { url: animBase + '/Sitting%20Disbelief.fbx', name: 'sitting_disbelief' },
                    { url: animBase + '/Sleeping%20Idle.fbx', name: 'sleep' },
                    { url: animBase + '/Step%20Hip%20Hop%20Dance.fbx', name: 'dance' }
                ];

                animsToLoad.forEach(anim => {
                    loadExternalAnimation(anim.url, anim.name);
                });

                if (window.pendingState) {
                    window.moduleUpdateState(window.pendingState.action, window.pendingState.emotion, window.pendingState.speed, window.pendingState.eyeState, window.pendingState.isTalking);
                    window.pendingState = null;
                }
                
                setTimeout(() => { 
                    const el = document.getElementById('status');
                    if(el) el.style.display = 'none';
                }, 3000);
            }, (xhr) => {
                if (xhr.total > 0) {
                    const p = (xhr.loaded / xhr.total * 100).toFixed(0);
                    updateStatus("Loading: " + p + "%");
                }
            }, (err) => {
                console.error("Avatar Load Error:", err);
                updateStatus("Load Error: " + (err.message || "Check Connection"));
                if (url !== FALLBACK_AVATAR) {
                    console.log("Retrying with fallback...");
                    loadAvatar(FALLBACK_AVATAR);
                }
            });
        }

        window.queuedAction = null;
        window.currentSpeed = 1.0;

        window.moduleUpdateState = (action, emotion, speed, eyeState, isTalking) => {
            window.isTalking = isTalking;
            window.currentEyeState = eyeState;
            window.currentSpeed = speed || 1.0;
            
            let animName = action.toLowerCase();
            
            if (animName === 'laugh') animName = animations['laughing'] ? 'laughing' : 'happy';
            else if (animName === 'angry') animName = animations['angry'] ? 'angry' : 'idle';
            else if (animName === 'yell' || animName === 'yelling') animName = animations['yell'] ? 'yell' : 'angry';
            else if (animName === 'wave' || animName === 'waving') animName = animations['wave'] ? 'wave' : 'idle';
            else if (animName === 'walk' || animName === 'walking') animName = animations['walk'] ? 'walk' : (animations['happy_walk'] ? 'happy_walk' : 'idle');
            else if (animName === 'sad') animName = animations['sad'] ? 'sad' : 'idle';
            else if (animName === 'dance' || animName === 'dancing') animName = animations['dance'] ? 'dance' : 'idle';
            else if (animName === 'sleep' || animName === 'sleeping') animName = animations['sleep'] ? 'sleep' : 'idle';
            else if (animName === 'sit' || animName === 'sitting') animName = animations['sitting_angry'] ? 'sitting_angry' : (animations['sitting_disbelief'] ? 'sitting_disbelief' : 'idle');
            else if (animName === 'kneel' || animName === 'kneeling') animName = animations['kneeling'] ? 'kneeling' : 'idle';
            else if (animName === 'lay' || animName === 'laying') animName = animations['laying'] ? 'laying' : 'idle';
            else if (animName === 'reject' || animName === 'rejected') animName = animations['rejected'] ? 'rejected' : 'idle';
            else if (animName === 'point' || animName === 'angry_point') animName = animations['angry_point'] ? 'angry_point' : 'idle';
            else if (animName === 'talk' || animName === 'talking') animName = 'talking';

            // Update currentActionName
            const oldActionName = currentActionName;
            currentActionName = animName;

            if (animations[animName]) {
                window.queuedAction = null;
                if (animName !== oldActionName || ['wave', 'yell', 'angry_point', 'excited', 'dance'].includes(animName)) {
                    if (animations[oldActionName]) animations[oldActionName].fadeOut(0.3);
                    animations[animName].reset().fadeIn(0.3).play();
                }
                animations[animName].timeScale = window.currentSpeed;
            } else {
                console.log("Animation not loaded yet, queuing:", animName);
                window.queuedAction = animName;
                
                const fallback = animations['talking'] ? 'talking' : 'idle';
                if (fallback && fallback !== oldActionName && animations[fallback]) {
                    if (animations[oldActionName]) animations[oldActionName].fadeOut(0.3);
                    animations[fallback].reset().fadeIn(0.3).play();
                }
            }

            // Morph targets for emotions
            if (morphTargetMesh) {
                const emotions = emotionMap[emotion] || emotionMap['neutral'];
                Object.keys(targetMorphs).forEach(k => targetMorphs[k] = 0);
                Object.entries(emotions).forEach(([k, v]) => targetMorphs[k] = v);
            }
        };

        function loadExternalAnimation(url, name) {
            const loader = new FBXLoader();
            loader.setCrossOrigin('anonymous');
            loader.load(url, (asset) => {
                let clip = asset.animations[0];
                if (clip && model) {
                    let modelBones = {};
                    model.traverse(c => { if(c.isBone) modelBones[c.name] = c; });

                    clip.tracks = clip.tracks.filter(track => track.name.includes('.quaternion'));

                    clip.tracks.forEach(track => {
                        let cleanName = track.name.replace(/.*:|.*1:/g, '');
                        let trackBoneName = cleanName.split('.')[0];
                        let property = cleanName.split('.').slice(1).join('.');
                        
                        let targetBoneName = null;
                        
                        const boneMap = {
                            'Hips': ['Hips', 'Pelvis', 'Groin', 'root'],
                            'Spine': ['Spine', 'Spine1', 'Spine2'],
                            'Neck': ['Neck', 'Neck1', 'Chin'],
                            'Head': ['Head', 'head'],
                            'LeftArm': ['LeftArm', 'LeftShoulder'],
                            'LeftForeArm': ['LeftForeArm', 'LeftArm', 'LeftElbow'],
                            'LeftHand': ['LeftHand', 'LeftWrist'],
                            'RightArm': ['RightArm', 'RightShoulder'],
                            'RightForeArm': ['RightForeArm', 'RightArm', 'RightElbow'],
                            'RightHand': ['RightHand', 'RightWrist'],
                            'LeftUpLeg': ['LeftUpLeg', 'LeftThigh'],
                            'LeftLeg': ['LeftLeg', 'LeftKnee'],
                            'RightUpLeg': ['RightUpLeg', 'RightThigh'],
                            'RightLeg': ['RightLeg', 'RightKnee']
                        };

                        if (modelBones[trackBoneName]) {
                            targetBoneName = trackBoneName;
                        } else {
                            const lower = trackBoneName.toLowerCase();
                            const mixamoClean = lower.replace('mixamorig', '');
                            
                            targetBoneName = Object.keys(modelBones).find(k => {
                                const kl = k.toLowerCase();
                                return kl === lower || kl.includes(mixamoClean);
                            });

                            if (!targetBoneName) {
                                for (const [standard, aliases] of Object.entries(boneMap)) {
                                    if (aliases.some(a => lower.includes(a.toLowerCase()))) {
                                        targetBoneName = Object.keys(modelBones).find(k => k.toLowerCase().includes(standard.toLowerCase()));
                                        if (targetBoneName) break;
                                    }
                                }
                            }
                        }

                        if (targetBoneName) track.name = targetBoneName + '.' + property;
                    });

                    const action = mixer.clipAction(clip);
                    animations[name] = action;
                    
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
                console.warn('[AvatarView] Failed to load animation:', name);
                if (fallbackAnims[name]) loadExternalAnimation(fallbackAnims[name], name);
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

        window.loadAvatar = loadAvatar;
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: _viewType,
    );
  }
}
