import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/gps.dart';
import 'package:AccessAbility/accessability/presentation/widgets/google_helper/map_view_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/checkIn/send_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/login_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/signup_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/onboarding_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/authscreens/upload_profile_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/chat_system/inbox_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/add_new_place.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settings_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/sos/sos_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/splash_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/account_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/biometric/biometric_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/chat_with_support_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/preferences_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/privacy_security_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/settings/settingsScreens/about_screen.dart';
import 'package:AccessAbility/accessability/presentation/widgets/chatWidgets/chat_convo_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppRouter {
  Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
        return _buildRoute(const SplashScreen(),
            clearStack: true, settings: routeSettings);
      case SignupScreen.routeName:
        return _buildRoute(const SignupScreen(), settings: routeSettings);
      case '/login':
        return _buildRoute(const LoginScreen(),
            clearStack: true, settings: routeSettings);
      case '/uploadProfilePicture':
        final args = routeSettings.arguments as SignUpModel;
        return _buildRoute(UploadProfileScreen(signUpModel: args),
            clearStack: true, settings: routeSettings);
      case '/addPlace':
        return _buildRoute(const AddNewPlaceScreen(), settings: routeSettings);
      case '/mapviewsettings':
        return _buildRoute(const MapViewScreen(), settings: routeSettings);
      case '/onboarding':
        return _buildRoute(const OnboardingScreen(),
            clearStack: true, settings: routeSettings);
      case '/homescreen':
        // Pass the routeSettings so that GpsScreen can read any arguments (e.g. MapPerspective)
        return _buildRoute(const GpsScreen(),
            clearStack: true, settings: routeSettings);
      case '/account':
        return _buildRoute(const AccountScreen(), settings: routeSettings);
      case '/preferences':
        return _buildRoute(const PreferencesScreen(), settings: routeSettings);
      case '/privacy':
        return _buildRoute(PrivacySecurity(), settings: routeSettings);
      case '/chatsupport':
        return _buildRoute(const ChatAndSupport(), settings: routeSettings);
      case '/biometric':
        return _buildRoute(const BiometricScreen(), settings: routeSettings);
      case '/settings':
        return _buildRoute(const SettingsScreen(), settings: routeSettings);
      case '/inbox':
        return _buildRoute(const InboxScreen(), settings: routeSettings);
      case '/sos':
        return _buildRoute(SOSScreen(), settings: routeSettings);
      case '/about':
        return _buildRoute(const AboutScreen(), settings: routeSettings);
      case '/send-location':
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null) {
          throw ArgumentError(
              'Arguments must not be null for /send-location route');
        }
        final currentLocation = args['currentLocation'] as LatLng;
        final isSpaceChat = args['isSpaceChat'] as bool? ?? false;
        return MaterialPageRoute(
          builder: (context) => SendLocationScreen(
            currentLocation: currentLocation,
            isSpaceChat: isSpaceChat,
          ),
          settings: routeSettings,
        );
      case '/chatconvo':
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null) {
          throw ArgumentError(
              'Arguments must not be null for /chatconvo route');
        }
        final receiverUsername = args['receiverUsername'] as String;
        final receiverID = args['receiverID'] as String;
        final isSpaceChat = args['isSpaceChat'] as bool? ?? false;
        final receiverProfilePicture = args['receiverProfilePicture']
                as String? ??
            'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media';
        return MaterialPageRoute(
          builder: (context) => ChatConvoScreen(
            receiverUsername: receiverUsername,
            receiverID: receiverID,
            isSpaceChat: isSpaceChat,
          ),
          settings: routeSettings,
        );
    }
    return null;
  }

  MaterialPageRoute<Map<String, dynamic>?> _buildRoute(Widget child,
      {bool clearStack = false, RouteSettings? settings}) {
    return MaterialPageRoute<Map<String, dynamic>?>(
      builder: (context) {
        if (clearStack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<Map<String, dynamic>?>(
                builder: (_) => child,
                settings: settings,
              ),
              (route) => false,
            );
          });
          return const SizedBox.shrink();
        }
        return child;
      },
      settings: settings,
    );
  }
}
