import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_state.dart';
import '../data/auth_state.dart';
import '../models/models.dart';

/// Central route paths — keep in sync with [app_router.dart].
abstract final class AppRoutes {
  static const splash = '/splash';
  static const home = '/';
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const studentPath = '/student/path';
  static const studentHome = studentPath;
  static const studentMandarin = '/student/mandarin';
  static const studentPractice = '/student/practice';
  static const studentPlay = '/student/play';
  static const studentMaths = '/student/maths';
  static const studentLabs = '/student/labs';
  static String studentLab(String id) => '/student/labs/$id';
  static String studentRopeBoard(String roomId) =>
      '/student/rope/$roomId/board';
  static const studentExams = '/student/exams';
  static const studentExamSession = '/student/exams/session';
  static const studentProfile = '/student/profile';
  static const studentRewards = '/student/rewards';
  static const studentExplore = '/student/explore';
  static const teacherHome = '/teacher/class';
  static const teacherProgress = '/teacher/progress';
  static const teacherCreate = '/teacher/create';
  static const teacherLive = '/teacher/live';
  static const teacherLiveCompose = '/teacher/live/compose';
  static const teacherPlay = '/teacher/play';
  static const teacherAssign = '/teacher/assign';
  static const studentReport = '/student/report';
  static const reviewerHome = '/reviewer/queue';

  static String teacherReport(String studentId) => '/teacher/report/$studentId';

  static String studentLesson(String lessonId) => '/student/lesson/$lessonId';
  static String mandarinLesson(String lessonId) =>
      '/student/foundation/$lessonId';
  static String studentLiveTest(String testId) => '/student/live-test/$testId';
  static String studentRope(String roomId) => '/student/rope/$roomId';
  static String teacherRope(String roomId) => '/teacher/rope/$roomId';
  static String teacherLiveMonitor(String testId) =>
      '/teacher/live/$testId/monitor';
}

bool isProtectedRoute(String path) =>
    path.startsWith('/student') ||
    path.startsWith('/teacher') ||
    path.startsWith('/reviewer');

String authWithRedirect(String destination) =>
    '${AppRoutes.auth}?redirect=${Uri.encodeComponent(destination)}';

String onboardingWithRedirect(String destination) =>
    '${AppRoutes.onboarding}?redirect=${Uri.encodeComponent(destination)}';

UserRole? roleFromPath(String? path) {
  if (path == null) return null;
  if (path.startsWith('/teacher')) return UserRole.teacher;
  if (path.startsWith('/student')) return UserRole.student;
  if (path.startsWith('/reviewer')) return UserRole.reviewer;
  return null;
}

/// Landing role tiles — sends unauthenticated users to auth first.
void enterStudentSpace(BuildContext context, WidgetRef ref) =>
    enterRoleSpace(context, ref, UserRole.student, AppRoutes.studentPath);

void enterTeacherSpace(BuildContext context, WidgetRef ref) =>
    enterRoleSpace(context, ref, UserRole.teacher, AppRoutes.teacherHome);

void enterReviewerSpace(BuildContext context, WidgetRef ref) =>
    enterRoleSpace(context, ref, UserRole.reviewer, AppRoutes.reviewerHome);

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

/// Sign-in uses [go], which replaces the stack, so exam practice has nothing to pop.
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
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
      redirect != null
          ? onboardingWithRedirect(redirect)
          : AppRoutes.onboarding,
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
    context.go(AppRoutes.studentPath);
    return;
  }
  if (role == UserRole.reviewer) {
    ref.read(roleProvider.notifier).state = UserRole.reviewer;
    context.go(AppRoutes.reviewerHome);
    return;
  }

  context.go(AppRoutes.home);
}

/// Homepage path tiles — deep-link into live app areas.
void openLandingFeature(BuildContext context, WidgetRef ref, int featureIndex) {
  switch (featureIndex) {
    case 0:
      enterRoleSpace(context, ref, UserRole.student, AppRoutes.studentMandarin);
    case 1:
      enterRoleSpace(context, ref, UserRole.student, AppRoutes.studentExams);
    case 2:
      enterRoleSpace(context, ref, UserRole.student, AppRoutes.studentPlay);
    case 3:
      enterRoleSpace(context, ref, UserRole.teacher, AppRoutes.teacherProgress);
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
