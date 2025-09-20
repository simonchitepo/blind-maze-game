import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/game_screen.dart';
import 'services/score_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const BlindMazeApp());
}

class BlindMazeApp extends StatelessWidget {
  const BlindMazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invisible Maze',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0E12),
        primaryColor: const Color(0xFF7FD3FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7FD3FF),
          secondary: Color(0xFF7FD3FF),
        ),
      ),
      home: const NameEntryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key});

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = true;
  String _existingName = '';

  @override
  void initState() {
    super.initState();
    _loadExistingName();
  }

  Future<void> _loadExistingName() async {
    final name = await ScoreService.getPlayerName();
    setState(() {
      _existingName = name;
      _nameController.text = name;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E12),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7FD3FF),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF7FD3FF).withOpacity(0.2),
                          const Color(0xFF7FD3FF).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      size: 50,
                      color: Color(0xFF7FD3FF),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'INVISIBLE MAZE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEDEDF7),
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  const Text(
                    'Navigate the unseen. Paint your path.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888899),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Name input label
                  const Text(
                    'ENTER YOUR NAME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7FD3FF),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name input field
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0x2217171F),
                          const Color(0x1117171F),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0x33FFFFFF),
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        color: Color(0xFFEDEDF7),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Your name',
                        hintStyle: const TextStyle(
                          color: Color(0xFF555566),
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      maxLength: 30,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      onSubmitted: (value) => _startGame(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Start button
                  ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7FD3FF),
                      foregroundColor: const Color(0xFF0E0E12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    child: const Text('START GAME'),
                  ),

                  // Continue button (only if name exists and is not Anonymous)
                  if (_existingName != 'Anonymous' && _existingName.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await ScoreService.savePlayerName(_existingName);
                        if (mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const GameScreen()),
                          );
                        }
                      },
                      child: Text(
                        'Continue as $_existingName',
                        style: const TextStyle(
                          color: Color(0xFF888899),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Hint text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x1117171F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x11FFFFFF),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF555566),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Your name will appear on the global leaderboard',
                          style: TextStyle(
                            color: Color(0xFF555566),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startGame() async {
    String name = _nameController.text.trim();
    if (name.isEmpty) {
      name = 'Anonymous';
    }
    await ScoreService.savePlayerName(name);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }
  }
}