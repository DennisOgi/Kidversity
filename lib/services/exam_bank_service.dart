import 'dart:convert';

import '../core/error_handler.dart' as app_errors;
import '../models/past_questions_models.dart';
import 'supabase_service.dart';

class ExamBankStatus {
  final int questions;
  final int exams;
  final int subjects;
  final int papers;
  final int harvested;
  final int exhausted;

  const ExamBankStatus({
    required this.questions,
    required this.exams,
    required this.subjects,
    required this.papers,
    required this.harvested,
    required this.exhausted,
  });

  factory ExamBankStatus.fromJson(Map<String, dynamic> json) => ExamBankStatus(
    questions: (json['questions'] as num?)?.toInt() ?? 0,
    exams: (json['exams'] as num?)?.toInt() ?? 0,
    subjects: (json['subjects'] as num?)?.toInt() ?? 0,
    papers: (json['papers'] as num?)?.toInt() ?? 0,
    harvested: (json['harvested'] as num?)?.toInt() ?? 0,
    exhausted: (json['exhausted'] as num?)?.toInt() ?? 0,
  );

  bool get isEmpty => questions == 0;
}

class ExamBankHarvestResult {
  final int added;
  final int questions;
  final bool done;
  final String? message;

  const ExamBankHarvestResult({
    required this.added,
    required this.questions,
    required this.done,
    this.message,
  });
}

/// Reads and fills the Supabase copy of the Sdash question bank.
class ExamBankService {
  ExamBankService._();
  static final instance = ExamBankService._();

  static const fallbackCatalog = PastQuestionsCatalog(
    exams: [
      PastExamType(id: 1, name: 'UTME', slug: 'utme'),
      PastExamType(id: 2, name: 'WASSCE', slug: 'wassce'),
      PastExamType(id: 3, name: 'NECO', slug: 'neco'),
      PastExamType(id: 4, name: 'Post-UTME', slug: 'post-utme'),
      PastExamType(id: 5, name: 'University', slug: 'university'),
    ],
    subjects: [
      PastSubject(id: 1, name: 'Accounting', slug: 'accounting'),
      PastSubject(id: 2, name: 'Agriculture', slug: 'agriculture'),
      PastSubject(id: 3, name: 'Arabic Studies', slug: 'arabic'),
      PastSubject(id: 4, name: 'Biology', slug: 'biology'),
      PastSubject(id: 5, name: 'Chemistry', slug: 'chemistry'),
      PastSubject(id: 6, name: 'Civic Education', slug: 'civiledu'),
      PastSubject(id: 7, name: 'Commerce', slug: 'commerce'),
      PastSubject(id: 8, name: 'Computer Studies', slug: 'computer'),
      PastSubject(id: 9, name: 'CRK', slug: 'crk'),
      PastSubject(id: 10, name: 'Current Affairs', slug: 'currentaffairs'),
      PastSubject(id: 11, name: 'Economics', slug: 'economics'),
      PastSubject(id: 12, name: 'English Language', slug: 'english'),
      PastSubject(id: 13, name: 'English Literature', slug: 'englishlit'),
      PastSubject(id: 14, name: 'Fine Art', slug: 'fineart'),
      PastSubject(id: 15, name: 'Geography', slug: 'geography'),
      PastSubject(id: 16, name: 'Geology', slug: 'geology'),
      PastSubject(id: 17, name: 'Government', slug: 'government'),
      PastSubject(id: 18, name: 'Hausa', slug: 'hausa'),
      PastSubject(id: 19, name: 'History', slug: 'history'),
      PastSubject(id: 20, name: 'Home Economics', slug: 'homeeconomics'),
      PastSubject(id: 21, name: 'Igbo', slug: 'igbo'),
      PastSubject(id: 22, name: 'Insurance', slug: 'insurance'),
      PastSubject(id: 23, name: 'IRK', slug: 'irk'),
      PastSubject(id: 24, name: 'Mathematics', slug: 'mathematics'),
      PastSubject(id: 25, name: 'Music', slug: 'music'),
      PastSubject(id: 26, name: 'Physics', slug: 'physics'),
      PastSubject(id: 27, name: 'Yoruba', slug: 'yoruba'),
    ],
    years: [
      2026, 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016,
      2015, 2014, 2013, 2012, 2011, 2010, 2009, 2008, 2007, 2006, 2005,
      2004, 2003, 2002, 2001, 2000, 1999, 1998, 1997, 1996, 1995, 1994,
      1993, 1992, 1991, 1990, 1989, 1988,
    ],
  );

  bool get _ready => SupabaseService.instance.isInitialized;

  Future<PastQuestionsCatalog?> readCatalog() async {
    if (!_ready) return null;
    try {
      final client = SupabaseService.instance.client;
      final examsRaw = await client
          .from('exam_bank_exams')
          .select('sdash_id, name, slug')
          .order('name');
      final subjectsRaw = await client
          .from('exam_bank_subjects')
          .select('sdash_id, name, slug')
          .order('name');
      final yearsRaw = await client
          .from('exam_bank_years')
          .select('year')
          .order('year', ascending: false);
      final exams = [
        for (final item in examsRaw)
          PastExamType.fromJson({
            'id': item['sdash_id'],
            'name': item['name'],
            'slug': item['slug'],
          }),
      ];
      if (exams.isEmpty) return null;
      return PastQuestionsCatalog(
        exams: exams,
        subjects: [
          for (final item in subjectsRaw)
            PastSubject.fromJson({
              'id': item['sdash_id'],
              'name': item['name'],
              'slug': item['slug'],
            }),
        ],
        years: [
          for (final item in yearsRaw) (item['year'] as num).toInt(),
        ],
      );
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'exam_bank.readCatalog',
      );
      return null;
    }
  }

  Future<void> saveCatalog(PastQuestionsCatalog catalog) async {
    if (!_ready || catalog.exams.isEmpty) return;
    try {
      await SupabaseService.instance.client.rpc(
        'exam_bank_replace_catalog',
        params: {
          'p_exams': [for (final exam in catalog.exams) exam.toJson()],
          'p_subjects': [
            for (final subject in catalog.subjects) subject.toJson(),
          ],
          'p_years': [for (final year in catalog.years) year.toString()],
        },
      );
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'exam_bank.saveCatalog',
      );
    }
  }

  Future<int?> pickYear({
    required String examSlug,
    required String subjectSlug,
    int? year,
    String? university,
  }) async {
    if (!_ready) return year;
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'exam_bank_pick_paper',
        params: {
          'p_exam_slug': examSlug,
          'p_subject_slug': subjectSlug,
          'p_year': year,
          'p_university': university,
        },
      );
      if (raw is Map && raw['year'] != null) {
        return (raw['year'] as num).toInt();
      }
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'exam_bank.pickYear',
      );
    }
    return year;
  }

  Future<List<PastQuestion>> draw({
    required String examSlug,
    required String subjectSlug,
    required int limit,
    int? year,
    String? university,
  }) async {
    if (!_ready) return const [];
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'exam_bank_draw',
        params: {
          'p_exam_slug': examSlug,
          'p_subject_slug': subjectSlug,
          'p_limit': limit.clamp(1, 50),
          'p_year': year?.toString(),
          'p_university': university,
        },
      );
      return _questionsFrom(raw);
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'exam_bank.draw',
      );
      return const [];
    }
  }

  Future<int> upsert(
    List<PastQuestion> questions, {
    required String examSlug,
    required String subjectSlug,
  }) async {
    if (!_ready || questions.isEmpty) return 0;
    try {
      final raw = await SupabaseService.instance.client.rpc(
        'exam_bank_upsert',
        params: {
          'p_rows': [
            for (final question in questions)
              {
                ...question.toJson(),
                'exam_slug': examSlug,
                'subject_slug': subjectSlug,
              },
          ],
        },
      );
      return (raw as num?)?.toInt() ?? 0;
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'exam_bank.upsert',
      );
      return 0;
    }
  }

  Future<ExamBankStatus?> status() async {
    if (!_ready) return null;
    try {
      final raw = await SupabaseService.instance.client.rpc('exam_bank_status');
      if (raw is Map) {
        return ExamBankStatus.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'exam_bank.status',
      );
      return null;
    }
  }

  Future<ExamBankHarvestResult> harvest({int rounds = 8}) async {
    if (!_ready) {
      return const ExamBankHarvestResult(
        added: 0,
        questions: 0,
        done: true,
        message: 'Sign in to fill the exam bank.',
      );
    }
    try {
      final response = await SupabaseService.instance.client.functions.invoke(
        'exam-bank',
        body: {'action': 'harvest', 'rounds': rounds},
      );
      final data = response.data;
      if (response.status >= 400 || data is! Map) {
        final error = data is Map ? data['error']?.toString() : null;
        return ExamBankHarvestResult(
          added: 0,
          questions: 0,
          done: true,
          message: error ?? 'Could not fill the exam bank.',
        );
      }
      return ExamBankHarvestResult(
        added: (data['added'] as num?)?.toInt() ?? 0,
        questions: (data['questions'] as num?)?.toInt() ?? 0,
        done: data['done'] == true,
        message: data['message']?.toString(),
      );
    } catch (error, stack) {
      await app_errors.ErrorHandler.reportError(
        error,
        stack,
        context: 'exam_bank.harvest',
      );
      return const ExamBankHarvestResult(
        added: 0,
        questions: 0,
        done: true,
        message: 'Could not fill the exam bank.',
      );
    }
  }

  List<PastQuestion> _questionsFrom(Object? raw) {
    Object? value = raw;
    if (value is String) {
      value = jsonDecode(value);
    }
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map)
          PastQuestion.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
