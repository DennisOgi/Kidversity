// Promo demo build: the real Kidversity screens with sample data, so the
// promo video can film signed-in pages without a real account.
//
//   flutter build web --release -t tool/promo_demo.dart -o build/promo_demo
//
// Routes: /  /auth  /onboarding  /splash  /student  /teacher  /school
//         /school/teachers  /school/students  /parent  /rope
//
// Nothing here talks to Supabase: every provider a page reads is overridden
// with the sample data below.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidversity/data/app_state.dart';
import 'package:kidversity/data/auth_state.dart';
import 'package:kidversity/data/records_providers.dart';
import 'package:kidversity/data/supabase_auth.dart';
import 'package:kidversity/features/auth/auth_screen.dart';
import 'package:kidversity/features/landing/landing_screen.dart';
import 'package:kidversity/features/onboarding/onboarding_screen.dart';
import 'package:kidversity/features/parent/parent_home_screen.dart';
import 'package:kidversity/features/school/school_admin_screens.dart';
import 'package:kidversity/features/shell/app_shell.dart';
import 'package:kidversity/features/splash/splash_screen.dart';
import 'package:kidversity/features/student/student_home_screen.dart';
import 'package:kidversity/features/teacher/school_home.dart';
import 'package:kidversity/features/teacher/teacher_home_screen.dart';
import 'package:kidversity/models/family_models.dart';
import 'package:kidversity/models/learning_records_models.dart';
import 'package:kidversity/models/mandarin_content.dart';
import 'package:kidversity/models/school_models.dart';
import 'package:kidversity/services/family_service.dart';
import 'package:kidversity/services/foundation_progress_service.dart';
import 'package:kidversity/theme/app_theme.dart';
import 'package:kidversity/theme/role_style.dart';
import 'package:kidversity/widgets/rope_arena.dart';

final _now = DateTime.now();

// --- Sample data -------------------------------------------------------------

MandarinCourseLesson _lesson(int n, String title) => MandarinCourseLesson(
  id: 'mfv1_l${n.toString().padLeft(2, '0')}',
  sequence: n,
  moduleSequence: 1,
  title: title,
  objective: '',
  status: CourseLessonStatus.approved,
  vocabulary: const [],
  examples: const [],
  grammar: const [],
  dialogue: const [],
  activities: const [],
  assessment: const [],
  explanation: '',
  xpReward: 20,
);

final _course = MandarinCourse(
  id: 'c',
  title: 'Foundation',
  level: 'A1',
  targetAge: '10+',
  modules: [
    MandarinModule(
      sequence: 1,
      title: 'M1',
      subtitle: '',
      lessons: [
        for (var i = 1; i <= 30; i++)
          _lesson(i, i == 7 ? 'At the restaurant: ordering food' : 'Lesson $i'),
      ],
    ),
  ],
);

FoundationStudentProgress _learner(
  String id,
  String name,
  String emoji,
  int done,
  double avg,
  int daysAgo,
  int thisWeek,
  LearningMovement movement, [
  List<String> reasons = const [],
]) => FoundationStudentProgress(
  userId: id,
  name: name,
  avatarEmoji: emoji,
  completedLessonIds: {for (var i = 1; i <= done; i++) 'l$i'},
  averageScore: avg,
  scoresByLesson: const {},
  weakItemIds: const [],
  lastCompletedAt: _now.subtract(Duration(days: daysAgo)),
  lessonsThisWeek: thisWeek,
  movement: movement,
  attentionReasons: reasons,
);

final _dashboard = FoundationClassDashboard(
  generatedAt: _now,
  students: [
    _learner(
      '1',
      'Caleb Lawal',
      '🦁',
      3,
      52,
      6,
      0,
      LearningMovement.struggling,
      ['No lesson for 6 days'],
    ),
    _learner('2', 'Bella Tijani', '🐼', 5, 61, 0, 1, LearningMovement.quiet, [
      'Missed tones 4 times in lesson 5',
    ]),
    _learner('3', 'Tomi Okafor', '🦊', 7, 78, 0, 3, LearningMovement.rising),
    _learner('4', 'Aisha Bello', '🐯', 11, 91, 1, 2, LearningMovement.steady),
    _learner('5', 'Dami Musa', '🐨', 4, 64, 2, 1, LearningMovement.steady),
  ],
  classHotspots: const [
    StruggleItem(key: 'a', label: '谢谢 xièxie', detail: 'Tones', missCount: 15),
    StruggleItem(
      key: 'b',
      label: '多少 duōshao',
      detail: 'Meaning',
      missCount: 9,
    ),
  ],
);

const _students = [
  ClassStudent(userId: '1', name: 'Caleb', avatar: '🦁'),
  ClassStudent(userId: '2', name: 'Bella', avatar: '🐼'),
  ClassStudent(userId: '3', name: 'Tomi', avatar: '🦊'),
  ClassStudent(userId: '4', name: 'Aisha', avatar: '🐯'),
  ClassStudent(userId: '5', name: 'Dami', avatar: '🐨'),
];

ClassAssignment _assignment(
  String id,
  AssignmentKind kind,
  String title,
  int dueIn,
) => ClassAssignment(
  id: id,
  classId: 'c1',
  kind: kind,
  title: title,
  config: kind == AssignmentKind.maths ? const {'level': 4} : const {},
  dueAt: _now.add(Duration(days: dueIn)),
  createdAt: _now.subtract(const Duration(days: 2)),
);

final _assignments = [
  AssignmentProgress(
    assignment: _assignment(
      'a1',
      AssignmentKind.maths,
      'Maths level 4: fractions',
      1,
    ),
    students: _students,
    submissions: const {},
    lessonScores: const {},
  ),
  AssignmentProgress(
    assignment: _assignment(
      'a2',
      AssignmentKind.lesson,
      'Mandarin lessons 6 and 7',
      3,
    ),
    students: _students,
    submissions: const {},
    lessonScores: const {'3': 80, '4': 92},
  ),
];

final _school = SchoolOverview.fromJson({
  'school_id': 's1',
  'school_name': 'Pearls Garden School',
  'viewer_role': 'admin',
  'student_count': 6,
  'classes': [
    {
      'id': 'c1',
      'name': 'JSS 2A',
      'teacher_id': 't1',
      'teacher_name': 'Mrs. Adeyemi',
      'member_count': 3,
      'join_code': 'K7Q42M',
    },
    {
      'id': 'c2',
      'name': 'JSS 3B',
      'teacher_id': '',
      'member_count': 0,
      'join_code': 'P3R7TA',
    },
  ],
  'entries': [],
});

final _directory = SchoolDirectory.fromJson({
  'teachers': [
    {
      'user_id': 't1',
      'display_name': 'Funmi Adeyemi',
      'email': 'funmi@pearls.ng',
      'role': 'teacher',
      'class_ids': ['c1'],
    },
  ],
  'students': [
    for (final (i, n) in [
      'Tomi Okafor',
      'Aisha Bello',
      'Caleb Lawal',
      'Bella Tijani',
      'Dami Musa',
      'Kemi Ade',
    ].indexed)
      {
        'user_id': 's$i',
        'display_name': n,
        'email': '${n.split(' ').first.toLowerCase()}@mail.ng',
        'role': 'student',
        'class_ids': i < 3 ? ['c1'] : [],
      },
  ],
  'people': [],
});

final _schoolAdmin = SchoolAdminInfo.fromJson({
  'school_id': 's1',
  'school_name': 'Pearls Garden School',
  'staff_code': 'KQ7M-4TZP',
  'invites': [
    {'id': 'i1', 'email': 'mr.eze@pearls.ng', 'role': 'teacher'},
  ],
  'staff': [
    {
      'user_id': 'me',
      'display_name': 'Chidi Okoro',
      'email': 'chidi@pearls.ng',
      'role': 'admin',
      'classes': [],
    },
    {
      'user_id': 't1',
      'display_name': 'Funmi Adeyemi',
      'email': 'funmi@pearls.ng',
      'role': 'teacher',
      'classes': [
        {'id': 'c1', 'name': 'JSS 2A'},
      ],
    },
  ],
});

final _family = FamilyOverview.fromJson({
  'family_id': 'f',
  'link_code': 'FMY8K2',
  'stats': {},
  'learners': [
    {
      'user_id': 'k1',
      'display_name': 'Tomi Okafor',
      'avatar_emoji': '🦊',
      'xp': 1240,
      'streak_days': 12,
      'minutes_learned': 340,
      'last_activity_date': _now.toIso8601String(),
      'subjects': [
        {
          'subject_id': 'mandarin',
          'lessons_total': 30,
          'lessons_completed': 7,
          'next_sequence': 8,
        },
        {
          'subject_id': 'maths',
          'lessons_total': 20,
          'lessons_completed': 4,
          'next_sequence': 5,
        },
      ],
    },
    {
      'user_id': 'k2',
      'display_name': 'Kemi Okafor',
      'avatar_emoji': '🐼',
      'xp': 300,
      'streak_days': 3,
      'minutes_learned': 45,
      'subjects': [],
    },
  ],
});

// --- Role shells --------------------------------------------------------------

const _studentNav = [
  NavItem(
    Icons.route_outlined,
    Icons.route_rounded,
    'Home',
    '/student',
    'Your next step',
    AppTint.violet,
  ),
  NavItem(
    Icons.school_outlined,
    Icons.school_rounded,
    'Practice',
    '/x1',
    'Review, exams, and drills',
    AppTint.sky,
  ),
  NavItem(
    Icons.sports_esports_outlined,
    Icons.sports_esports_rounded,
    'Play',
    '/rope',
    'Rope Pull with friends',
    AppTint.sun,
  ),
  NavItem(
    Icons.person_outline_rounded,
    Icons.person_rounded,
    'Me',
    '/x2',
    'Class and learning settings',
    AppTint.pink,
  ),
];

const _teacherNav = [
  NavItem(
    Icons.home_outlined,
    Icons.home_rounded,
    'Home',
    '/teacher',
    'Today in your class',
    AppTint.mint,
  ),
  NavItem(
    Icons.groups_outlined,
    Icons.groups_rounded,
    'Class',
    '/x3',
    'Create a class and share the join code',
    AppTint.violet,
  ),
  NavItem(
    Icons.insights_outlined,
    Icons.insights_rounded,
    'Progress',
    '/x4',
    'Learning movement & check-ins',
    AppTint.sky,
  ),
  NavItem(
    Icons.assignment_outlined,
    Icons.assignment_rounded,
    'Assign',
    '/x5',
    'Set work and see who finished',
    AppTint.sun,
  ),
  NavItem(
    Icons.bolt_outlined,
    Icons.bolt_rounded,
    'Live',
    '/x6',
    'Timed quizzes',
    AppTint.coral,
  ),
];

const _schoolNav = [
  NavItem(
    Icons.dashboard_outlined,
    Icons.dashboard_rounded,
    'Overview',
    '/school',
    'Classes and setup',
    AppTint.violet,
  ),
  NavItem(
    Icons.co_present_outlined,
    Icons.co_present_rounded,
    'Teachers',
    '/school/teachers',
    'Invite and manage staff',
    AppTint.sky,
  ),
  NavItem(
    Icons.school_outlined,
    Icons.school_rounded,
    'Students',
    '/school/students',
    'Place students in classes',
    AppTint.mint,
  ),
  NavItem(
    Icons.settings_outlined,
    Icons.settings_rounded,
    'Settings',
    '/x7',
    'School name and staff code',
    AppTint.sun,
  ),
];

const _parentNav = [
  NavItem(
    Icons.family_restroom_outlined,
    Icons.family_restroom_rounded,
    'Family',
    '/parent',
    'Your children and what is due',
    AppTint.coral,
  ),
];

Widget _shell(String path, List<NavItem> items, RoleStyle style, Widget page) =>
    AppShell(currentPath: path, items: items, style: style, child: page);

// --- Rope Pull: a scripted match so the arena can be filmed ------------------

class _RopeDemo extends StatefulWidget {
  const _RopeDemo();

  @override
  State<_RopeDemo> createState() => _RopeDemoState();
}

class _RopeDemoState extends State<_RopeDemo> {
  final _c = RopeArenaController();
  Timer? _t;
  int _score = 0;
  int _round = 0;
  // Teal edges ahead, Indigo fights back, Teal wins.
  static const _script = [1, 1, -1, 1, -1, 1, 1, 1];

  @override
  void initState() {
    super.initState();
    _c.applyState(
      position: 0,
      phase: RopePhase.playing,
      indigoScore: 0,
      tealScore: 0,
      snap: true,
    );
    _t = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (_round >= _script.length) {
        _t?.cancel();
        return;
      }
      final step = _script[_round++];
      _score += step;
      final team = step < 0 ? RopeTeam.indigo : RopeTeam.teal;
      _c.feedback(team, correct: true);
      final done = _score.abs() >= 4;
      _c.applyState(
        position: _score / 4,
        phase: done ? RopePhase.finished : RopePhase.playing,
        winner: done ? (_score < 0 ? RopeTeam.indigo : RopeTeam.teal) : null,
        indigoScore: _script.take(_round).where((s) => s < 0).length,
        tealScore: _script.take(_round).where((s) => s > 0).length,
      );
      if (done) _t?.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return ColoredBox(
      color: const Color(0xFF20213B),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.max(320, 1200)),
            child: RopePullKitScene(controller: _c),
          ),
        ),
      ),
    );
  }
}

// --- App -----------------------------------------------------------------------

SupabaseAuthController _account(String name, {bool signedIn = true}) {
  final c = SupabaseAuthController();
  c.isLoading = false;
  c.isAuthenticated = signedIn;
  c.onboardingComplete = signedIn;
  c.displayName = name;
  c.xp = 1240;
  c.level = 3;
  c.streakDays = 12;
  c.lessonsCompleted = 23;
  c.minutesLearned = 340;
  return c;
}

void main() {
  final start = Uri.base.queryParameters['view'] ?? Uri.base.path;
  final role = start.split('/').where((p) => p.isNotEmpty).firstOrNull ?? '';
  final name = switch (role) {
    'teacher' => 'Funmi Adeyemi',
    'school' => 'Chidi Okoro',
    'parent' => 'Ngozi Okafor',
    _ => 'Tomi Okafor',
  };
  final signedIn = !{'', 'auth', 'onboarding', 'splash'}.contains(role);

  final router = GoRouter(
    initialLocation: start.isEmpty ? '/' : start,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/student',
        builder: (_, _) => _shell(
          '/student',
          _studentNav,
          RoleStyle.student,
          const StudentHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/rope',
        builder: (_, _) =>
            _shell('/rope', _studentNav, RoleStyle.student, const _RopeDemo()),
      ),
      GoRoute(
        path: '/teacher',
        builder: (_, _) => _shell(
          '/teacher',
          _teacherNav,
          RoleStyle.teacher,
          const TeacherHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/school',
        builder: (_, _) =>
            _shell('/school', _schoolNav, RoleStyle.school, const SchoolHome()),
      ),
      GoRoute(
        path: '/school/teachers',
        builder: (_, _) => _shell(
          '/school/teachers',
          _schoolNav,
          RoleStyle.school,
          const SchoolTeachersScreen(),
        ),
      ),
      GoRoute(
        path: '/school/students',
        builder: (_, _) => _shell(
          '/school/students',
          _schoolNav,
          RoleStyle.school,
          const SchoolStudentsScreen(),
        ),
      ),
      GoRoute(
        path: '/parent',
        builder: (_, _) => _shell(
          '/parent',
          _parentNav,
          RoleStyle.parent,
          const ParentHomeScreen(),
        ),
      ),
    ],
  );

  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => _account(name, signedIn: signedIn),
        ),
        activeLiveTestProvider.overrideWith((ref) => Stream.value(null)),
        mandarinCourseProvider.overrideWith((ref) async => _course),
        foundationCompletedLessonIdsProvider.overrideWith(
          (ref) async => {for (var i = 1; i <= 6; i++) 'mfv1_l0$i'},
        ),
        myAssignmentsProvider.overrideWith(
          (ref) async => (
            assignments: [for (final a in _assignments) a.assignment],
            submissions: <String, AssignmentSubmission>{},
          ),
        ),
        myMistakeGroupsProvider.overrideWith((ref) async => const []),
        myMathsResultsProvider.overrideWith(
          (ref) async => [
            MathsResult(level: 4, correct: 8, total: 10, createdAt: _now),
          ],
        ),
        myExamAttemptsProvider.overrideWith((ref) async => const []),
        paymentAccessProvider.overrideWith((ref) => Future.error('offline')),
        schoolOverviewProvider.overrideWith((ref) async => _school),
        schoolDirectoryProvider.overrideWith((ref) async => _directory),
        schoolAdminProvider.overrideWith((ref) async => _schoolAdmin),
        teacherClassInfoProvider.overrideWith(
          (ref) async => (id: 'c1', name: 'JSS 2A', code: 'K7Q42M'),
        ),
        foundationClassDashboardProvider.overrideWith(
          (ref) async => _dashboard,
        ),
        classAssignmentsProvider.overrideWith((ref) async => _assignments),
        familyOverviewProvider.overrideWith((ref) async => _family),
        familyCodeProvider.overrideWith((ref) async => 'FMY8K2'),
        paymentCatalogProvider.overrideWith((ref) => Future.error('offline')),
      ],
      child: MaterialApp.router(
        title: 'Kidversity',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
}
