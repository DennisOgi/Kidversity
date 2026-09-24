import 'package:shared_preferences/shared_preferences.dart';

import '../../models/past_questions_models.dart';

class ExamTopic {
  final String id;
  final String title;
  final String detail;
  final List<String> keywords;

  const ExamTopic(this.id, this.title, this.detail, this.keywords);
}

const examTopicSubjects = ['biology', 'chemistry', 'physics', 'government'];

const int examTopicSize = 8;
const int examTopicMinimum = 4;

const examTopicsBySubject = <String, List<ExamTopic>>{
  'biology': [
    ExamTopic(
      'ecology',
      'Ecology',
      'Succession, populations, and ecosystems.',
      [
        'succession',
        'ecosystem',
        'population',
        'habitat',
        'food chain',
        'food web',
        'niche',
        'biosphere',
      ],
    ),
    ExamTopic('cells', 'Cell biology', 'Cells, membranes, and organelles.', [
      'mitochond',
      'nucleus',
      'osmosis',
      'diffusion',
      'organelle',
      'cell membrane',
      'cytoplasm',
    ]),
    ExamTopic('genetics', 'Genetics', 'DNA, genes, and inheritance.', [
      'chromosome',
      'allele',
      'genotype',
      'phenotype',
      'heredity',
      'mutation',
      ' dna',
    ]),
    ExamTopic(
      'reproduction',
      'Reproduction',
      'Gametes, flowers, and human reproduction.',
      [
        'gamete',
        'pollination',
        'menstrual',
        'fertili',
        'ovary',
        'testis',
        'ovule',
      ],
    ),
    ExamTopic(
      'nutrition',
      'Nutrition',
      'Enzymes, digestion, and photosynthesis.',
      [
        'enzyme',
        'photosynthesis',
        'digestion',
        'vitamin',
        'nutrient',
        'chlorophyll',
      ],
    ),
    ExamTopic('transport', 'Transport', 'Blood, heart, xylem, and phloem.', [
      'xylem',
      'phloem',
      'transpiration',
      'circulatory',
      'haemoglobin',
      'capillar',
    ]),
  ],
  'chemistry': [
    ExamTopic(
      'atoms',
      'Atomic structure',
      'Particles, isotopes, and electron shells.',
      ['isotope', 'electron', 'proton', 'neutron', 'atomic number', 'orbital'],
    ),
    ExamTopic(
      'periodic',
      'Periodic table',
      'Groups, periods, and element families.',
      ['periodic', 'halogen', 'alkali metal', 'noble gas', 'group 1', 'period'],
    ),
    ExamTopic('bonding', 'Bonding', 'Ionic, covalent, and metallic bonds.', [
      'covalent',
      'ionic',
      'metallic bond',
      'electrovalent',
      'molecule',
    ]),
    ExamTopic(
      'acids',
      'Acids, bases, and salts',
      'pH, neutralisation, and salts.',
      ['neutralis', 'alkali', 'acid', ' ph', 'salt'],
    ),
    ExamTopic(
      'organic',
      'Organic chemistry',
      'Hydrocarbons and simple organic families.',
      ['alkane', 'alkene', 'hydrocarbon', 'ethanol', 'ester', 'organic'],
    ),
    ExamTopic('moles', 'The mole', 'Moles, molar mass, and formulae.', [
      'mole',
      'molar',
      'stoichiometr',
      'empirical',
      'avogadro',
    ]),
  ],
  'physics': [
    ExamTopic(
      'mechanics',
      'Motion and force',
      'Speed, acceleration, and Newton’s laws.',
      ['acceleration', 'velocity', 'momentum', 'newton', 'force'],
    ),
    ExamTopic(
      'energy',
      'Work and energy',
      'Work, power, and forms of energy.',
      ['kinetic energy', 'potential energy', 'work done', ' joule', 'power'],
    ),
    ExamTopic('waves', 'Waves', 'Frequency, wavelength, and sound.', [
      'wavelength',
      'frequency',
      'amplitude',
      'sound',
      'wave',
    ]),
    ExamTopic(
      'electricity',
      'Electricity',
      'Current, voltage, and resistance.',
      ['resistance', 'voltage', 'current', 'ohm', 'circuit'],
    ),
    ExamTopic('heat', 'Heat', 'Temperature, specific heat, and expansion.', [
      'specific heat',
      'latent heat',
      'thermometer',
      'temperature',
      'heat',
    ]),
    ExamTopic('optics', 'Light', 'Mirrors, lenses, and refraction.', [
      'refraction',
      'reflection',
      'focal',
      'lens',
      'mirror',
    ]),
  ],
  'government': [
    ExamTopic(
      'constitution',
      'Constitution',
      'Federalism and the constitution.',
      ['constitution', 'federalism', 'separation of power', 'unitary'],
    ),
    ExamTopic(
      'legislature',
      'Legislature',
      'Law-making, bills, and the assembly.',
      ['legislature', 'parliament', 'senate', 'bill'],
    ),
    ExamTopic(
      'executive',
      'Executive',
      'President, cabinet, and administration.',
      ['president', 'cabinet', 'executive'],
    ),
    ExamTopic('judiciary', 'Judiciary', 'Courts and the rule of law.', [
      'judiciary',
      'rule of law',
      'judicial',
      'court',
    ]),
    ExamTopic('elections', 'Elections', 'Parties, voting, and the franchise.', [
      'franchise',
      'suffrage',
      'political party',
      'election',
      'voting',
    ]),
    ExamTopic('citizenship', 'Citizenship', 'Rights, duties, and the state.', [
      'citizenship',
      'fundamental right',
      'duty',
      'nationalism',
    ]),
  ],
};

List<ExamTopic> topicsForSubject(String? slug) {
  if (slug == null) return const [];
  return examTopicsBySubject[slug] ?? const [];
}

ExamTopic? examTopicById(String? subjectSlug, String? topicId) {
  if (topicId == null) return null;
  for (final topic in topicsForSubject(subjectSlug)) {
    if (topic.id == topicId) return topic;
  }
  return null;
}

bool topicCleared(int correct, int total) =>
    total > 0 && correct * 4 >= total * 3;

String _haystack(PastQuestion question) {
  final options = question.options.map((option) => option.text).join(' ');
  return ' ${question.question} ${question.section ?? ''} $options '
      .toLowerCase();
}

bool _matches(PastQuestion question, ExamTopic topic) {
  final haystack = _haystack(question);
  return topic.keywords.any(haystack.contains);
}

ExamTopic? topicForQuestion(String subjectSlug, PastQuestion question) {
  if (question.answerKey.isEmpty || question.options.length < 2) return null;
  for (final topic in topicsForSubject(subjectSlug)) {
    if (_matches(question, topic)) return topic;
  }
  return null;
}

/// Up to [examTopicSize] checked questions for one topic.
/// Questions that also match an earlier topic stay with that earlier topic.
/// Questions with a worked solution are kept first.
List<PastQuestion> questionsForTopic(
  String subjectSlug,
  ExamTopic topic,
  List<PastQuestion> questions, {
  int limit = examTopicSize,
}) {
  final matched = <PastQuestion>[];
  for (final question in questions) {
    if (topicForQuestion(subjectSlug, question)?.id != topic.id) continue;
    matched.add(question);
  }
  matched.sort((a, b) {
    final aSolved = (a.solution ?? '').trim().isNotEmpty;
    final bSolved = (b.solution ?? '').trim().isNotEmpty;
    if (aSolved == bSolved) return 0;
    return aSolved ? -1 : 1;
  });
  if (matched.length <= limit) return matched;
  return matched.sublist(0, limit);
}

class ExamTopicProgress {
  static const prefsKey = 'kidversity_exam_topics';

  static String idFor({
    required String examSlug,
    required String subjectSlug,
    required String topicId,
  }) => '$examSlug|$subjectSlug|$topicId';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(prefsKey) ?? const <String>[]).toSet();
  }

  static Future<void> mark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final next = {...?prefs.getStringList(prefsKey), id}.toList();
    await prefs.setStringList(prefsKey, next);
  }
}
