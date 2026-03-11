import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:hugeicons/hugeicons.dart';

// ==========================================
// 1. The Flutter Widget (UI Layer)
// ==========================================

class PlyViewer extends StatefulWidget {
  final String filePath;
  final Color backgroundColor;

  const PlyViewer({
    super.key,
    required this.filePath,
    required this.backgroundColor,
  });

  @override
  State<PlyViewer> createState() => _PlyViewerState();
}

class _PlyViewerState extends State<PlyViewer> {
  late final PlatformViewer _platformViewer;
  bool _isLoading = true;
  int _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _platformViewer = PlatformViewer(
      filePath: widget.filePath,
      backgroundColor: widget.backgroundColor,
      onLoaded: () {
        if (mounted) setState(() => _isLoading = false);
      },
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        }
      },
      onParsing: () {
        // Optional parsing status
      },
    );

    _platformViewer.init();
  }

  @override
  void dispose() {
    _platformViewer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        // 3D View fills available space
        Expanded(
          child: Stack(
            children: [
              _platformViewer.buildView(context),

              // Custom Loader (shadcn-style)
              if (_isLoading && _errorMessage == null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(20, 2, 6, 23),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFA78BFA),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Drawing your model $_progress%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error Message
              if (_errorMessage != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x1AEF4444),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x4DEF4444)),
                    ),
                    child: Text(
                      'Error: $_errorMessage',
                      style: const TextStyle(color: Color(0xFFEF4444)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Control bar sits OUTSIDE the WebView so it always receives taps
        Container(
          padding: EdgeInsets.only(top: 12, bottom: 12 + bottomInset),
          color: widget.backgroundColor,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ControlButton(
                  icon: HugeIcons.strokeRoundedPlusSign,
                  onTap: () => _platformViewer.zoomIn(),
                ),
                const SizedBox(width: 8),
                _ControlButton(
                  icon: HugeIcons.strokeRoundedMinusSign,
                  onTap: () => _platformViewer.zoomOut(),
                ),
                const SizedBox(width: 8),
                _ControlButton(
                  icon: HugeIcons.strokeRoundedHouse03,
                  onTap: () => _platformViewer.toggleLookInside(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small tappable control button used in the 3D viewer overlay.
class _ControlButton extends StatefulWidget {
  final dynamic icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(15, 2, 6, 23),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: HugeIcon(
              icon: widget.icon,
              size: 18,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. The Logic Class (Server & WebView)
// ==========================================

class PlatformViewer {
  final String filePath;
  final Color backgroundColor;
  final VoidCallback onLoaded;
  final void Function(int) onProgress;
  final void Function(String) onError;
  final VoidCallback onParsing;

  WebViewController? _controller;
  HttpServer? _server;
  int _serverPort = 0;
  final UniqueKey _webViewKey = UniqueKey();
  bool _jsReady = false;

  PlatformViewer({
    required this.filePath,
    required this.backgroundColor,
    required this.onLoaded,
    required this.onProgress,
    required this.onError,
    required this.onParsing,
  });

  void init() {
    debugPrint('PlyViewer init: $filePath');
    _startServerAndLoad();
  }

  void dispose() {
    _server?.close(force: true);
  }

  Widget buildView(BuildContext context) {
    if (_controller == null) {
      return const SizedBox.shrink();
    }
    return WebViewWidget(key: _webViewKey, controller: _controller!);
  }

  Future<void> zoomIn() async {
    if (_controller == null) return;
    await _controller!.runJavaScript('window.zoomBy && window.zoomBy(0.75);');
  }

  Future<void> zoomOut() async {
    if (_controller == null) return;
    await _controller!.runJavaScript('window.zoomBy && window.zoomBy(1.35);');
  }

  Future<void> toggleLookInside() async {
    if (_controller == null) return;
    await _controller!.runJavaScript(
      'window.toggleLookInside && window.toggleLookInside();',
    );
  }

  Future<void> _startServerAndLoad() async {
    try {
      final isRemote = filePath.startsWith('http');
      final modelPath = _modelRoutePath(filePath);

      File? localFile;
      if (!isRemote) {
        localFile = File(filePath);
        if (!await localFile.exists()) {
          throw Exception("File not found: $filePath");
        }
      }

      Response handler(Request request) {
        final path = request.url.path;

        final headers = {
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'public, max-age=3600',
        };

        if (path == '' || path == 'index.html') {
          return _serveHtml(headers);
        }

        if (path == modelPath) {
          if (isRemote) {
            return _serveRemoteFile(filePath);
          }
          return _serveLocalFile(localFile!, headers);
        }

        return Response.notFound('Not found');
      }

      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      _serverPort = _server!.port;

      _initWebView('http://localhost:$_serverPort/index.html');
    } catch (e) {
      onError("Setup Error: $e");
    }
  }

  Response _serveHtml(Map<String, String> baseHeaders) {
    final headers = Map<String, String>.from(baseHeaders);
    headers['content-type'] = 'text/html';
    return Response.ok(_getViewerHtml(), headers: headers);
  }

  Response _serveLocalFile(File file, Map<String, String> baseHeaders) {
    final stat = file.statSync();
    final headers = Map<String, String>.from(baseHeaders);
    headers['content-type'] = _contentTypeForPath(file.path);
    headers['content-length'] = stat.size.toString();

    return Response.ok(file.openRead(), headers: headers);
  }

  Response _serveRemoteFile(String url) {
    return Response.ok(
      () async* {
        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(url));
          request.headers.set(
            HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (Flutter; Dart)',
          );
          final response = await request.close();
          yield* response;
        } finally {
          client.close(force: true);
        }
      }(),
      headers: {
        'content-type': _contentTypeForPath(url),
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  String _modelRoutePath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.glb')) return 'model.glb';
    if (lower.endsWith('.gltf')) return 'model.gltf';
    return 'model.ply';
  }

  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.glb')) return 'model/gltf-binary';
    if (lower.endsWith('.gltf')) return 'model/gltf+json';
    return 'application/octet-stream';
  }

  void _initWebView(String initialUrl) {
    late final PlatformWebViewControllerCreationParams params;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      WebViewPlatform.instance ??= WebKitWebViewPlatform();
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      WebViewPlatform.instance ??= AndroidWebViewPlatform();
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(backgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {},
          onWebResourceError: (error) {
            debugPrint("PlyViewer WebView error: ${error.description}");
          },
        ),
      )
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (message) => _handleJsMessage(message.message),
      )
      ..loadRequest(Uri.parse(initialUrl));

    _controller = controller;
  }

  void _triggerJsLoad() {
    if (_controller == null || !_jsReady) return;

    final modelPath = _modelRoutePath(filePath);
    final localModelUrl = 'http://localhost:$_serverPort/$modelPath';
    final colorHex = '#${backgroundColor.value.toRadixString(16).substring(2)}';

    _controller!.runJavaScript('setBackgroundColor("$colorHex")');
    _controller!.runJavaScript('loadFromUrl("$localModelUrl")');
  }

  void _handleJsMessage(String message) {
    if (message == 'ready') {
      _jsReady = true;
      _triggerJsLoad();
    } else if (message == 'loaded') {
      onLoaded();
    } else if (message.startsWith('progress:')) {
      final progressStr = message.split(':')[1];
      final progress = int.tryParse(progressStr) ?? 0;
      onProgress(progress);
    } else if (message.startsWith('error:')) {
      onError(message.substring(6));
    }
  }

  String _getViewerHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>3D Viewer</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            width: 100%; height: 100%;
            overflow: hidden;
            background: transparent;
            touch-action: none;
            -webkit-user-select: none;
            user-select: none;
        }
        #container { width: 100%; height: 100%; }
        canvas { display: block; width: 100%; height: 100%; touch-action: none; }
        #controls { display: none; }
        #gesture-hint {
            position: fixed;
            bottom: 80px;
            left: 50%;
            transform: translateX(-50%);
            background: #1e293b;
            color: #ffffff;
            padding: 8px 10px;
            border-radius: 20px;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 13px;
            font-weight: 500;
            white-space: nowrap;
            visibility: hidden;
            opacity: 0;
            transition: opacity 0.4s, visibility 0.4s;
            pointer-events: none;
            z-index: 998;
        }
        #gesture-hint.show {
            visibility: visible;
            opacity: 1;
        }
    </style>
</head>
<body>
    <div id="container"></div>
    <div id="gesture-hint">Pinch to zoom · Drag to rotate · Two-finger drag to pan</div>

    <script type="importmap">
    {
        "imports": {
            "three": "https://cdn.jsdelivr.net/npm/three@0.162.0/build/three.module.js",
            "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.162.0/examples/jsm/"
        }
    }
    </script>
    <script type="module">
        import * as THREE from 'three';
        import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
        import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
        import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';

        const container = document.getElementById('container');
        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0xffffff);

        const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.001, 1000);
        camera.position.set(0, 0, 3);

        const renderer = new THREE.WebGLRenderer({
            antialias: true, alpha: true,
            powerPreference: "high-performance"
        });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
        renderer.outputColorSpace = THREE.SRGBColorSpace;
        renderer.toneMapping = THREE.ACESFilmicToneMapping;
        renderer.toneMappingExposure = 1.0;
        container.appendChild(renderer.domElement);

        const controls = new OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.dampingFactor = 0.08;
        controls.screenSpacePanning = true;
        controls.enablePan = true;
        controls.panSpeed = 1.0;
        controls.rotateSpeed = 1.0;
        controls.zoomSpeed = 1.2;
        controls.minDistance = 0;
        controls.maxDistance = 500;
        controls.target.set(0, 0, 0);
        controls.minPolarAngle = 0;
        controls.maxPolarAngle = Math.PI;
        controls.minAzimuthAngle = -Infinity;
        controls.maxAzimuthAngle = Infinity;
        controls.touches = {
            ONE: THREE.TOUCH.ROTATE,
            TWO: THREE.TOUCH.DOLLY_PAN
        };

        scene.add(new THREE.AmbientLight(0xffffff, 0.5));
        const keyLight = new THREE.DirectionalLight(0xffffff, 1.0);
        keyLight.position.set(5, 10, 7.5);
        scene.add(keyLight);
        const fillLight = new THREE.DirectionalLight(0xffffff, 0.4);
        fillLight.position.set(-5, 5, -5);
        scene.add(fillLight);
        const rimLight = new THREE.DirectionalLight(0xffffff, 0.3);
        rimLight.position.set(0, -5, -10);
        scene.add(rimLight);
        scene.add(new THREE.HemisphereLight(0xffffff, 0xcccccc, 0.4));

        const gltfLoader = new GLTFLoader();
        const dracoLoader = new DRACOLoader();
        dracoLoader.setDecoderPath('https://cdn.jsdelivr.net/npm/three@0.162.0/examples/jsm/libs/draco/');
        dracoLoader.preload();
        gltfLoader.setDRACOLoader(dracoLoader);

        let currentModel = null;
        let savedCamState = null;

        function send(msg) {
            if (window.Flutter) window.Flutter.postMessage(msg);
            console.log('Flutter:', msg);
        }

        function fitModelToView(object) {
            const box = new THREE.Box3().setFromObject(object);
            const center = box.getCenter(new THREE.Vector3());
            const size = box.getSize(new THREE.Vector3());
            const maxDim = Math.max(size.x, size.y, size.z);
            if (maxDim === 0) return;

            const targetSize = 2;
            const scale = targetSize / maxDim;
            object.scale.setScalar(scale);

            const scaledBox = new THREE.Box3().setFromObject(object);
            const scaledCenter = scaledBox.getCenter(new THREE.Vector3());
            object.position.sub(scaledCenter);

            const fov = camera.fov * (Math.PI / 180);
            const scaledSize = scaledBox.getSize(new THREE.Vector3());
            const maxScaledDim = Math.max(scaledSize.x, scaledSize.y, scaledSize.z);
            const cameraDistance = (maxScaledDim / 2) / Math.tan(fov / 2) * 1.5;

            camera.position.set(0, maxScaledDim * 0.3, Math.max(cameraDistance, 1));
            camera.near = 0.001;
            camera.far  = cameraDistance * 100;
            camera.updateProjectionMatrix();

            controls.target.set(0, 0, 0);
            controls.minDistance = 0;
            controls.maxDistance = cameraDistance * 20;
            controls.update();

            savedCamState = {
                pos: camera.position.clone(),
                target: controls.target.clone(),
                minDist: controls.minDistance,
                maxDist: controls.maxDistance,
                scaleY: object.scale.y
            };
        }

        window.loadFromUrl = function(url) {
            if (currentModel) { scene.remove(currentModel); currentModel = null; }

            gltfLoader.load(url, (gltf) => {
                const model = gltf.scene;

                model.traverse((child) => {
                    if (child.isMesh && child.material) {
                        child.material.side = THREE.DoubleSide;
                        if (child.material.map) child.material.map.colorSpace = THREE.SRGBColorSpace;
                    }
                    if (child.geometry && !child.geometry.attributes.normal) {
                        child.geometry.computeVertexNormals();
                    }
                });

                fitModelToView(model);
                model.scale.y *= -1;
                model.scale.x *= -1;
                model.scale.z *= -1;

                const recenteredBox = new THREE.Box3().setFromObject(model);
                const recenteredCenter = recenteredBox.getCenter(new THREE.Vector3());
                model.position.sub(recenteredCenter);
                controls.target.set(0, 0, 0);
                controls.update();

                currentModel = model;
                scene.add(model);
                send('loaded');
            },
            (xhr) => {
                if (xhr.total > 0) {
                    send('progress:' + Math.round((xhr.loaded / xhr.total) * 100));
                } else if (xhr.loaded > 0) {
                    send('progress:' + Math.min(Math.round(xhr.loaded / 10000), 99));
                }
            },
            (err) => { send('error:' + (err.message || 'Load failed')); });
        };

        window.setBackgroundColor = function(hex) {
            scene.background = new THREE.Color(hex);
        };

        window.resetCamera = function() {
            if (savedCamState) {
                camera.position.copy(savedCamState.pos);
                controls.target.copy(savedCamState.target);
                controls.minDistance = savedCamState.minDist;
                controls.maxDistance = savedCamState.maxDist;
                controls.update();
            } else {
                camera.position.set(0, 0, 3);
                controls.target.set(0, 0, 0);
                controls.update();
            }
        };

        window.zoomBy = function(factor) {
            const dir = new THREE.Vector3().subVectors(camera.position, controls.target);
            dir.multiplyScalar(factor);
            camera.position.copy(controls.target).add(dir);
            controls.update();
        };

        let insideMode = false;
        window.toggleLookInside = function() {
            if (!currentModel) return;
            insideMode = !insideMode;

            if (insideMode) {
                const box = new THREE.Box3().setFromObject(currentModel);
                const center = box.getCenter(new THREE.Vector3());
                const size = box.getSize(new THREE.Vector3());
                const smallOffset = Math.max(size.x, size.y, size.z) * 0.01;

                camera.position.set(center.x + smallOffset, center.y, center.z);
                controls.target.copy(center);
                camera.near = 0.0001;
                camera.updateProjectionMatrix();
                controls.update();
            } else {
                window.resetCamera();
            }
        };

        const hint = document.getElementById('gesture-hint');
        let hintShown = false;
        function showHint() {
            if (hintShown) return;
            hintShown = true;
            hint.classList.add('show');
            setTimeout(() => hint.classList.remove('show'), 3500);
        }

        function animate() {
            requestAnimationFrame(animate);
            controls.update();
            renderer.render(scene, camera);
        }
        animate();

        function onResize() {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        }
        window.addEventListener('resize', onResize);
        window.addEventListener('orientationchange', () => setTimeout(onResize, 100));

        send('ready');
        setTimeout(showHint, 1500);
    </script>
</body>
</html>
''';
  }
}
