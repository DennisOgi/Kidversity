import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'mock_data.dart';

/// Loads lessons, badges, and leaderboard from Supabase with mock fallback.
class ContentCatalog extends ChangeNotifier {
  List<Lesson> lessons = MockData.lessons;
  List<Lesson> assigned = MockData.assigned;
  List<RewardBadge> badges = MockData.badges;
  List<LeaderboardEntry> leaderboard = MockData.leaderboard;
  bool isLoading = false;
  bool useRemote = false;

  Future<void> load({bool force = false}) async {
    if (isLoading) return;
    if (useRemote && !force) return;

    // If Supabase is not initialized, stay in mock mode
    if (!SupabaseService.instance.isInitialized) {
      // Ensure mock data is loaded
      if (lessons.isEmpty) {
        lessons = MockData.lessons;
        assigned = MockData.assigned;
        badges = MockData.badges;
        leaderboard = MockData.leaderboard;
        notifyListeners();
      }
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final service = SupabaseService.instance;
      final lessonsResult = await service.fetchLessons();
      if (lessonsResult.isSuccess && lessonsResult.data!.isNotEmpty) {
        lessons = lessonsResult.data!;
        useRemote = true;
      }

      final assignedResult = await service.fetchAssignedLessons();
      if (assignedResult.isSuccess && assignedResult.data!.isNotEmpty) {
        assigned = assignedResult.data!;
      } else if (useRemote) {
        assigned = lessons.where((l) => l.progress > 0).toList();
        if (assigned.isEmpty && lessons.isNotEmpty) {
          assigned = [lessons.first];
        }
      }

      final badgesResult = await service.fetchBadges();
      if (badgesResult.isSuccess && badgesResult.data!.isNotEmpty) {
        badges = badgesResult.data!;
      }

      final boardResult = await service.fetchLeaderboard();
      if (boardResult.isSuccess && boardResult.data!.isNotEmpty) {
        leaderboard = boardResult.data!;
      }
    } catch (e) {
      debugPrint('ContentCatalog load failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterLessonComplete() async {
    await load(force: true);
  }
}
