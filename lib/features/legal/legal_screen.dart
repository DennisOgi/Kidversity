import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

enum LegalDocument { privacy, terms, guardianConsent }

class LegalScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final (title, summary) = switch (document) {
      LegalDocument.privacy => (
        'Privacy',
        'Kidversity stores account, class, and Mandarin learning progress data '
            'only to provide the learning service. We do not sell learner data.',
      ),
      LegalDocument.terms => (
        'Terms',
        'Kidversity is a guided Mandarin learning service for children, '
            'families, teachers, and approved language reviewers.',
      ),
      LegalDocument.guardianConsent => (
        'Guardian consent',
        'A parent or guardian must approve use by a child where local law '
            'requires it. Schools remain responsible for their learner consent process.',
      ),
    };
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(summary),
                const SizedBox(height: 18),
                const Text(
                  'The complete reviewed legal document will be published '
                  'before the production service opens.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
