import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/features.dart';
import '../data/app_state.dart';
import '../data/auth_state.dart';
import '../features/auth/auth_screen.dart';
import '../features/landing/landing_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/reports/progress_report_screen.dart';
import '../features/teacher/assignments_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/splash/splash_screen.dart';
import '../features/student/payments_screen.dart';
import '../features/admin/admin_overview_screen.dart';
import '../features/admin/admin_payments_screen.dart';
import '../features/parent/parent_home_screen.dart';
import '../features/admin/admin_performance_screen.dart';
import '../features/admin/admin_schools_screen.dart';
import '../features/admin/admin_users_screen.dart';
import '../features/reviewer/review_queue_screen.dart';
import '../features/student/foundation_path_screen.dart';
import '../features/student/student_home_screen.dart';
import '../features/student/foundation_practice_screen.dart';
import '../features/student/mandarin_lesson_player.dart';
import '../features/student/labs/lab_screen.dart';
import '../features/student/labs/labs_hub_screen.dart';
import '../features/student/maths_path_screen.dart';
import '../features/student/past_questions_hub_screen.dart';
import '../features/student/past_questions_session_screen.dart';
import '../features/student/profile_screen.dart';
import '../features/student/rope_pull_screen.dart';
import '../features/student/student_live_test_screen.dart';
import '../models/past_questions_models.dart';
import '../features/teacher/foundation_progress_screen.dart';
import '../features/teacher/students_screen.dart';
import '../features/teacher/teacher_live_compose_screen.dart';
import '../features/teacher/teacher_live_hub_screen.dart';
import '../features/teacher/teacher_live_monitor_screen.dart';
import '../theme/app_colors.dart';
import 'navigation.dart';

final _rootKey = GlobalKey<NavigatorState>();

const _studentNav = [
  NavItem(
    Icons.route_outlined,
    Icons.route_rounded,
    'Home',
    '/student/path',
    'Your next step',
  ),
  NavItem(
    Icons.school_outlined,
    Icons.school_rounded,
    'Practice',
    '/student/practice',
    'Review, exams, and drills',
  ),
  NavItem(
    Icons.sports_esports_outlined,
    Icons.sports_esports_rounded,
    'Play',
    '/student/play',
    'Rope Pull with friends',
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
    'Create a class and share the join code',
  ),
  NavItem(
    Icons.insights_outlined,
    Icons.insights_rounded,
    'Progress',
    '/teacher/progress',
    'Learning movement & check-ins',
  ),
  NavItem(
    Icons.assignment_outlined,
    Icons.assignment_rounded,
    'Assign',
    '/teacher/assign',
    'Set work and see who finished',
  ),
  NavItem(
    Icons.bolt_outlined,
    Icons.bolt_rounded,
    'Live',
    '/teacher/live',
    'Timed quizzes',
  ),
];

const _parentNav = [
  NavItem(
    Icons.family_restroom_outlined,
    Icons.family_restroom_rounded,
    'Family',
    '/parent/family',
    'Your children and what is due',
  ),
  if (Features.payments)
    NavItem(
      Icons.local_offer_outlined,
      Icons.local_offer_rounded,
      'Packs',
      '/parent/packs',
      'Pathway, pack contents, and prices',
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

const _adminNav = [
  NavItem(
    Icons.dashboard_outlined,
    Icons.dashboard_rounded,
    'Overview',
    '/admin',
    'Platform pulse',
  ),
  NavItem(
    Icons.apartment_outlined,
    Icons.apartment_rounded,
    'Schools',
    '/admin/schools',
    'Schools and staff',
  ),
  NavItem(
    Icons.people_outline_rounded,
    Icons.people_rounded,
    'Users',
    '/admin/users',
    'Accounts across schools',
  ),
  NavItem(
    Icons.insights_outlined,
    Icons.insights_rounded,
    'Performance',
    '/admin/performance',
    'Learner analytics',
  ),
  if (Features.payments)
    NavItem(
      Icons.payments_outlined,
      Icons.payments_rounded,
      'Payments',
      '/admin/payments',
      'Families, packs, and repeat buys',
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

Widget _parentShell(String path, Widget page) => AppShell(
  currentPath: path,
  items: _parentNav,
  accent: AppColors.success,
  child: page,
);

Widget _reviewerShell(String path, Widget page) => AppShell(
  currentPath: path,
  items: _reviewerNav,
  accent: AppColors.jade,
  child: page,
);

Widget _adminShell(String path, Widget page) => AppShell(
  currentPath: path,
  items: _adminNav,
  accent: AppColors.ink,
  child: page,
);

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.home,
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

      // Never show the branded splash after first paint. Stay on the
      // destination page while auth settles.
      if (isSplash) {
        if (session.isBootstrapping || !session.isAuthenticated) {
          return AppRoutes.home;
        }
        if (!session.onboardingComplete) return AppRoutes.onboarding;
        return homeForRole(session.role ?? ref.read(roleProvider));
      }

      if (session.isBootstrapping) return null;

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
        if (role != null) return homeForRole(role);
      }

      if (isAuth || isOnboarding) {
        if (redirect != null && redirect.isNotEmpty) return redirect;
        return homeForRole(session.role ?? ref.read(roleProvider));
      }

      if (isProtected) {
        final role = session.role ?? ref.read(roleProvider);
        final requiredRole = roleFromPath(path);
        if (role != null && requiredRole != null && role != requiredRole) {
          return homeForRole(role);
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
            _studentShell('/student/path', const StudentHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.studentMandarin,
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
        path: AppRoutes.studentExams,
        builder: (_, _) => const PastQuestionsHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentExamSession,
        builder: (_, state) {
          final config = state.extra;
          if (config is! PastQuestionsSessionConfig) {
            return const PastQuestionsHubScreen();
          }
          return PastQuestionsSessionScreen(config: config);
        },
      ),
      GoRoute(
        path: AppRoutes.studentLabs,
        builder: (_, _) =>
            _studentShell('/student/path', const LabsHubScreen()),
      ),
      GoRoute(
        path: '/student/labs/:id',
        builder: (_, state) => _studentShell(
          '/student/path',
          LabScreen(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.studentMaths,
        builder: (_, state) => _studentShell(
          '/student/path',
          MathsPathScreen(
            key: ValueKey(state.uri.toString()),
            startLevel: int.tryParse(state.uri.queryParameters['level'] ?? ''),
            assignmentId: state.uri.queryParameters['assignment'],
          ),
        ),
      ),
      GoRoute(
        path: '/student/play',
        builder: (_, _) =>
            _studentShell('/student/play', const RopePullHubScreen()),
      ),
      GoRoute(
        path: '/student/rope/:id/board',
        builder: (_, state) => RopePullRoomScreen(
          roomId: state.pathParameters['id']!,
          boardMode: true,
        ),
      ),
      GoRoute(
        path: '/student/rope/:id',
        builder: (_, state) =>
            RopePullRoomScreen(roomId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (_, _) =>
            _studentShell('/student/profile', const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.studentPayments,
        redirect: (_, _) => Features.payments ? null : AppRoutes.studentPath,
        builder: (_, state) => _studentShell(
          '/student/path',
          PaymentsScreen(
            subjectId: state.uri.queryParameters['subject'],
            highlightPackId: state.uri.queryParameters['pack'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.studentPaymentsReturn,
        redirect: (_, _) => Features.payments ? null : AppRoutes.studentPath,
        builder: (_, state) => _studentShell(
          '/student/path',
          PaymentsScreen(
            reference:
                state.uri.queryParameters['reference'] ??
                state.uri.queryParameters['trxref'],
          ),
        ),
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
        path: AppRoutes.teacherAssign,
        builder: (_, _) =>
            _teacherShell(AppRoutes.teacherAssign, const AssignmentsScreen()),
      ),
      GoRoute(
        path: '/teacher/report/:id',
        builder: (_, state) => ProgressReportScreen(
          studentId: state.pathParameters['id'],
          backRoute: AppRoutes.teacherAssign,
        ),
      ),
      GoRoute(
        path: AppRoutes.studentReport,
        builder: (_, _) =>
            const ProgressReportScreen(backRoute: AppRoutes.studentProfile),
      ),
      GoRoute(
        path: '/teacher/play',
        builder: (_, _) => _teacherShell(
          '/teacher/live',
          const RopePullHubScreen(hostPlays: false, boardByDefault: true),
        ),
      ),
      GoRoute(
        path: '/teacher/rope/:id',
        builder: (_, state) => RopePullRoomScreen(
          roomId: state.pathParameters['id']!,
          boardMode: true,
          closeRoute: AppRoutes.teacherPlay,
        ),
      ),
      GoRoute(
        path: AppRoutes.teacherLiveCompose,
        builder: (_, _) =>
            _teacherShell('/teacher/live', const TeacherLiveComposeScreen()),
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
        path: AppRoutes.parentHome,
        builder: (_, _) =>
            _parentShell(AppRoutes.parentHome, const ParentHomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.parentPacks,
        redirect: (_, _) => Features.payments ? null : AppRoutes.parentHome,
        builder: (_, state) => _parentShell(
          AppRoutes.parentPacks,
          PaymentsScreen(
            subjectId: state.uri.queryParameters['subject'],
            highlightPackId: state.uri.queryParameters['pack'],
            learnerUserId: state.uri.queryParameters['learner'],
            parentMode: true,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.parentPaymentsReturn,
        redirect: (_, _) => Features.payments ? null : AppRoutes.parentHome,
        builder: (_, state) => _parentShell(
          AppRoutes.parentPacks,
          PaymentsScreen(
            reference:
                state.uri.queryParameters['reference'] ??
                state.uri.queryParameters['trxref'],
            parentMode: true,
          ),
        ),
      ),
      GoRoute(path: '/parent', redirect: (_, _) => AppRoutes.parentHome),
      GoRoute(
        path: '/reviewer/queue',
        builder: (_, _) =>
            _reviewerShell('/reviewer/queue', const ReviewQueueScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (_, _) =>
            _adminShell(AppRoutes.adminHome, const AdminOverviewScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminSchools,
        builder: (_, _) =>
            _adminShell(AppRoutes.adminSchools, const AdminSchoolsScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (_, _) =>
            _adminShell(AppRoutes.adminUsers, const AdminUsersScreen()),
      ),
      GoRoute(
        path: AppRoutes.adminPerformance,
        builder: (_, _) => _adminShell(
          AppRoutes.adminPerformance,
          const AdminPerformanceScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminPayments,
        redirect: (_, _) => Features.payments ? null : AppRoutes.adminHome,
        builder: (_, _) =>
            _adminShell(AppRoutes.adminPayments, const AdminPaymentsScreen()),
      ),
      GoRoute(
        path: '/admin/performance/:id',
        builder: (_, state) => _adminShell(
          AppRoutes.adminPerformance,
          AdminPerformanceScreen(userId: state.pathParameters['id']),
        ),
      ),
    ],
  );
});
