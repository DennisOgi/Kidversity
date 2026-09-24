import 'package:flutter/material.dart';

import '../../../router/navigation.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/common.dart';
import 'lab_catalog.dart';

class LabScreen extends StatelessWidget {
  final String id;
  const LabScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final spec = labById(id);
    return ShellScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'All experiments',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => popOrGo(context, AppRoutes.studentLabs),
                ),
                if (spec == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'That experiment is not on this bench.',
                      style: TextStyle(color: AppColors.ink),
                    ),
                  )
                else
                  spec.build(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
