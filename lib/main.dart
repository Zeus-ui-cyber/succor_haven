// lib/main.dart  (replace your existing main.dart with this)
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/repositories/auth_repository.dart' show AuthRepository;

// Auth screens
import 'features/auth/screens/login_screen.dart' show LoginScreen;
import 'features/auth/screens/register_screen.dart' show RegisterScreen;

// Dashboards
import 'features/dashboard/student_dashboard_screen.dart' show StudentDashboard;
import 'features/dashboard/teacher_dashboard_screen.dart' show TeacherDashboard;
import 'features/dashboard/teacher_pending_screen.dart'
    show TeacherPendingScreen;
import 'features/dashboard/admin_dashboard_screen.dart' show AdminDashboard;

// Settings screens
import 'features/settings/screens/student/edit_profile_screen.dart'
    show EditProfileScreen;
import 'features/settings/screens/student/change_password_screen.dart'
    show ChangePasswordScreen;
import 'features/settings/screens/student/phone_settings_screen.dart'
    show PhoneSettingsScreen;
import 'features/settings/screens/student/language_settings_screen.dart'
    show LanguageSettingsScreen;
import 'features/settings/screens/student/notification_settings_screen.dart'
    show NotificationSettingsScreen;
import 'features/settings/screens/student/help_center_screen.dart'
    show HelpCenterScreen;
import 'features/settings/screens/student/privacy_policy_screen.dart'
    show PrivacyPolicyScreen;

// Booking / Teacher detail
import 'features/booking/screens/teacher_detail_screen.dart'
    show TeacherDetailScreen; // ← NEW

// Appointments
import 'features/appointments/screens/request_appointment_screen.dart'
    show RequestAppointmentScreen; // ← NEW

// Models
import 'models/user.dart' show UserModel;
import 'models/user_role.dart' show UserRole;
import 'models/teacher_profile.dart' show TeacherProfileModel; // ← NEW

// ─── Succor Haven global design tokens ───────────────────────────────────────
class SHColors {
  static const magenta = Color(0xFFD64577);
  static const slateBlue = Color(0xFF3E678A);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const burgundy = Color(0xFF7D002B);
  static const lightPink = Color(0xFFF7D6E2);
  static const dustyBlue = Color(0xFFA7BCCB);
  static const mauve = Color(0xFFE08AB2);
  static const cream = Color(0xFFFFF5F7);
  static const lightGray = Color(0xFFE6E6E6);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const bg = Color(0xFFFFF5F7);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDCF7EE);
  static const gradientStart = burgundy;
  static const gradientMid = blushPink;
  static const gradientEnd = slateBlue;
}

class SHTheme {
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: SHColors.magenta,
      brightness: Brightness.light,
      primary: SHColors.magenta,
      onPrimary: Colors.white,
      primaryContainer: SHColors.blushPink,
      onPrimaryContainer: SHColors.burgundy,
      secondary: SHColors.slateBlue,
      onSecondary: Colors.white,
      secondaryContainer: SHColors.dustyBlue.withValues(alpha: 0.3),
      onSecondaryContainer: SHColors.slateBlue,
      tertiary: SHColors.mauve,
      onTertiary: Colors.white,
      error: const Color(0xFFB00020),
      surface: SHColors.paper,
      onSurface: SHColors.ink,
      surfaceContainerHighest: SHColors.softPink,
      outline: SHColors.line,
      outlineVariant: SHColors.lightPink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: SHColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: SHColors.bg,
        foregroundColor: SHColors.ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: SHColors.ink,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: SHColors.ink),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SHColors.magenta,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SHColors.lightPink,
          disabledForegroundColor: SHColors.inkSoft,
          elevation: 4,
          shadowColor: SHColors.magenta.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SHColors.magenta,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SHColors.magenta,
          side: const BorderSide(color: SHColors.magenta, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SHColors.softPink,
        labelStyle: const TextStyle(
            color: SHColors.inkSoft, fontWeight: FontWeight.w600, fontSize: 14),
        hintStyle: const TextStyle(
            color: SHColors.inkSoft, fontWeight: FontWeight.w500, fontSize: 13),
        prefixIconColor: SHColors.inkSoft,
        suffixIconColor: SHColors.inkSoft,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: SHColors.magenta, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.8)),
        errorStyle: const TextStyle(color: Color(0xFFB00020), fontSize: 11.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: SHColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SHColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SHColors.lightPink,
        selectedColor: SHColors.magenta,
        labelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: SHColors.ink),
        secondaryLabelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SHColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: SHColors.inkSoft,
        indicatorColor: SHColors.magenta,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      dividerTheme:
          const DividerThemeData(color: SHColors.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SHColors.ink,
        contentTextStyle: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SHColors.magenta,
        linearTrackColor: SHColors.lightPink,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: SHColors.inkSoft,
        titleTextStyle: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: SHColors.ink),
        subtitleTextStyle: TextStyle(
            fontSize: 12, color: SHColors.inkSoft, fontWeight: FontWeight.w500),
      ),
      iconTheme: const IconThemeData(color: SHColors.inkSoft, size: 22),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: SHColors.magenta,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),
    );
  }
}

// ─── Entry point ──────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  String apiUrl;
  if (kIsWeb) {
    apiUrl = 'http://localhost:3000/api/v1';
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    apiUrl = 'http://10.0.2.2:3000/api/v1';
  } else {
    apiUrl = 'http://localhost:3000/api/v1';
  }
  AuthRepository.configure(url: apiUrl);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: SHColors.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: SuccorHavenApp()));
}

// ─── Root app ─────────────────────────────────────────────────────────────────
class SuccorHavenApp extends StatelessWidget {
  const SuccorHavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Succor Haven',
      debugShowCheckedModeBanner: false,
      theme: SHTheme.light,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),

        '/register': (context) {
          final role =
              ModalRoute.of(context)?.settings.arguments as UserRole? ??
                  UserRole.student;
          return RegisterScreen(initialRole: role);
        },

        // ── Dashboards ────────────────────────────────────────────────────
        '/dashboard': (_) => const StudentDashboard(),
        '/teacher-dashboard': (_) => const TeacherDashboard(),

        // ── Teacher pending approval ──────────────────────────────────────
        // Login screen / auth controller should redirect here instead of
        // '/teacher-dashboard' when user.teacherApproved == false.
        '/teacher-pending': (_) => const TeacherPendingScreen(),

        '/admin-dashboard': (_) => const AdminDashboard(),

        // ── Account Settings ──────────────────────────────────────────────
        // Expects a UserModel passed as arguments, e.g.:
        //   Navigator.pushNamed(context, '/settings/edit-profile', arguments: user);
        '/settings/edit-profile': (context) {
          final user = ModalRoute.of(context)!.settings.arguments as UserModel;
          return EditProfileScreen(user: user);
        },

        // No arguments needed — the backend identifies the user from the
        // JWT and looks up their own registered phone number.
        '/settings/change-password': (_) => const ChangePasswordScreen(),

        // No arguments needed — backend identifies the user from the JWT
        // and looks up their own primary/backup phone numbers.
        '/settings/phone': (_) => const PhoneSettingsScreen(),

        // Optional String argument for the user's current language
        // ('en' | 'zh'), e.g.:
        //   Navigator.pushNamed(context, '/settings/language',
        //       arguments: user.languagePref);
        // Defaults to 'en' if no argument is passed.
        '/settings/language': (context) {
          final currentLanguage =
              ModalRoute.of(context)?.settings.arguments as String? ?? 'en';
          return LanguageSettingsScreen(currentLanguage: currentLanguage);
        },

        '/settings/notifications': (_) => const NotificationSettingsScreen(),

        '/settings/help-center': (_) => const HelpCenterScreen(),

        '/settings/privacy-policy': (_) => const PrivacyPolicyScreen(),

        // ── Appointments ───────────────────────────────────────────────────
        // Expects a TeacherProfileModel passed as arguments, e.g.:
        //   Navigator.pushNamed(context, '/appointments/request',
        //       arguments: teacher);
        //
        // FIXED: this used to do a hard, non-null cast
        // (`ModalRoute.of(context)!.settings.arguments as TeacherProfileModel`),
        // which crashed with "type 'Null' is not a subtype of type
        // 'TeacherProfileModel'" any time this route was entered without a
        // teacher object in the arguments — most commonly a browser
        // refresh on Flutter web, since the URL alone can't carry a Dart
        // object across a reload. Now it's a nullable cast with a friendly
        // fallback screen instead of a crash.
        '/appointments/request': (context) {
          final teacher = ModalRoute.of(context)?.settings.arguments
              as TeacherProfileModel?;
          if (teacher == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Request Appointment')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Please select a teacher first to request an appointment.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/dashboard',
                          (route) => false,
                        ),
                        child: const Text('Back to Dashboard'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return RequestAppointmentScreen(teacher: teacher);
        }, // ← NEW
      },
      // ── Dynamic routes ───────────────────────────────────────────────────
      // Handles paths the `routes:` map above can't match, since it only
      // does exact string comparison — no path-parameter support. Right
      // now this covers /teachers/:id (tapped from Find Teachers / teacher
      // cards). Without this, Navigator.pushNamed(context,
      // '/teachers/$id') fails with "Could not find a generator for
      // route" and silently does nothing from the user's perspective.
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        final segments = uri.pathSegments;

        if (segments.length == 2 && segments[0] == 'teachers') {
          final teacherId = segments[1];
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => TeacherDetailScreen(teacherId: teacherId),
          );
        }

        // No match — fall through to onUnknownRoute instead of returning
        // null, which would silently no-op the navigation.
        return null;
      },
      // Safety net: if onGenerateRoute also can't resolve it, show an
      // explicit error screen instead of a raw console-only error with no
      // UI feedback for the person using the app.
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page not found')),
            body: Center(
              child: Text('No route defined for "${settings.name}"'),
            ),
          ),
        );
      },
    );
  }
}
