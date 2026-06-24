import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const WorldOSApp());
}

class WorldOSApp extends StatelessWidget {
  const WorldOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppBrain()),
      ],
      child: MaterialApp(
        title: 'WorldOS Browser',
        debugShowCheckedModeBanner: false,
        theme: WorldOSTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _controller.addListener(() {
      setState(() => _progress = _controller.value);
    });

    _initApp();
  }

  Future<void> _initApp() async {
    final brain = context.read<AppBrain>();
    await brain.initialize();
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorldOSTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    WorldOSTheme.cyan.withOpacity(0.8),
                    WorldOSTheme.cyan.withOpacity(0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: WorldOSTheme.cyan.withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.language,
                size: 50,
                color: WorldOSTheme.bg,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                  duration: 2000.ms,
                  color: WorldOSTheme.cyan.withOpacity(0.3),
                ),
            const SizedBox(height: 32),
            Text(
              'WORLDOS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: WorldOSTheme.textPrimary,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ACTION BROWSER',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: WorldOSTheme.cyan,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: WorldOSTheme.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          WorldOSTheme.cyan),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _progress < 0.3
                        ? 'Loading brain...'
                        : _progress < 0.6
                            ? 'Calibrating agents...'
                            : _progress < 0.9
                                ? 'Syncing memory...'
                                : 'Ready',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: WorldOSTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
