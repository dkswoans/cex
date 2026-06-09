import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/login_page.dart';
import 'providers/community_provider.dart';
import 'providers/gym_provider.dart';
import 'services/reservation_notification_service.dart';
import 'services/supabase_config.dart';
import 'utils/status_utils.dart';
import 'widgets/app_design.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await ReservationNotificationService.instance.initialize();
  runApp(const ApdoApp());
}

class ApdoApp extends StatelessWidget {
  const ApdoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GymProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
      ],
      child: MaterialApp(
        title: '압도정진올라잇삼창돌격',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: surfaceColor,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: bgColor,
          textTheme: Theme.of(
            context,
          ).textTheme.apply(bodyColor: textColor, displayColor: redColor),
          appBarTheme: const AppBarTheme(
            backgroundColor: surfaceColor,
            foregroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: bgColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          cardTheme: CardThemeData(
            color: surfaceColor,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: borderColor, width: 3),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderColor, width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: blueColor, width: 4),
            ),
            labelStyle: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
            filled: true,
            fillColor: const Color(0xFFFFB800),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: redColor,
              foregroundColor: bgColor,
              minimumSize: const Size(0, 48),
              elevation: 0,
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                side: BorderSide(color: Colors.black, width: 3),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.8,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              backgroundColor: greenColor,
              side: const BorderSide(color: borderColor, width: 2.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: bgColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: borderColor, width: 3),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            titleTextStyle: AppTextStyles.sectionTitle,
            contentTextStyle: AppTextStyles.value,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: borderColor,
            contentTextStyle: const TextStyle(
              color: bgColor,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: const BorderSide(color: surfaceColor, width: 3),
            ),
            elevation: 0,
          ),
        ),
        home: const LoginPage(),
      ),
    );
  }
}
