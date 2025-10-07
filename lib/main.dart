import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const SpooktacularApp());

class SpooktacularApp extends StatelessWidget {
  const SpooktacularApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spooktacular Storybook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // ✅ fixed brightness match
        ),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const SplashPage(),
        '/game': (_) => const GamePage(),
        '/win': (_) => const WinPage(),
      },
    );
  }
}

// ------------------- Splash Page -------------------
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: SpookyBackgroundPainter(),
        child: Center(
          child: ScaleTransition(
            scale: _pulse,
            child: ElevatedButton.icon(
              icon: const Hero(
                tag: 'start-hero',
                child: Icon(Icons.auto_awesome, size: 28),
              ),
              label: const Text('Enter the Storybook'),
              onPressed: () => Navigator.pushNamed(context, '/game'),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------- Game Page -------------------
class SpookyItem {
  SpookyItem({
    required this.emoji,
    required this.isTrap,
    required this.isWinning,
    required this.size,
  });
  final String emoji;
  final bool isTrap;
  final bool isWinning;
  final double size;
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Random _rng = Random();
  late Timer _moveTimer;
  final AudioPlayer _bg = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  // Toggle this false to run without audio
  final bool enableAudio = true;

  late List<SpookyItem> items;

  @override
  void initState() {
    super.initState();

    items = [
      SpookyItem(emoji: '👻', isTrap: false, isWinning: false, size: 64),
      SpookyItem(emoji: '🎃', isTrap: true, isWinning: false, size: 56),
      SpookyItem(emoji: '🦇', isTrap: true, isWinning: false, size: 56),
      SpookyItem(emoji: '🕷️', isTrap: true, isWinning: false, size: 48),
      SpookyItem(emoji: '🍬', isTrap: false, isWinning: true, size: 56),
      SpookyItem(emoji: '🕯️', isTrap: false, isWinning: false, size: 48),
    ];

    if (enableAudio) {
      _bg.setReleaseMode(ReleaseMode.loop);
      _bg.play(AssetSource('audio/bg.mp3')).catchError((_) {});
    }

    _moveTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _moveTimer.cancel();
    _bg.stop();
    _bg.dispose();
    _sfx.dispose();
    super.dispose();
  }

  Future<void> _tapItem(SpookyItem it) async {
    if (it.isTrap) {
      if (enableAudio) {
        await _sfx.play(AssetSource('audio/jumpscare.wav')).catchError((_) {});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('😱 Boo! That was a trap!')),
      );
    } else if (it.isWinning) {
      if (enableAudio) {
        await _sfx.play(AssetSource('audio/win.wav')).catchError((_) {});
      }
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('You Found It!'),
          content: const Text('Nicely done—you discovered the hidden candy.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            )
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/win');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hmm… keep looking!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: SpookyBackgroundPainter(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final List<Offset> targets = List.generate(items.length, (_) {
              final dx = _rng.nextDouble() * (w - 96);
              final dy = _rng.nextDouble() * (h - 160);
              return Offset(dx, dy);
            });

            return Stack(
              children: [
                Positioned(
                  top: 40,
                  left: 20,
                  child: Hero(
                    tag: 'start-hero',
                    child: Text(
                      'Spooktacular Storybook',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                Positioned(
                  top: 80,
                  left: 20,
                  child: Text(
                    'Find the 🍬 candy! Beware of traps…',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                ...List.generate(items.length, (i) {
                  final it = items[i];
                  final t = targets[i];
                  return AnimatedPositioned(
                    key: ValueKey('pos-$i-${t.dx}-${t.dy}'),
                    left: t.dx,
                    top: t.dy,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    child: _FloatingGlow(
                      child: GestureDetector(
                        onTap: () => _tapItem(it),
                        child: Text(
                          it.emoji,
                          style: TextStyle(fontSize: it.size),
                        ),
                      ),
                    ),
                  );
                }),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Home'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------- Glow Animation Wrapper -------------------
class _FloatingGlow extends StatefulWidget {
  const _FloatingGlow({required this.child});
  final Widget child;

  @override
  State<_FloatingGlow> createState() => _FloatingGlowState();
}

class _FloatingGlowState extends State<_FloatingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                blurRadius: _a.value,
                spreadRadius: _a.value * 0.2,
                color: Colors.deepPurpleAccent.withOpacity(0.35),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ------------------- Win Page -------------------
class WinPage extends StatelessWidget {
  const WinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: SpookyBackgroundPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉 You Found the Candy!',
                  style: TextStyle(fontSize: 28)),
              const SizedBox(height: 16),
              const Text(
                'The spirits are pleased… tap below to play again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/game'),
                child: const Text('Play Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------- Custom Painter Background -------------------
class SpookyBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0B1020), Color(0xFF1C1030)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final moon = Paint()..color = Colors.amber.withOpacity(0.9);
    canvas.drawCircle(Offset(size.width - 80, 90), 36, moon);

    final hill = Paint()..color = const Color(0xFF121826);
    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.7,
          size.width * 0.6, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.9,
          size.width, size.height * 0.85)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, hill);

    final star = Paint()..color = Colors.white70;
    final rnd = Random(42);
    for (int i = 0; i < 80; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height * 0.6;
      canvas.drawCircle(Offset(dx, dy), rnd.nextDouble() * 1.5 + 0.5, star);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
