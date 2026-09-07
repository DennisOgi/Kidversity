import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/auth_state.dart';
import '../models/models.dart';
import '../features/auth/auth_screen.dart';
import '../features/landing/landing_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/reviewer/review_queue_screen.dart';
import '../features/student/foundation_path_screen.dart';
import '../features/student/foundation_practice_screen.dart';
import '../features/student/mandarin_lesson_player.dart';
import '../features/student/profile_screen.dart';
import '../features/student/student_live_test_screen.dart';
import '../features/teacher/foundation_progress_screen.dart';
import '../features/teacher/students_screen.dart';
import '../features/teacher/teacher_live_hub_screen.dart';
import '../features/teacher/teacher_live_monitor_screen.dart';
import '../theme/app_colors.dart';
import 'navigation.dart';

final _rootKey = GlobalKey<NavigatorState>();

const _studentNav = [
  NavItem(
    Icons.route_outlined,
    Icons.route_rounded,
    'Path',
    '/student/path',
    'Your Mandarin Foundation journey',
  ),
  NavItem(
    Icons.school_outlined,
    Icons.school_rounded,
    'Practice',
    '/student/practice',
    'Build confidence with every word',
  ),
  NavItem(
    Icons.person_outline_rounded,
    Icons.person_rounded,
    'Me',
    '/student/profile',
    'Class and learning settings',
  ),
];

const _teacherNav = [
  NavItem(
    Icons.groups_outlined,
    Icons.groups_rounded,
    'Class',
    '/teacher/class',
    'Class code & roster',
  ),
  NavItem(
    Icons.route_outlined,
    Icons.route_rounded,
    'Progress',
    '/teacher/progress',
    'Foundation lesson map',
  ),
  NavItem(
    Icons.bolt_outlined,
    Icons.bolt_rounded,
    'Live',
    '/teacher/live',
    'Timed quizzes',
  ),
];

const _reviewerNav = [
  NavItem(
    Icons.fact_check_outlined,
    Icons.fact_check_rounded,
    'Review',
    '/reviewer/queue',
    'Review Mandarin lessons',
  ),
];

Widget _studentShell(String path, Widget page) => AppShell(
  currentPath: path,
  items: _studentNav,
  accent: AppColors.primary,
  child: page,
);

Widget _teacherShell(String path, Widget page) => AppShell(
  currentPath: path,
  items: _teacherNav,
  accent: AppColors.secondary,
  child: page,
);

Widget _reviewerShell(String path, Widget page) => AppShell(
  currentPath: path,
  items: _reviewerNav,
  accent: AppColors.jade,
  child: page,
);

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final session = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      final redirect = state.uri.queryParameters['redirect'];

      final isSplash = path == AppRoutes.splash;
      final isHome = path == AppRoutes.home;
      final isAuth = path == AppRoutes.auth;
      final isOnboarding = path == AppRoutes.onboarding;
      final isProtected = isProtectedRoute(path);

      // Hold splash until the recovered session and profile are known.
      // Do not use [isLoading] here — sign-in also sets that flag.
      if (session.isBootstrapping) {
        return isSplash ? null : AppRoutes.splash;
      }

      if (isSplash) {
        if (session.isAuthenticated && !session.onboardingComplete) {
          return AppRoutes.onboarding;
        }
        if (session.isAuthenticated && session.onboardingComplete) {
          final role = session.role ?? ref.read(roleProvider);
          if (role == UserRole.teacher) return AppRoutes.teacherHome;
          if (role == UserRole.student) return AppRoutes.studentPath;
          if (role == UserRole.reviewer) return AppRoutes.reviewerHome;
        }
        return AppRoutes.home;
      }

      if (!session.isAuthenticated) {
        // Stale /onboarding bookmarks must not linger for signed-out users.
        if (isOnboarding) return AppRoutes.home;
        if (isHome || isAuth) return null;
        if (isProtected) return authWithRedirect(path);
        return null;
      }

      if (!session.onboardingComplete) {
        if (isOnboarding) return null;
        if (isProtected) return onboardingWithRedirect(path);
        return AppRoutes.onboarding;
      }

      if (session.isAuthenticated && session.onboardingComplete && isHome) {
        final role = session.role ?? ref.read(roleProvider);
        if (role == UserRole.teacher) return AppRoutes.teacherHome;
        if (role == UserRole.student) return AppRoutes.studentPath;
        if (role == UserRole.reviewer) return AppRoutes.reviewerHome;
      }

      if (isAuth || isOnboarding) {
        if (redirect != null && redirect.isNotEmpty) return redirect;
        final role = session.role ?? ref.read(roleProvider);
        if (role == UserRole.teacher) return AppRoutes.teacherHome;
        if (role == UserRole.student) return AppRoutes.studentPath;
        if (role == UserRole.reviewer) return AppRoutes.reviewerHome;
        return AppRoutes.home;
      }

      if (isProtected) {
        final role = session.role ?? ref.read(roleProvider);
        final requiredRole = roleFromPath(path);
        if (role != null && requiredRole != null && role != requiredRole) {
          return switch (role) {
            UserRole.student => AppRoutes.studentPath,
            UserRole.teacher => AppRoutes.teacherHome,
            UserRole.reviewer => AppRoutes.reviewerHome,
          };
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const LandingScreen()),
      GoRoute(
        path: '/privacy',
        builder: (_, _) => const LegalScreen(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, _) => const LegalScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: '/guardian-consent',
        builder: (_, _) =>
            const LegalScreen(document: LegalDocument.guardianConsent),
      ),

      GoRoute(
        path: '/student/lesson/:id',
        redirect: (_, _) => AppRoutes.studentPath,
      ),
      GoRoute(
        path: '/student/foundation/:id',
        builder: (_, state) =>
            MandarinLessonPlayer(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/live-test/:id',
        builder: (_, state) =>
            StudentLiveTestScreen(testId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/student/path',
        builder: (_, _) =>
            _studentShell('/student/path', const FoundationPathScreen()),
      ),
      GoRoute(
        path: '/student/practice',
        builder: (_, _) => _studentShell(
          '/student/practice',
          const FoundationPracticeScreen(),
        ),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (_, _) =>
            _studentShell('/student/profile', const ProfileScreen()),
      ),
      GoRoute(path: '/student/home', redirect: (_, _) => AppRoutes.studentPath),
      GoRoute(
        path: '/student/explore',
        redirect: (_, _) => AppRoutes.studentPath,
      ),
      GoRoute(
        path: '/student/rewards',
        redirect: (_, _) => AppRoutes.studentProfile,
      ),

      GoRoute(
        path: '/teacher/class',
        builder: (_, _) =>
            _teacherShell('/teacher/class', const StudentsScreen()),
      ),
      GoRoute(
        path: '/teacher/progress',
        builder: (_, _) => _teacherShell(
          '/teacher/progress',
          const FoundationProgressScreen(),
        ),
      ),
      GoRoute(
        path: '/teacher/live',
        builder: (_, _) =>
            _teacherShell('/teacher/live', const TeacherLiveHubScreen()),
      ),
      GoRoute(
        path: '/teacher/live/:id/monitor',
        builder: (_, state) =>
            TeacherLiveMonitorScreen(testId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/teacher/home', redirect: (_, _) => AppRoutes.teacherHome),
      GoRoute(
        path: '/teacher/create',
        redirect: (_, _) => AppRoutes.teacherProgress,
      ),
      GoRoute(
        path: '/teacher/students',
        redirect: (_, _) => AppRoutes.teacherHome,
      ),
      GoRoute(
        path: '/reviewer/queue',
        builder: (_, _) =>
            _reviewerShell('/reviewer/queue', const ReviewQueueScreen()),
      ),
    ],
  );
});
