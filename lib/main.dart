import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/login_page.dart';
import 'providers/gym_provider.dart';
import 'services/supabase_config.dart';
import 'utils/status_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ApdoApp());
}

class ApdoApp extends StatelessWidget {
  const ApdoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GymProvider(),
      child: MaterialApp(
        title: '압도정진올라잇삼창돌격',
        debugShowCheckedModeBanner: true,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Comic Sans MS',
          colorScheme: ColorScheme.fromSeed(
            seedColor: surfaceColor,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: bgColor,
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: textColor,
            displayColor: redColor,
            fontFamily: 'Comic Sans MS',
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: surfaceColor,
            foregroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            elevation: 12,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: bgColor,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          cardTheme: CardThemeData(
            color: surfaceColor,
            elevation: 16,
            shadowColor: greenColor,
            margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: redColor, width: 4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: greenColor, width: 6),
            ),
            labelStyle: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
            filled: true,
            fillColor: const Color(0xFFFFB800),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: redColor,
              foregroundColor: bgColor,
              minimumSize: const Size(0, 52),
              elevation: 18,
              shadowColor: blueColor,
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                side: BorderSide(color: Colors.black, width: 4),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: 4,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: redColor,
              backgroundColor: greenColor,
              side: const BorderSide(color: borderColor, width: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        home: const LoginPage(),
      ),
    );
  }
}
