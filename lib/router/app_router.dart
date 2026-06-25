import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/auth_state.dart';
import '../models/models.dart';
import '../features/auth/auth_screen.dart';
import '../features/landing/landing_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/student/explore_screen.dart';
import '../features/student/lesson_player.dart';
import '../features/student/profile_screen.dart';
import '../features/student/rewards_screen.dart';
import '../features/student/student_home.dart';
import '../features/student/student_live_test_screen.dart';
import '../features/teacher/create_screen.dart';
import '../features/teacher/students_screen.dart';
import '../features/teacher/teacher_home.dart';
import '../features/teacher/teacher_live_hub_screen.dart';
import '../features/teacher/teacher_live_monitor_screen.dart';
import '../theme/app_colors.dart';
import 'navigation.dart';

final _rootKey = GlobalKey<NavigatorState>();

const _studentNav = [
  NavItem(Icons.home_outlined, Icons.home_rounded, 'Home', '/student/home'),
  NavItem(Icons.explore_outlined, Icons.explore_rounded, 'Explore', '/student/explore'),
  NavItem(Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Rewards', '/student/rewards'),
  NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', '/student/profile'),
];

const _teacherNav = [
  NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home', '/teacher/home'),
  NavItem(Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'Create', '/teacher/create'),
  NavItem(Icons.bolt_outlined, Icons.bolt_rounded, 'Live', '/teacher/live'),
  NavItem(Icons.groups_outlined, Icons.groups_rounded, 'Class', '/teacher/students'),
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

      if (session.isLoading) {
        if (isSplash || isHome || isAuth || isOnboarding) return null;
        if (session.isAuthenticated && isProtected) return null;
        return AppRoutes.splash;
      }

      if (isSplash) return AppRoutes.home;

      if (session.isAuthenticated && session.onboardingComplete && isHome) {
        final role = session.role ?? ref.read(roleProvider);
        if (role == UserRole.teacher) return AppRoutes.teacherHome;
        if (role == UserRole.student) return AppRoutes.studentHome;
      }

      if (!session.isAuthenticated) {
        if (isHome || isAuth) return null;
        if (isProtected) return authWithRedirect(path);
        return null;
      }

      if (!session.onboardingComplete) {
        if (isOnboarding || isAuth || isHome) return null;
        if (isProtected) return onboardingWithRedirect(path);
        return null;
      }

      if (isAuth || isOnboarding) {
        if (redirect != null && redirect.isNotEmpty) return redirect;
        final role = session.role ?? ref.read(roleProvider);
        if (role == UserRole.teacher) return AppRoutes.teacherHome;
        if (role == UserRole.student) return AppRoutes.studentHome;
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const LandingScreen()),

      GoRoute(
        path: '/student/lesson/:id',
        builder: (_, state) => LessonPlayer(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/live-test/:id',
        builder: (_, state) => StudentLiveTestScreen(testId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/student/home',
        builder: (_, _) => _studentShell('/student/home', const StudentHome()),
      ),
      GoRoute(
        path: '/student/explore',
        builder: (_, _) => _studentShell('/student/explore', const ExploreScreen()),
      ),
      GoRoute(
        path: '/student/rewards',
        builder: (_, _) => _studentShell('/student/rewards', const RewardsScreen()),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (_, _) => _studentShell('/student/profile', const ProfileScreen()),
      ),

      GoRoute(
        path: '/teacher/home',
        builder: (_, _) => _teacherShell('/teacher/home', const TeacherHome()),
      ),
      GoRoute(
        path: '/teacher/create',
        builder: (_, state) => _teacherShell(
          '/teacher/create',
          CreateScreen(lessonId: state.uri.queryParameters['lessonId']),
        ),
      ),
      GoRoute(
        path: '/teacher/live',
        builder: (_, _) => _teacherShell('/teacher/live', const TeacherLiveHubScreen()),
      ),
      GoRoute(
        path: '/teacher/live/:id/monitor',
        builder: (_, state) => TeacherLiveMonitorScreen(testId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/students',
        builder: (_, _) => _teacherShell('/teacher/students', const StudentsScreen()),
      ),
    ],
  );
});
