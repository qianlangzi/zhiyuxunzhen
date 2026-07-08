import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assignment_model.dart';
import '../models/case_model.dart';
import '../models/chat_model.dart';
import '../models/learning_model.dart';
import '../sources/mock_data.dart';

/// 病例仓库
class CaseRepository {
  List<CaseModel> all() => MockData.cases.toList();

  CaseModel? byId(String id) {
    for (final CaseModel c in MockData.cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  CaseModel daily() => MockData.dailyCase;

  List<MarketCaseModel> market() => MockData.marketCases.toList();
}

final Provider<CaseRepository> caseRepositoryProvider =
    Provider<CaseRepository>((ProviderRef<CaseRepository> ref) {
  return CaseRepository();
});

/// 学习数据仓库
class LearningRepository {
  List<ChatMessage> chat() => MockData.chatMessages.toList();
  List<ReasoningNode> reasoning() => MockData.reasoningNodes.toList();
  List<AbilityScore> abilities() => MockData.abilityScores.toList();
  List<LearningPathItem> learningPath() => MockData.learningPath.toList();
  List<MistakeItem> mistakes() => MockData.mistakes.toList();
  List<HeatmapDay> heatmap() => MockData.heatmapDays.toList();
}

final Provider<LearningRepository> learningRepositoryProvider =
    Provider<LearningRepository>((ProviderRef<LearningRepository> ref) {
  return LearningRepository();
});

/// 教学仓库
class TeachingRepository {
  List<AssignmentModel> assignments() => MockData.assignments.toList();
  List<ReviewItem> reviewQueue() => MockData.reviewQueue.toList();
  List<WeaknessItem> weakness() => MockData.weakness.toList();
  List<FormatShieldRule> formatRules() => MockData.formatShieldRules.toList();
}

final Provider<TeachingRepository> teachingRepositoryProvider =
    Provider<TeachingRepository>((ProviderRef<TeachingRepository> ref) {
  return TeachingRepository();
});
