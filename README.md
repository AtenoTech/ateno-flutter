# Ateno Flutter

Ateno Flutter provides official UI components for the Ateno Spatial Design API.

Use the built-in `PlyViewer` widget to embed an interactive 3D viewer in your app. It supports `.glb`, `.gltf`, and `.ply` models, with loading feedback and touch-friendly controls out of the box.

## Features

- Render `.glb`, `.gltf`, and `.ply` models
- Load models from a remote URL or local file path
- Built-in loading and error states
- Gesture and control-bar interactions for navigation

## Installation

```bash
flutter pub add ateno_flutter
```

## Quick Start

Use `PlyViewer` to render a model from a remote URL or local file path.

```dart
import 'package:flutter/material.dart';
import 'package:ateno_flutter/ateno_flutter.dart';

class RoomDesignScreen extends StatelessWidget {
  final String storageUrl;

  const RoomDesignScreen({super.key, required this.storageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Spatial Design')),
      body: PlyViewer(
        filePath: storageUrl, // Example: https://api.ateno.co/models/scene.glb
        backgroundColor: Colors.white,
      ),
    );
  }
}

```

## Notes

- `filePath` accepts either a public HTTP(S) URL or a local file path.
- Set `backgroundColor` to match your screen theme for a seamless UI.
