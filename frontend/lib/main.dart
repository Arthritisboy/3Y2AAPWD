import 'package:AccessAbility/accessability/data/repositories/emergency_repository.dart';
import 'package:AccessAbility/accessability/data/repositories/place_repository.dart';
import 'package:AccessAbility/accessability/firebaseServices/emergency/emergency_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/place_service.dart';
import 'package:AccessAbility/accessability/logic/bloc/emergency/bloc/emergency_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:AccessAbility/accessability/backgroundServices/background_service.dart';
import 'package:AccessAbility/accessability/data/repositories/auth_repository.dart';
import 'package:AccessAbility/accessability/data/repositories/user_repository.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/fcm_service.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/router/app_router.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:AccessAbility/firebase_options.dart';
import 'package:AccessAbility/accessability/firebaseServices/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:AccessAbility/accessability/backgroundServices/location_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeService();

  await createNotificationChannel();

  // Initialize SharedPreferences
  final SharedPreferences sharedPreferences =
      await SharedPreferences.getInstance();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env'); // Use absolute path for testing
    print("Loaded API Key: ${dotenv.env['GOOGLE_API_KEY']}");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  // Initialize date formatting
  await initializeDateFormatting();

  // Initialize FCMService
  final FCMService fcmService = FCMService(navigatorKey: navigatorKey);
  fcmService.initializeFCMListeners(); // Pass the navigatorKey

  final AuthService authService = AuthService();
  final PlaceService placeService = PlaceService(); // Initialize PlaceService

  // Initialize ThemeProvider
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(
        sharedPreferences: sharedPreferences,
        navigatorKey: navigatorKey,
        fcmService: fcmService,
        authService: authService,
        placeService: placeService, // Pass PlaceService
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter _appRouter = AppRouter();
  final SharedPreferences sharedPreferences;
  final GlobalKey<NavigatorState> navigatorKey;
  final FCMService fcmService;
  final AuthService authService;
  final PlaceService placeService; // Add this

  MyApp({
    super.key,
    required this.sharedPreferences,
    required this.navigatorKey,
    required this.fcmService,
    required this.authService,
    required this.placeService, // Initialize it
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserBloc>(
          create: (context) => UserBloc(
            userRepository: UserRepository(
                FirebaseFirestore.instance,
                sharedPreferences,
                authService,
                placeService // Use the passed AuthService
                ),
          ),
        ),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: AuthRepository(
              authService, // Use the passed AuthService
              UserRepository(FirebaseFirestore.instance, sharedPreferences,
                  authService, placeService // Use the passed AuthService
                  ),
            ),
            userRepository: UserRepository(
                FirebaseFirestore.instance,
                sharedPreferences,
                authService,
                placeService // Use the passed AuthService
                ),
            userBloc: context.read<UserBloc>(),
            authService: authService, // Use the passed AuthService
          ),
        ),
        BlocProvider<PlaceBloc>(
          create: (context) => PlaceBloc(
            placeRepository: PlaceRepository(placeService: PlaceService()),
          ),
        ),
        BlocProvider<EmergencyBloc>(
          create: (context) => EmergencyBloc(
            emergencyRepository:
                EmergencyRepository(emergencyService: EmergencyService()),
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [routeObserver],
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(context),
            darkTheme: _buildDarkTheme(context),
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            onGenerateRoute: _appRouter.onGenerateRoute,
            builder: (context, child) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final authBloc = context.read<AuthBloc>();
                authBloc.add(CheckAuthStatus());
              });
              return child!;
            },
          );
        },
      ),
    );
  }
}

ThemeData _buildLightTheme(BuildContext context) {
  return ThemeData(
    primaryColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 255, 255, 255),
    ),
    useMaterial3: true,
    listTileTheme: const ListTileThemeData(
      textColor: Colors.black,
      iconColor: Colors.black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      backgroundColor: Colors.white,
    ),
    textTheme: _buildHelveticaTextTheme(),
  );
}

ThemeData _buildDarkTheme(BuildContext context) {
  return ThemeData(
    primaryColor: Colors.black,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 0, 0, 0),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white, // Ensure text/icons are visible
    ),
    textTheme: _buildHelveticaTextTheme(),
  );
}

// Helvetica Text Theme
TextTheme _buildHelveticaTextTheme() {
  return const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 24,
      fontWeight: FontWeight.w600,
    ),
    displaySmall: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 20,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 18,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    labelLarge: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    labelMedium: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
    labelSmall: TextStyle(
      fontFamily: 'HelveticaNeue',
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  );
}
