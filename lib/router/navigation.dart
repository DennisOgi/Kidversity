import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/auth_state.dart';
import '../data/lesson_mapper.dart';
import '../models/models.dart';

/// Central route paths — keep in sync with [app_router.dart].
abstract final class AppRoutes {
  static const splash = '/splash';
  static const home = '/';
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const studentHome = '/student/home';
  static const studentRewards = '/student/rewards';
  static const studentExplore = '/student/explore';
  static const teacherHome = '/teacher/home';
  static const teacherCreate = '/teacher/create';
  static const teacherLive = '/teacher/live';

  static String studentLesson(String lessonId) => '/student/lesson/$lessonId';
  static String studentLiveTest(String testId) => '/student/live-test/$testId';
  static String teacherLiveMonitor(String testId) => '/teacher/live/$testId/monitor';
}

bool isProtectedRoute(String path) =>
    path.startsWith('/student') || path.startsWith('/teacher');

String authWithRedirect(String destination) =>
    '${AppRoutes.auth}?redirect=${Uri.encodeComponent(destination)}';

String onboardingWithRedirect(String destination) =>
    '${AppRoutes.onboarding}?redirect=${Uri.encodeComponent(destination)}';

UserRole? roleFromPath(String? path) {
  if (path == null) return null;
  if (path.startsWith('/teacher')) return UserRole.teacher;
  if (path.startsWith('/student')) return UserRole.student;
  return null;
}

/// Landing role tiles — sends unauthenticated users to auth first.
void enterStudentSpace(BuildContext context, WidgetRef ref) =>
    enterRoleSpace(context, ref, UserRole.student, AppRoutes.studentHome);

void enterTeacherSpace(BuildContext context, WidgetRef ref) =>
    enterRoleSpace(context, ref, UserRole.teacher, AppRoutes.teacherHome);

void enterRoleSpace(
  BuildContext context,
  WidgetRef ref,
  UserRole role,
  String route,
) {
  final auth = ref.read(authControllerProvider);
  if (!auth.isAuthenticated) {
    context.go(authWithRedirect(route));
    return;
  }
  if (!auth.onboardingComplete) {
    context.go(onboardingWithRedirect(route));
    return;
  }
  ref.read(roleProvider.notifier).state = role;
  context.go(route);
}

/// After sign-in / sign-up — honour ?redirect= when onboarding is done.
void continueAfterAuth(
  BuildContext context,
  WidgetRef ref, {
  String? redirect,
}) {
  final auth = ref.read(authControllerProvider);
  if (!auth.onboardingComplete) {
    context.go(
      redirect != null ? onboardingWithRedirect(redirect) : AppRoutes.onboarding,
    );
    return;
  }

  if (redirect != null && redirect.isNotEmpty) {
    context.go(redirect);
    return;
  }

  final role = auth.role ?? ref.read(roleProvider);
  if (role == UserRole.teacher) {
    ref.read(roleProvider.notifier).state = UserRole.teacher;
    context.go(AppRoutes.teacherHome);
    return;
  }
  if (role == UserRole.student) {
    ref.read(roleProvider.notifier).state = UserRole.student;
    context.go(AppRoutes.studentHome);
    return;
  }

  context.go(AppRoutes.home);
}

/// Homepage feature cards — deep-link into live app areas.
void openLandingFeature(BuildContext context, WidgetRef ref, int featureIndex) {
  switch (featureIndex) {
    case 0: // Upload or Generate
      enterRoleSpace(context, ref, UserRole.teacher, AppRoutes.teacherCreate);
    case 1: // Slides + Audio
    case 2: // Smart Quizzes (same lesson includes checkpoints)
      openStudentLesson(context, ref, CatalogIds.mandarinFamily);
    case 3: // Track & Celebrate
      enterRoleSpace(context, ref, UserRole.student, AppRoutes.studentRewards);
    default:
      enterStudentSpace(context, ref);
  }
}

void openStudentLesson(BuildContext context, WidgetRef ref, String lessonId) {
  final route = AppRoutes.studentLesson(lessonId);
  final auth = ref.read(authControllerProvider);
  if (!auth.isAuthenticated) {
    context.go(authWithRedirect(route));
    return;
  }
  if (!auth.onboardingComplete) {
    context.go(onboardingWithRedirect(route));
    return;
  }
  ref.read(roleProvider.notifier).state = UserRole.student;
  context.go(route);
}
