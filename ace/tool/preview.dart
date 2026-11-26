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
