import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/pairing_screen.dart';
import 'services/session_service.dart';
import 'theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmritiKunjApp());
}

class SmritiKunjApp extends StatelessWidget {
  const SmritiKunjApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionService.instance),
      ],
      child: MaterialApp(
        title: 'Smriti Kunj',
        debugShowCheckedModeBanner: false,
        theme: patientTheme,
        home: Consumer<SessionService>(
          builder: (context, session, _) {
            return session.isPaired ? const HomeScreen() : const PairingScreen();
          },
        ),
      ),
    );
  }
}
