// Local design preview: the real ACE screens with sample data and no
// backend. Build with:
//   flutter build web -t tool/preview.dart -o ../build/ace_design
// Open ?view=/ , /welcome, /c/as-mathematics or /l/math-as-derivatives.
import 'package:ace_app/data/api.dart';
import 'package:ace_app/screens/channel_screen.dart';
import 'package:ace_app/screens/home_screen.dart';
import 'package:ace_app/screens/landing_screen.dart';
import 'package:ace_app/screens/lesson_screen.dart';
import 'package:ace_app/screens/sign_in_screen.dart';
import 'package:ace_app/screens/splash_screen.dart';
import 'package:ace_app/staff/marking_screen.dart';
import 'package:ace_app/staff/overview_screen.dart';
import 'package:ace_app/staff/people_screen.dart';
import 'package:ace_app/staff/progress_screen.dart';
import 'package:ace_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeApi extends AceApi {
  @override
  Future<Map<String, dynamic>> me() async => {
    'display_name': 'Amara Okafor',
    'schools': [
      {'name': 'ACE Demo Academy', 'role': 'student'},
    ],
    'stats': {
      'questions_tried': 6,
      'matched': 4,
      'streak_days': 3,
      'awaiting_teacher': 3,
    },
    'resume': {
      'lesson_id': 'math-as-derivatives',
      'title': 'Differentiation and tangents',
      'stage': 'AS',
      'subject': 'Mathematics',
    },
    'channels': [
      for (final c in const [
        ('as-mathematics', 'AS', 'Mathematics', '9709', 8, 4, 3),
        ('as-physics', 'AS', 'Physics', '9702', 8, 3, 2),
        ('a2-mathematics', 'A2', 'Mathematics', '9709', 8, 0, 0),
        ('a2-physics', 'A2', 'Physics', '9702', 8, 1, 1),
      ])
        {
          'id': c.$1,
          'stage': c.$2,
          'subject': c.$3,
          'syllabus': 'Cambridge International ${c.$4}',
          'lessons': 2,
          'questions': c.$5,
          'attempted': c.$6,
          'matched': c.$7,
        },
    ],
  };

  @override
  Future<Map<String, dynamic>> channel(String id) async => {
    'id': id,
    'stage': 'AS',
    'subject': 'Mathematics',
    'syllabus': 'Cambridge International 9709 · exams 2026–2027',
    'lessons': [
      {
        'id': 'math-as-quadratics',
        'title': 'Quadratics: roots and turning points',
        'minutes': 20,
        'topic': 'Solving quadratics',
        'topic_ref': '1.1',
        'questions': 4,
        'answered': 4,
      },
      {
        'id': 'math-as-derivatives',
        'title': 'Differentiation and tangents',
        'minutes': 20,
        'topic': 'Rates of change',
        'topic_ref': '1.7',
        'questions': 4,
        'answered': 1,
      },
      {
        'id': 'x',
        'title': 'Coordinate geometry of lines and circles',
        'minutes': 25,
        'topic': 'Coordinates and geometry',
        'topic_ref': '1.3',
        'questions': 5,
        'answered': 0,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> progress(String channelId) async => {
    'questions': 13,
    'attempted': 5,
    'final_answer_matched': 4,
    'awaiting_teacher': 2,
  };

  @override
  Future<Map<String, dynamic>> lesson(String id) async => {
    'id': id,
    'channel_id': 'as-mathematics',
    'stage': 'AS',
    'title': 'Differentiation and tangents',
    'minutes': 20,
    'topic': {'ref': '1.7', 'title': 'Rates of change'},
    'objectives': [
      'Differentiate powers of x.',
      'Find a tangent gradient.',
      'Use a derivative to locate and classify a turning point.',
    ],
    'explanation_markdown':
        r'The derivative gives the local rate of change and the tangent gradient. For a constant $a$, $\frac{d}{dx}(ax^n)=anx^{n-1}$. Differentiate a sum term by term. To find a tangent at $x=a$, find both $f(a)$ and $f\prime(a)$, then use $y-f(a)=f\prime(a)(x-a)$.',
    'worked_example': {
      'prompt': r'Find the tangent to $y=x^2+1$ at $x=2$.',
      'steps': [
        r'$\frac{dy}{dx}=2x$, so the gradient is 4.',
        r'At $x=2$, $y=5$.',
        r'Use $y-5=4(x-2)$.',
      ],
      'answer': r'$y=4x-3$.',
    },
    'common_errors': [
      'Differentiating a constant gives zero.',
      'A stationary point need not be a minimum.',
    ],
    'exit_check':
        'Why do you need both the point and the gradient for a tangent?',
    'questions': [
      {
        'id': 'q1',
        'kind': 'constructed_response',
        'prompt_markdown': r'Differentiate $y=4x^3-5x+7$.',
        'max_marks': 2,
        'attempts': 0,
      },
      {
        'id': 'q2',
        'kind': 'numeric',
        'prompt_markdown':
            r'For $y=2x^3-3x^2$, find the tangent gradient at $x=2$.',
        'max_marks': 2,
        'attempts': 1,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> submit({
    required String questionId,
    num? finalAnswer,
    String? unit,
    String? working,
    String? option,
  }) async => {
    'attempt_id': DateTime.now().toIso8601String(),
    'attempt_no': 2,
    'final_answer_status': finalAnswer == 12
        ? 'final_answer_match'
        : 'try_again',
    'marking_state': (working ?? '').isEmpty
        ? 'final_answer_checked'
        : 'needs_review',
    'feedback': {
      'correct_answer': '12.',
      'worked_solution': [
        r'$\frac{dy}{dx}=6x^2-6x$.',
        r'At $x=2$ the gradient is $24-12=12$.',
      ],
    },
  };

  static final _now = DateTime.now();
  static String _ago(int minutes) =>
      _now.subtract(Duration(minutes: minutes)).toIso8601String();

  @override
  Future<Map<String, dynamic>> staffOverview() async => {
    'role': 'admin',
    'display_name': 'Funmi Adeyemi',
    'school': {'name': 'ACE Demo Academy', 'join_code': 'DEMO2026'},
    'counts': {
      'students': 24,
      'teachers': 3,
      'to_mark': 6,
      'attempts_7d': 182,
      'active_7d': 19,
      'marked_7d': 41,
    },
    'activity': [
      for (var i = 13; i >= 0; i--)
        {
          'day': _now
              .subtract(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
          'attempts': const [
            6,
            9,
            4,
            12,
            18,
            3,
            2,
            14,
            21,
            17,
            25,
            8,
            5,
            22,
          ][13 - i],
        },
    ],
    'channels': [
      {
        'id': 'as-mathematics',
        'stage': 'AS',
        'subject': 'Mathematics',
        'questions': 8,
        'learners': 18,
        'attempts': 96,
        'correct_rate': 71,
      },
      {
        'id': 'as-physics',
        'stage': 'AS',
        'subject': 'Physics',
        'questions': 8,
        'learners': 14,
        'attempts': 64,
        'correct_rate': 64,
      },
      {
        'id': 'a2-mathematics',
        'stage': 'A2',
        'subject': 'Mathematics',
        'questions': 8,
        'learners': 10,
        'attempts': 31,
        'correct_rate': 58,
      },
      {
        'id': 'a2-physics',
        'stage': 'A2',
        'subject': 'Physics',
        'questions': 8,
        'learners': 6,
        'attempts': 19,
        'correct_rate': 80,
      },
    ],
    'attention': [
      {
        'user_id': 'u2',
        'name': 'Tunde Bello',
        'attempts': 6,
        'rate': 33,
        'last_active': _ago(2900),
      },
      {
        'user_id': 'u5',
        'name': 'Chidi Nwosu',
        'attempts': 9,
        'rate': 44,
        'last_active': _ago(400),
      },
      {
        'user_id': 'u3',
        'name': 'Zainab Yusuf',
        'attempts': 0,
        'rate': null,
        'last_active': null,
      },
    ],
    'recent': [
      {
        'attempt_id': 'a1',
        'name': 'Amara Okafor',
        'question': r'For $y=2x^3-3x^2$, find the tangent gradient at $x=2$.',
        'lesson': 'Differentiation and tangents',
        'status': 'try_again',
        'state': 'needs_review',
        'at': _ago(12),
      },
      {
        'attempt_id': 'a2',
        'name': 'David Mensah',
        'question':
            'A spherical planet produces a field strength of 12 N/kg at radius r. Find the field strength at 2r.',
        'lesson': 'Gravitational fields',
        'status': 'final_answer_match',
        'state': 'final_answer_checked',
        'at': _ago(55),
      },
      {
        'attempt_id': 'a3',
        'name': 'Tunde Bello',
        'question':
            'Find the equivalent resistance of 6 ohm and 3 ohm in parallel.',
        'lesson': 'Series and parallel resistance',
        'status': 'try_again',
        'state': 'final_answer_checked',
        'at': _ago(180),
      },
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> reviewQueue({
    String state = 'needs_review',
    String? channel,
  }) async => [
    {
      'attempt_id': 'a1',
      'user_id': 'u1',
      'name': 'Amara Okafor',
      'question': r'For $y=2x^3-3x^2$, find the tangent gradient at $x=2$.',
      'max_marks': 2,
      'stage': 'AS',
      'subject': 'Mathematics',
      'lesson': 'Differentiation and tangents',
      'attempt_no': 1,
      'status': 'try_again',
      'state': 'needs_review',
      'at': _ago(12),
    },
    {
      'attempt_id': 'a4',
      'user_id': 'u1',
      'name': 'Amara Okafor',
      'question': r'Solve $x^2-9x+20=0$.',
      'max_marks': 2,
      'stage': 'AS',
      'subject': 'Mathematics',
      'lesson': 'Quadratics: roots and turning points',
      'attempt_no': 1,
      'status': 'not_auto_checked',
      'state': 'needs_review',
      'at': _ago(130),
    },
    {
      'attempt_id': 'a5',
      'user_id': 'u5',
      'name': 'Chidi Nwosu',
      'question':
          'A car starts at 4 m/s and accelerates uniformly at 3 m/s^2 for 5 s. Find its final velocity.',
      'max_marks': 2,
      'stage': 'AS',
      'subject': 'Physics',
      'lesson': 'Uniform acceleration',
      'attempt_no': 2,
      'status': 'final_answer_match',
      'state': 'needs_review',
      'at': _ago(300),
    },
  ];

  @override
  Future<Map<String, dynamic>> attemptDetail(String attemptId) async => {
    'attempt_id': attemptId,
    'user_id': 'u1',
    'name': 'Amara Okafor',
    'attempt_no': 1,
    'at': _ago(12),
    'response': {
      'final_answer': 18,
      'working_text': '\\frac{dy}{dx} = 6x^2 - 3x\n6(2)^2 - 3(2) = 18',
    },
    'status': 'try_again',
    'state': 'needs_review',
    'awarded': null,
    'question': {
      'prompt': r'For $y=2x^3-3x^2$, find the tangent gradient at $x=2$.',
      'kind': 'numeric',
      'max_marks': 2,
      'lesson': 'Differentiation and tangents',
      'stage': 'AS',
      'subject': 'Mathematics',
    },
    'key': {
      'answer': '12.',
      'worked_solution': [
        r'$\frac{dy}{dx}=6x^2-6x$.',
        r'At $x=2$ the gradient is $24-12=12$.',
      ],
      'rubric': [
        {
          'criterion': r'Differentiates correctly: $\frac{dy}{dx}=6x^2-6x$.',
          'marks': 1,
        },
        {'criterion': r'Substitutes $x=2$ to get 12.', 'marks': 1},
      ],
    },
    'reviews': [],
  };

  @override
  Future<Map<String, dynamic>> classProgress(String channelId) async => {
    'lessons': [
      {
        'id': 'l1',
        'title': 'Quadratics: roots and turning points',
        'questions': 4,
      },
      {'id': 'l2', 'title': 'Differentiation and tangents', 'questions': 4},
    ],
    'students': [
      for (final r in const [
        ['Amara Okafor', 4, 3, 1, 0, 12],
        ['Chidi Nwosu', 3, 1, 2, 1, 400],
        ['David Mensah', 4, 4, 4, 4, 55],
        ['Ifeoma Obi', 2, 2, 0, 0, 1500],
        ['Tunde Bello', 1, 0, 0, 0, 2900],
        ['Zainab Yusuf', 0, 0, 0, 0, -1],
      ])
        {
          'user_id': r[0],
          'name': r[0],
          'last_active': (r[5] as int) < 0 ? null : _ago(r[5] as int),
          'cells': {
            'l1': {'tried': r[1], 'correct': r[2]},
            'l2': {'tried': r[3], 'correct': r[4]},
          },
        },
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> schoolPeople() async => [
    {
      'user_id': 'p0',
      'name': 'Dr. Ngozi Eze',
      'role': 'admin',
      'joined': _ago(90000),
      'is_me': true,
      'attempts': 0,
    },
    {
      'user_id': 'p1',
      'name': 'Funmi Adeyemi',
      'role': 'teacher',
      'joined': _ago(80000),
      'attempts': 0,
    },
    {
      'user_id': 'u1',
      'name': 'Amara Okafor',
      'role': 'student',
      'joined': _ago(7000),
      'attempts': 8,
      'last_active': _ago(12),
    },
    {
      'user_id': 'u4',
      'name': 'David Mensah',
      'role': 'student',
      'joined': _ago(7000),
      'attempts': 12,
      'last_active': _ago(55),
    },
    {
      'user_id': 'u2',
      'name': 'Tunde Bello',
      'role': 'student',
      'joined': _ago(7000),
      'attempts': 6,
      'last_active': _ago(2900),
    },
  ];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://preview.invalid',
    publishableKey: 'preview',
  );
  AceApi.instance = _FakeApi();
  final view = Uri.base.queryParameters['view'] ?? '/';
  final router = GoRouter(
    initialLocation: view,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/staff', builder: (_, _) => const StaffOverviewScreen()),
      GoRoute(path: '/staff/marking', builder: (_, _) => const MarkingScreen()),
      GoRoute(
        path: '/staff/progress',
        builder: (_, _) => const ProgressScreen(),
      ),
      GoRoute(path: '/staff/people', builder: (_, _) => const PeopleScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/splash',
        builder: (_, _) => SplashOverlay(onDone: () {}),
      ),
      GoRoute(
        path: '/c/:id',
        builder: (_, s) => ChannelScreen(channelId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/l/:id',
        builder: (_, s) => LessonScreen(lessonId: s.pathParameters['id']!),
      ),
    ],
  );
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: Ace.theme(),
      routerConfig: router,
    ),
  );
}
