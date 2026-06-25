import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kidversity/data/app_state.dart';
import 'package:kidversity/data/auth_state.dart';
import 'package:kidversity/data/content_catalog.dart';
import 'package:kidversity/data/supabase_auth.dart';
import 'package:kidversity/features/auth/auth_screen.dart';
import 'package:kidversity/features/shell/app_shell.dart';
import 'package:kidversity/features/student/student_home.dart';
import 'package:kidversity/theme/app_theme.dart';

void main() {
  testWidgets('Auth screen shows sign-in tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            final c = SupabaseAuthController();
            c.isLoading = false;
            return c;
          }),
        ],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('AppShell renders StudentHome content above bottom nav', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            final c = SupabaseAuthController();
            c.isLoading = false;
            c.isAuthenticated = true;
            c.onboardingComplete = true;
            c.displayName = 'Chioma';
            return c;
          }),
          catalogProvider.overrideWith((ref) => ContentCatalog()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(
            currentPath: '/student/home',
            items: [
              NavItem(Icons.home_outlined, Icons.home_rounded, 'Home', '/student/home'),
              NavItem(Icons.explore_outlined, Icons.explore_rounded, 'Explore', '/student/explore'),
            ],
            child: StudentHome(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Hi, Chioma'), findsOneWidget);
    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
