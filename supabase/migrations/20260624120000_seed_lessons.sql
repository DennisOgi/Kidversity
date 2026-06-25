-- Seed catalog lessons (published so anon/authenticated users can browse)

INSERT INTO lessons (
  id, title, subject, description, source, status, author_name,
  color, emoji, grade_band_label, xp_reward, estimated_minutes, slides, checkpoints
) VALUES
(
  'a1000001-0001-4001-8001-000000000001',
  'Family Words in Mandarin',
  'Mandarin',
  'Learn to say mum, dad, sister and more with native-style audio.',
  'uploaded',
  'published',
  'Mrs. Ade',
  '#FF7A59',
  '👨‍👩‍👧',
  4,
  150,
  10,
  '[{"id":"s1","title":"妈妈 — māma","body":"This means \"mum\". Listen and repeat the rising-falling tones.","image_emoji":"👩","caption":"māma means mum. Tap play and repeat after me.","audio_duration_ms":16000,"speech_text":"妈妈。māma。","speech_lang":"zh-CN"},{"id":"s2","title":"爸爸 — bàba","body":"This means \"dad\". Notice the falling tone on the first syllable.","image_emoji":"👨","caption":"bàba means dad.","audio_duration_ms":15000,"speech_text":"爸爸。bàba。","speech_lang":"zh-CN"},{"id":"s3","title":"姐姐 — jiějie","body":"This means \"older sister\".","image_emoji":"👧","caption":"jiějie means older sister.","audio_duration_ms":14000,"ai_voice":true,"speech_text":"姐姐。jiějie。","speech_lang":"zh-CN"}]'::jsonb,
  '[{"id":"c1","type":"pronunciation","prompt":"Hear \"māma\" — tap the correct character","audio_prompt":"妈妈","audio_lang":"zh-CN","options":[{"id":"o1","label":"妈妈","is_correct":true},{"id":"o2","label":"爸爸"},{"id":"o3","label":"姐姐"}]},{"id":"c2","type":"multipleChoice","prompt":"What does \"bàba\" mean?","hint":"Think of the deeper voice in the family!","options":[{"id":"o1","label":"Mum"},{"id":"o2","label":"Dad","is_correct":true},{"id":"o3","label":"Sister"},{"id":"o4","label":"Brother"}]}]'::jsonb
),
(
  'a1000001-0002-4001-8001-000000000002',
  'Numbers 1–10 in Mandarin',
  'Mandarin',
  'AI-generated beginner lesson with characters, pinyin and a quiz.',
  'ai_generated',
  'published',
  'Mr. Ibrahim',
  '#6C5CE7',
  '🔢',
  3,
  120,
  8,
  '[{"id":"s1","title":"一 — yī (one)","body":"A single horizontal stroke.","image_emoji":"1️⃣","caption":"yī means one.","ai_voice":true,"speech_text":"一。yī。","speech_lang":"zh-CN"},{"id":"s2","title":"二 — èr (two)","body":"Two strokes stacked.","image_emoji":"2️⃣","caption":"èr means two.","ai_voice":true,"speech_text":"二。èr。","speech_lang":"zh-CN"},{"id":"s3","title":"三 — sān (three)","body":"Three horizontal strokes.","image_emoji":"3️⃣","caption":"sān means three.","ai_voice":true,"speech_text":"三。sān。","speech_lang":"zh-CN"}]'::jsonb,
  '[{"id":"c1","type":"multipleChoice","prompt":"Which character means \"three\"?","options":[{"id":"o1","label":"一"},{"id":"o2","label":"三","is_correct":true},{"id":"o3","label":"二"}]}]'::jsonb
),
(
  'a1000001-0003-4001-8001-000000000003',
  'Introduction to Fractions',
  'Maths',
  'Halves, thirds and quarters explained with pizza slices.',
  'hybrid',
  'published',
  'AI + Mr. Okoro',
  '#00CEC9',
  '🍕',
  5,
  140,
  12,
  '[{"id":"s1","title":"What is a fraction?","body":"A part of a whole.","image_emoji":"🍕"},{"id":"s2","title":"One half","body":"1/2 means one of two equal parts.","image_emoji":"🌗"}]'::jsonb,
  '[{"id":"c1","type":"multipleChoice","prompt":"If you eat 2 of 4 equal slices, what fraction did you eat?","options":[{"id":"o1","label":"1/2","is_correct":true},{"id":"o2","label":"1/4"},{"id":"o3","label":"3/4"}]}]'::jsonb
),
(
  'a1000001-0004-4001-8001-000000000004',
  'Our Solar System',
  'Science',
  'A tour of the eight planets with fun facts and narration.',
  'ai_generated',
  'published',
  'AI Studio',
  '#0284C7',
  '🪐',
  6,
  160,
  15,
  '[{"id":"s1","title":"The Sun","body":"A giant ball of hot plasma.","image_emoji":"☀️","ai_voice":true},{"id":"s2","title":"Earth","body":"The only planet with known life.","image_emoji":"🌍","ai_voice":true}]'::jsonb,
  '[]'::jsonb
),
(
  'a1000001-0005-4001-8001-000000000005',
  'Phonics: The Letter S',
  'Reading',
  'Sound it out — \"sss\" like a snake. Great for early readers.',
  'uploaded',
  'published',
  'Mrs. Bello',
  '#FF6B9D',
  '🐍',
  1,
  100,
  8,
  '[{"id":"s1","title":"S says sss","body":"Like a snake!","image_emoji":"🐍"}]'::jsonb,
  '[]'::jsonb
)
ON CONFLICT (id) DO NOTHING;
