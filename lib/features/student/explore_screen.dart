import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/lesson_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _query = '';
  String _subject = 'All';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(lessonsProvider);
    final subjects = ['All', ...{for (final l in all) l.subject}];
    final filtered = all.where((l) {
      final matchesQuery = _query.isEmpty ||
          l.title.toLowerCase().contains(_query.toLowerCase()) ||
          l.subject.toLowerCase().contains(_query.toLowerCase());
      final matchesSubject = _subject == 'All' || l.subject == _subject;
      return matchesQuery && matchesSubject;
    }).toList();

    final cross = MediaQuery.sizeOf(context).width > 720 ? 2 : 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      children: [
        Text('Explore lessons', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Discover something new or revisit a favourite',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search lessons or subjects',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: subjects.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = subjects[i];
              final selected = s == _subject;
              return GestureDetector(
                onTap: () => setState(() => _subject = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: 1.5),
                  ),
                  child: Text(s,
                      style: TextStyle(
                          color: selected ? Colors.white : AppColors.inkSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: _EmptyState(),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: 300,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) => LessonCard(
              lesson: filtered[i],
              onTap: () => context.go('/student/lesson/${filtered[i].id}'),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text('No lessons found', style: Theme.of(context).textTheme.titleLarge),
          Text('Try a different search or subject', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
