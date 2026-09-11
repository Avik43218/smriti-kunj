import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/pairing_screen.dart';
import 'services/session_service.dart';
import 'services/difficulty_service.dart';
import 'services/locale_service.dart';
import 'services/api_service.dart';
import 'services/tts_service.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Text-To-Speech service
  await TtsService().initTts();

  // Pre-initialize TFLite dynamic difficulty model in background
  ApiService.instance.baseUrl = 'http://192.168.1.240:8000';
  DynamicDifficultyService.instance.init();
  
  // Auto-login using pairing code stored in local SQLite database
  await SessionService.instance.tryAutoLogin();
  
  runApp(const SmritiKunjApp());
}

class SmritiKunjApp extends StatelessWidget {
  const SmritiKunjApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionService.instance),
        ChangeNotifierProvider(create: (_) => LocaleService.instance),
      ],
      child: MaterialApp(
        title: 'Smriti Kunj',
        debugShowCheckedModeBanner: false,
        theme: patientTheme,
        home: Consumer<SessionService>(
          builder: (context, session, _) {
            if (session.isInitializing) {
              return const Scaffold(
                backgroundColor: AppColors.cream,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.terracotta),
                ),
              );
            }
            return session.isPaired ? const HomeScreen() : const PairingScreen();
          },
        ),
      ),
    );
  }
}