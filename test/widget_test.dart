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
import 'package:kidversity/features/teacher/teacher_home.dart';
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Hi, Chioma'), findsOneWidget);
    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Home'), findsNWidgets(2));

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('AppShell renders TeacherHome content (no blank dashboard)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) {
            final c = SupabaseAuthController();
            c.isLoading = false;
            c.isAuthenticated = true;
            c.onboardingComplete = true;
            c.displayName = 'Ms. Chen';
            return c;
          }),
          catalogProvider.overrideWith((ref) => ContentCatalog()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AppShell(
            currentPath: '/teacher/home',
            items: [
              NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home', '/teacher/home'),
              NavItem(Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'Create', '/teacher/create'),
            ],
            child: TeacherHome(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('Ms. Chen'), findsOneWidget);
    expect(find.text('Your lessons'), findsOneWidget);
    expect(find.text('Home'), findsNWidgets(2));

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('AppShell bottom nav renders rounded pill container', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

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
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();

    final pill = tester.renderObject<RenderBox>(find.byKey(const Key('bottomNavPill')));
    expect(pill.size.width, greaterThan(200));
    expect(pill.size.height, greaterThan(40));

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
