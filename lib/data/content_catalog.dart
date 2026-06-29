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
      
      // If Supabase returns successfully but with empty data, use MockData as fallback
      if (lessonsResult.isSuccess) {
        if (lessonsResult.data!.isNotEmpty) {
          lessons = lessonsResult.data!;
          useRemote = true;
        } else {
          // Supabase is empty - use MockData
          debugPrint('📦 Supabase database is empty. Using MockData as fallback.');
          lessons = MockData.lessons;
          assigned = MockData.assigned;
          badges = MockData.badges;
          leaderboard = MockData.leaderboard;
          isLoading = false;
          notifyListeners();
          return;
        }
      }

      final assignedResult = await service.fetchAssignedLessons();
      if (assignedResult.isSuccess && assignedResult.data!.isNotEmpty) {
        assigned = assignedResult.data!;
      } else if (useRemote) {
        assigned = lessons.where((l) => l.progress > 0).toList();
        if (assigned.isEmpty && lessons.isNotEmpty) {
          assigned = [lessons.first];
        }
      } else {
        // Use MockData assigned lessons
        assigned = MockData.assigned;
      }

      final badgesResult = await service.fetchBadges();
      if (badgesResult.isSuccess && badgesResult.data!.isNotEmpty) {
        badges = badgesResult.data!;
      } else {
        badges = MockData.badges;
      }

      final boardResult = await service.fetchLeaderboard();
      if (boardResult.isSuccess && boardResult.data!.isNotEmpty) {
        leaderboard = boardResult.data!;
      } else {
        leaderboard = MockData.leaderboard;
      }
    } catch (e) {
      debugPrint('ContentCatalog load failed: $e. Falling back to MockData.');
      // On error, fallback to MockData
      lessons = MockData.lessons;
      assigned = MockData.assigned;
      badges = MockData.badges;
      leaderboard = MockData.leaderboard;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterLessonComplete() async {
    await load(force: true);
  }
}
