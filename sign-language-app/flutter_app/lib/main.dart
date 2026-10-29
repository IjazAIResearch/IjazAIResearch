import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/fingerspell_screen.dart';
import 'screens/learn_screen.dart';
import 'services/psl_classifier.dart';

void main() {
  runApp(const PslTranslatorApp());
}

/// Pakistan Sign Language translator — full 37-letter alphabet scope.
///
/// The app tries to load the trained TFLite model once, here, and
/// shares the result with all three tabs:
///
///   * Model found → Camera, Fingerspelling and Learn practice all
///     run on real on-device recognition.
///   * Model missing → the Camera tab shows the clearly-labelled demo
///     fallback, Fingerspelling explains what is missing, and Learn
///     still shows the alphabet list. Nothing pretends to recognise
///     signs without a model.
///
/// To get the model: train it (see README), copy model.tflite +
/// labels.txt into flutter_app/assets/, and uncomment the assets
/// block in pubspec.yaml.
class PslTranslatorApp extends StatelessWidget {
  const PslTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSL Translator',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _classifier = PslClassifierService();
  bool _loading = true;
  bool _modelAvailable = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    final ok = await _classifier.load();
    if (mounted) {
      setState(() {
        _modelAvailable = ok;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _classifier.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final tabs = <Widget>[
      CameraScreen(
        classifier: _classifier,
        modelAvailable: _modelAvailable,
      ),
      FingerspellScreen(
        classifier: _classifier,
        modelAvailable: _modelAvailable,
      ),
      LearnScreen(
        classifier: _classifier,
        modelAvailable: _modelAvailable,
      ),
    ];
    return Scaffold(
      // One screen at a time (not an IndexedStack): each tab's camera
      // is released when you leave it, so the next tab can open it.
      body: tabs[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.spellcheck),
            label: 'Fingerspell',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Learn',
          ),
        ],
      ),
    );
  }
}
