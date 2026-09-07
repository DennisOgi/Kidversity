-- Kidversity Plan B production baseline 4/5.
-- Deterministic first-party Foundation lessons 1-3.
-- Lessons remain in review until Google audio is generated and reviewed.

INSERT INTO public.content_sources(
  id, source_name, url, licence, dataset_version
)
VALUES (
  'f1000000-0000-4000-8000-000000000001',
  'Kidversity Foundation V1 first-party pack',
  NULL,
  'All rights reserved — original Kidversity content',
  '1.0'
)
ON CONFLICT (id) DO UPDATE
SET source_name = EXCLUDED.source_name,
    url = EXCLUDED.url,
    licence = EXCLUDED.licence,
    dataset_version = EXCLUDED.dataset_version;

INSERT INTO public.courses(id, title, level, target_age)
VALUES (
  'mandarin_foundation_v1',
  'Mandarin Foundation',
  'Complete beginner',
  '7–12'
)
ON CONFLICT (id) DO UPDATE
SET title = EXCLUDED.title,
    level = EXCLUDED.level,
    target_age = EXCLUDED.target_age;

INSERT INTO public.course_modules(
  id, course_id, sequence, title, subtitle
)
VALUES
  (
    'f2000000-0000-4000-8000-000000000001',
    'mandarin_foundation_v1', 1, 'First Contact',
    'Hear Mandarin, understand tones, and say hello.'
  ),
  (
    'f2000000-0000-4000-8000-000000000002',
    'mandarin_foundation_v1', 2, 'My World',
    'Talk about yourself and the world around you.'
  ),
  (
    'f2000000-0000-4000-8000-000000000003',
    'mandarin_foundation_v1', 3, 'Everyday Mandarin',
    'Use Mandarin in everyday situations.'
  )
ON CONFLICT (course_id, sequence) DO UPDATE
SET title = EXCLUDED.title,
    subtitle = EXCLUDED.subtitle;

INSERT INTO public.course_lessons(
  id, course_id, module_sequence, sequence, title, objective,
  explanation, status, xp_reward, metadata_review_status, submitted_at
)
VALUES
  (
    'mfv1_l01', 'mandarin_foundation_v1', 1, 1,
    'Welcome to Mandarin',
    'Recognise Mandarin and use a first greeting.',
    'Chinese characters show meaning. Pinyin helps us learn how Mandarin sounds.',
    'in_review', 100, 'approved', NOW()
  ),
  (
    'mfv1_l02', 'mandarin_foundation_v1', 1, 2,
    'Understanding the Four Tones',
    'Hear and identify Mandarin’s four main tones.',
    'A tone is the shape your voice makes. Mandarin has level, rising, dipping, and falling tones.',
    'in_review', 100, 'approved', NOW()
  ),
  (
    'mfv1_l03', 'mandarin_foundation_v1', 1, 3,
    'Hello!',
    'Greet a friend or teacher and say goodbye.',
    'Use 你好 with most people, 您好 as a respectful hello, and 老师好 for a teacher.',
    'in_review', 120, 'approved', NOW()
  )
ON CONFLICT (id) DO UPDATE
SET course_id = EXCLUDED.course_id,
    module_sequence = EXCLUDED.module_sequence,
    sequence = EXCLUDED.sequence,
    title = EXCLUDED.title,
    objective = EXCLUDED.objective,
    explanation = EXCLUDED.explanation,
    xp_reward = EXCLUDED.xp_reward,
    metadata_review_status = EXCLUDED.metadata_review_status,
    status = CASE
      WHEN course_lessons.status = 'approved' THEN course_lessons.status
      ELSE EXCLUDED.status
    END,
    submitted_at = COALESCE(course_lessons.submitted_at, EXCLUDED.submitted_at);

INSERT INTO public.vocab_items(
  id, lesson_id, simplified_chinese, pinyin, english_meaning,
  part_of_speech, source_id, review_status, sequence
)
VALUES
  ('l1v1','mfv1_l01','你好','nǐ hǎo','hello','greeting','f1000000-0000-4000-8000-000000000001','approved',1),
  ('l1v2','mfv1_l01','中文','Zhōngwén','Chinese language','noun','f1000000-0000-4000-8000-000000000001','approved',2),
  ('l1v3','mfv1_l01','听','tīng','listen','verb','f1000000-0000-4000-8000-000000000001','approved',3),
  ('l1v4','mfv1_l01','说','shuō','speak','verb','f1000000-0000-4000-8000-000000000001','approved',4),
  ('l1v5','mfv1_l01','我','wǒ','I / me','pronoun','f1000000-0000-4000-8000-000000000001','approved',5),
  ('l2v1','mfv1_l02','妈','mā','mum — first tone','','f1000000-0000-4000-8000-000000000001','approved',1),
  ('l2v2','mfv1_l02','麻','má','hemp — second tone','','f1000000-0000-4000-8000-000000000001','approved',2),
  ('l2v3','mfv1_l02','马','mǎ','horse — third tone','','f1000000-0000-4000-8000-000000000001','approved',3),
  ('l2v4','mfv1_l02','骂','mà','scold — fourth tone','','f1000000-0000-4000-8000-000000000001','approved',4),
  ('l3v1','mfv1_l03','你好','nǐ hǎo','hello','greeting','f1000000-0000-4000-8000-000000000001','approved',1),
  ('l3v2','mfv1_l03','您好','nín hǎo','hello (respectful)','greeting','f1000000-0000-4000-8000-000000000001','approved',2),
  ('l3v3','mfv1_l03','老师好','lǎoshī hǎo','hello, teacher','greeting','f1000000-0000-4000-8000-000000000001','approved',3),
  ('l3v4','mfv1_l03','再见','zàijiàn','goodbye','greeting','f1000000-0000-4000-8000-000000000001','approved',4)
ON CONFLICT (id) DO UPDATE
SET simplified_chinese = EXCLUDED.simplified_chinese,
    pinyin = EXCLUDED.pinyin,
    english_meaning = EXCLUDED.english_meaning,
    part_of_speech = EXCLUDED.part_of_speech,
    source_id = EXCLUDED.source_id,
    review_status = EXCLUDED.review_status,
    sequence = EXCLUDED.sequence;

INSERT INTO public.dialogues(
  id, lesson_id, speaker, chinese, pinyin, english,
  source_id, review_status, sequence
)
VALUES
  ('l3d1','mfv1_l03','Mei','老师好！','Lǎoshī hǎo!','Hello, teacher!','f1000000-0000-4000-8000-000000000001','approved',1),
  ('l3d2','mfv1_l03','Teacher','你好！','Nǐ hǎo!','Hello!','f1000000-0000-4000-8000-000000000001','approved',2),
  ('l3d3','mfv1_l03','Mei','再见！','Zàijiàn!','Goodbye!','f1000000-0000-4000-8000-000000000001','approved',3)
ON CONFLICT (id) DO UPDATE
SET speaker = EXCLUDED.speaker,
    chinese = EXCLUDED.chinese,
    pinyin = EXCLUDED.pinyin,
    english = EXCLUDED.english,
    source_id = EXCLUDED.source_id,
    review_status = EXCLUDED.review_status,
    sequence = EXCLUDED.sequence;

INSERT INTO public.activities(
  id, lesson_id, type, prompt, answer, distractors, explanation,
  difficulty, source_id, review_status, sequence
)
VALUES
  ('l1a1','mfv1_l01','listen_tap','Listen and tap “hello”.','你好','["中文","听"]','你好 means hello.',1,'f1000000-0000-4000-8000-000000000001','approved',1),
  ('l1a2','mfv1_l01','match','Match the action to its meaning.','听 = listen','["说 = listen","中文 = speak"]','听 means listen; 说 means speak.',1,'f1000000-0000-4000-8000-000000000001','approved',2),
  ('l2a1','mfv1_l02','listen_tap','Listen for the falling fourth tone.','mà','["mā","má","mǎ"]','The fourth tone falls sharply.',1,'f1000000-0000-4000-8000-000000000001','approved',1),
  ('l2a2','mfv1_l02','match','Match the tone shape.','mǎ = dip','["mǎ = level","mǎ = falling"]','The third tone dips.',1,'f1000000-0000-4000-8000-000000000001','approved',2),
  ('l3a1','mfv1_l03','listen_tap','Choose the respectful greeting.','您好','["你好","再见"]','您好 is respectful.',1,'f1000000-0000-4000-8000-000000000001','approved',1),
  ('l3a2','mfv1_l03','fill_blank','老师___','好','["见","您"]','老师好 means hello, teacher.',1,'f1000000-0000-4000-8000-000000000001','approved',2)
ON CONFLICT (id) DO UPDATE
SET type = EXCLUDED.type,
    prompt = EXCLUDED.prompt,
    answer = EXCLUDED.answer,
    distractors = EXCLUDED.distractors,
    explanation = EXCLUDED.explanation,
    difficulty = EXCLUDED.difficulty,
    source_id = EXCLUDED.source_id,
    review_status = EXCLUDED.review_status,
    sequence = EXCLUDED.sequence;

INSERT INTO public.assessment_items(
  id, lesson_id, question, type, correct_answer, distractors,
  explanation, source_id, review_status, sequence
)
VALUES
  ('l1q1','mfv1_l01','Which word means “hello”?','mcq','你好','["中文","我"]','你好 means hello.','f1000000-0000-4000-8000-000000000001','approved',1),
  ('l1q2','mfv1_l01','What does 中文 mean?','mcq','Chinese language','["listen","hello"]','中文 is the Chinese language.','f1000000-0000-4000-8000-000000000001','approved',2),
  ('l1q3','mfv1_l01','Tap the word for “listen”.','listen_tap','听','["说","我"]','听 means listen.','f1000000-0000-4000-8000-000000000001','approved',3),
  ('l1q4','mfv1_l01','Which word means “speak”?','mcq','说','["听","中文"]','说 means speak.','f1000000-0000-4000-8000-000000000001','approved',4),
  ('l1q5','mfv1_l01','Complete: nǐ hǎo = ____','fill_blank','hello','["goodbye","thank you"]','nǐ hǎo is hello.','f1000000-0000-4000-8000-000000000001','approved',5),
  ('l2q1','mfv1_l02','Which Pinyin has the level first tone?','mcq','mā','["má","mǎ","mà"]','The macron shows a level tone.','f1000000-0000-4000-8000-000000000001','approved',1),
  ('l2q2','mfv1_l02','Which tone rises?','mcq','má','["mā","mǎ","mà"]','The acute mark rises.','f1000000-0000-4000-8000-000000000001','approved',2),
  ('l2q3','mfv1_l02','Which tone dips?','mcq','mǎ','["mā","má","mà"]','The caron marks the dip.','f1000000-0000-4000-8000-000000000001','approved',3),
  ('l2q4','mfv1_l02','Which tone falls sharply?','mcq','mà','["mā","má","mǎ"]','The grave mark falls.','f1000000-0000-4000-8000-000000000001','approved',4),
  ('l2q5','mfv1_l02','Why do tones matter?','mcq','They can change meaning','["They change the alphabet","They are decoration"]','Tone can change meaning.','f1000000-0000-4000-8000-000000000001','approved',5),
  ('l3q1','mfv1_l03','How do you say hello?','mcq','你好','["再见","中文"]','你好 means hello.','f1000000-0000-4000-8000-000000000001','approved',1),
  ('l3q2','mfv1_l03','Which greeting is respectful?','mcq','您好','["你好","再见"]','您好 uses respectful 您.','f1000000-0000-4000-8000-000000000001','approved',2),
  ('l3q3','mfv1_l03','How do you greet a teacher?','mcq','老师好','["老师见","您好见"]','老师好 means hello, teacher.','f1000000-0000-4000-8000-000000000001','approved',3),
  ('l3q4','mfv1_l03','What does 再见 mean?','mcq','goodbye','["hello","teacher"]','再见 means goodbye.','f1000000-0000-4000-8000-000000000001','approved',4),
  ('l3q5','mfv1_l03','Complete: zàijiàn = ____','fill_blank','goodbye','["hello","please"]','zàijiàn is goodbye.','f1000000-0000-4000-8000-000000000001','approved',5)
ON CONFLICT (id) DO UPDATE
SET question = EXCLUDED.question,
    type = EXCLUDED.type,
    correct_answer = EXCLUDED.correct_answer,
    distractors = EXCLUDED.distractors,
    explanation = EXCLUDED.explanation,
    source_id = EXCLUDED.source_id,
    review_status = EXCLUDED.review_status,
    sequence = EXCLUDED.sequence;

INSERT INTO public.curriculum_constraints(
  id, course_id, tag, description, language_function,
  source_id, verification_status
)
VALUES
  ('f3000000-0000-4000-8000-000000000001','mandarin_foundation_v1','beginner-reviewed','Only reviewer-approved beginner Mandarin may reach learners.','Quality gate for beginner language','f1000000-0000-4000-8000-000000000001','verified'),
  ('f3000000-0000-4000-8000-000000000002','mandarin_foundation_v1','no-new-chinese','Generation may not introduce Chinese outside the approved lesson pack.','Constrained generation','f1000000-0000-4000-8000-000000000001','verified'),
  ('f3000000-0000-4000-8000-000000000003','mandarin_foundation_v1','pinyin-preserved','Generation must preserve supplied characters and Pinyin exactly.','Orthographic fidelity','f1000000-0000-4000-8000-000000000001','verified')
ON CONFLICT (course_id, tag) DO UPDATE
SET description = EXCLUDED.description,
    language_function = EXCLUDED.language_function,
    source_id = EXCLUDED.source_id,
    verification_status = EXCLUDED.verification_status;

INSERT INTO public.audio_clips(
  id, lesson_id, item_type, item_id, audio_text, speech_lang,
  audio_url, storage_path, voice, provider, text_hash, generated_at,
  source_id, review_status
)
SELECT
  (
    'f4' || lpad(row_number() OVER (ORDER BY item_type, item_id)::text, 6, '0')
    || '-0000-4000-8000-000000000001'
  )::uuid,
  lesson_id,
  item_type,
  item_id,
  audio_text,
  'zh-CN',
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  'f1000000-0000-4000-8000-000000000001',
  'pending'
FROM (
  SELECT lesson_id, 'vocab'::text AS item_type, id AS item_id,
         simplified_chinese AS audio_text
  FROM public.vocab_items
  WHERE lesson_id IN ('mfv1_l01', 'mfv1_l02', 'mfv1_l03')
  UNION ALL
  SELECT lesson_id, 'dialogue', id, chinese
  FROM public.dialogues
  WHERE lesson_id IN ('mfv1_l01', 'mfv1_l02', 'mfv1_l03')
) required_audio
ON CONFLICT (lesson_id, item_type, item_id) DO UPDATE
SET audio_text = EXCLUDED.audio_text,
    source_id = EXCLUDED.source_id;
