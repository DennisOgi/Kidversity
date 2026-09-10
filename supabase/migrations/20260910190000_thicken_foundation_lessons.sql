-- Thicken Foundation V1 in place: extra dialogue, examples, recycle practice,
-- and longer module quests. Same 30 lessons. First-party source only.

UPDATE public.vocab_items
SET english_meaning = 'not'
WHERE id IN (
  SELECT id FROM public.vocab_items
  WHERE lesson_id = 'mfv1_l06' AND simplified_chinese = '不' AND english_meaning = 'pending'
);

-- Extra dialogue turns (sequence 3+) so conversations are 4 lines where they were 2.
INSERT INTO public.dialogues (
  id, lesson_id, speaker, chinese, pinyin, english, source_id, review_status, sequence
)
SELECT v.id, v.lesson_id, v.speaker, v.chinese, v.pinyin, v.english,
       'f1000000-0000-4000-8000-000000000001'::uuid, 'approved', v.sequence
FROM (VALUES
  ('l04d3','mfv1_l04',3,'Ming','你好！','Nǐ hǎo!','Hello!'),
  ('l04d4','mfv1_l04',4,'Lele','你好！我叫乐乐。','Nǐ hǎo! Wǒ jiào Lèlè.','Hello! My name is Lele.'),
  ('l05d3','mfv1_l05',3,'Anan','我是同学。','Wǒ shì tóngxué.','I am a classmate.'),
  ('l05d4','mfv1_l05',4,'Ming','很高兴！','Hěn gāoxìng!','Glad to meet you!'),
  ('l06d3','mfv1_l06',3,'Teacher','对吗？','Duì ma?','Is that right?'),
  ('l06d4','mfv1_l06',4,'Lele','对。','Duì.','Yes, that is right.'),
  ('l07d3','mfv1_l07',3,'Kai','一、二。','Yī, èr.','One, two.'),
  ('l07d4','mfv1_l07',4,'Mei','三、四、五！','Sān, sì, wǔ!','Three, four, five!'),
  ('l08d3','mfv1_l08',3,'Mei','六、七、八。','Liù, qī, bā.','Six, seven, eight.'),
  ('l08d4','mfv1_l08',4,'Kai','九、十！','Jiǔ, shí!','Nine, ten!'),
  ('l09d3','mfv1_l09',3,'Mei','我八岁。你呢？','Wǒ bā suì. Nǐ ne?','I am eight. And you?'),
  ('l09d4','mfv1_l09',4,'Kai','我也八岁。','Wǒ yě bā suì.','I am eight too.'),
  ('l11d3','mfv1_l11',3,'Mei','这是我妈妈。','Zhè shì wǒ māma.','This is my mum.'),
  ('l11d4','mfv1_l11',4,'Kai','你好！','Nǐ hǎo!','Hello!'),
  ('l12d3','mfv1_l12',3,'Kai','这是我的朋友。','Zhè shì wǒ de péngyou.','This is my friend.'),
  ('l12d4','mfv1_l12',4,'Mei','你好！','Nǐ hǎo!','Hello!'),
  ('l13d3','mfv1_l13',3,'Teacher','你是学生。','Nǐ shì xuésheng.','You are a student.'),
  ('l13d4','mfv1_l13',4,'Kai','我是学生。老师好！','Wǒ shì xuésheng. Lǎoshī hǎo!','I am a student. Hello, teacher!'),
  ('l14d3','mfv1_l14',3,'Mei','那是桌子。','Nà shì zhuōzi.','That is a desk.'),
  ('l14d4','mfv1_l14',4,'Kai','这是椅子。','Zhè shì yǐzi.','This is a chair.'),
  ('l15d3','mfv1_l15',3,'Kai','我喜欢蓝色。','Wǒ xǐhuan lánsè.','I like blue.'),
  ('l15d4','mfv1_l15',4,'Mei','我喜欢红色。','Wǒ xǐhuan hóngsè.','I like red.'),
  ('l16d3','mfv1_l16',3,'Mei','那是什么？','Nà shì shénme?','What is that?'),
  ('l16d4','mfv1_l16',4,'Kai','那是东西。是书包。','Nà shì dōngxi. Shì shūbāo.','That is a thing. It is a school bag.'),
  ('l17d3','mfv1_l17',3,'Kai','你吃什么？','Nǐ chī shénme?','What do you eat?'),
  ('l17d4','mfv1_l17',4,'Mei','我吃米饭。','Wǒ chī mǐfàn.','I eat rice.'),
  ('l18d3','mfv1_l18',3,'Mei','我喜欢看书。','Wǒ xǐhuan kàn shū.','I like reading.'),
  ('l18d4','mfv1_l18',4,'Kai','我也喜欢看书。','Wǒ yě xǐhuan kàn shū.','I like reading too.'),
  ('l19d3','mfv1_l19',3,'Kai','你喜欢面条吗？','Nǐ xǐhuan miàntiáo ma?','Do you like noodles?'),
  ('l19d4','mfv1_l19',4,'Mei','喜欢。','Xǐhuan.','Yes, I like them.'),
  ('l21d3','mfv1_l21',3,'Teacher','下午好！','Xiàwǔ hǎo!','Good afternoon!'),
  ('l21d4','mfv1_l21',4,'Mei','老师，再见！','Lǎoshī, zàijiàn!','Goodbye, teacher!'),
  ('l22d3','mfv1_l22',3,'Kai','今天呢？','Jīntiān ne?','What about today?'),
  ('l22d4','mfv1_l22',4,'Mei','今天好。明天见！','Jīntiān hǎo. Míngtiān jiàn!','Today is good. See you tomorrow!'),
  ('l23d3','mfv1_l23',3,'Mei','明天星期一。','Míngtiān xīngqīyī.','Tomorrow is Monday.'),
  ('l23d4','mfv1_l23',4,'Kai','今天星期三。','Jīntiān xīngqīsān.','Today is Wednesday.'),
  ('l24d3','mfv1_l24',3,'Mei','我去学校。你呢？','Wǒ qù xuéxiào. Nǐ ne?','I am going to school. And you?'),
  ('l24d4','mfv1_l24',4,'Kai','我也去学校。','Wǒ yě qù xuéxiào.','I am going to school too.'),
  ('l25d3','mfv1_l25',3,'Kai','我去公园。','Wǒ qù gōngyuán.','I am going to the park.'),
  ('l25d4','mfv1_l25',4,'Mei','我去商店。','Wǒ qù shāngdiàn.','I am going to the shop.'),
  ('l26d3','mfv1_l26',3,'Mum','喝水。','Hē shuǐ.','Drink water.'),
  ('l26d4','mfv1_l26',4,'Kai','好，我喝水。','Hǎo, wǒ hē shuǐ.','OK, I will drink water.'),
  ('l27d3','mfv1_l27',3,'Teacher','你会写中文吗？','Nǐ huì xiě Zhōngwén ma?','Can you write Chinese?'),
  ('l27d4','mfv1_l27',4,'Mei','不会。我会说。','Bú huì. Wǒ huì shuō.','No. I can speak it.')
) AS v(id, lesson_id, sequence, speaker, chinese, pinyin, english)
WHERE NOT EXISTS (SELECT 1 FROM public.dialogues d WHERE d.id = v.id);

INSERT INTO public.examples (
  id, lesson_id, chinese, pinyin, english, source_id, review_status, sequence
)
SELECT v.id, v.lesson_id, v.chinese, v.pinyin, v.english,
       'f1000000-0000-4000-8000-000000000001'::uuid, 'approved', v.sequence
FROM (VALUES
  ('l03e3','mfv1_l03',3,'老师好！','Lǎoshī hǎo!','Hello, teacher!'),
  ('l03e4','mfv1_l03',4,'再见！','Zàijiàn!','Goodbye!'),
  ('l04e3','mfv1_l04',3,'你叫什么名字？','Nǐ jiào shénme míngzi?','What is your name?'),
  ('l04e4','mfv1_l04',4,'我叫乐乐。','Wǒ jiào Lèlè.','My name is Lele.'),
  ('l05e3','mfv1_l05',3,'我是同学。','Wǒ shì tóngxué.','I am a classmate.'),
  ('l05e4','mfv1_l05',4,'很高兴！','Hěn gāoxìng!','Glad to meet you!'),
  ('l06e3','mfv1_l06',3,'你是明明吗？','Nǐ shì Míngming ma?','Are you Mingming?'),
  ('l06e4','mfv1_l06',4,'不是。','Bú shì.','No.'),
  ('l09e3','mfv1_l09',3,'你几岁？','Nǐ jǐ suì?','How old are you?'),
  ('l09e4','mfv1_l09',4,'我八岁。','Wǒ bā suì.','I am eight.'),
  ('l11e3','mfv1_l11',3,'这是爸爸。','Zhè shì bàba.','This is dad.'),
  ('l11e4','mfv1_l11',4,'这是家人。','Zhè shì jiārén.','This is family.'),
  ('l12e3','mfv1_l12',3,'这是我的书。','Zhè shì wǒ de shū.','This is my book.'),
  ('l12e4','mfv1_l12',4,'这是我的朋友。','Zhè shì wǒ de péngyou.','This is my friend.'),
  ('l13e3','mfv1_l13',3,'我在学校。','Wǒ zài xuéxiào.','I am at school.'),
  ('l13e4','mfv1_l13',4,'老师好！','Lǎoshī hǎo!','Hello, teacher!'),
  ('l15e3','mfv1_l15',3,'书包是红色的。','Shūbāo shì hóngsè de.','The bag is red.'),
  ('l15e4','mfv1_l15',4,'我喜欢蓝色。','Wǒ xǐhuan lánsè.','I like blue.'),
  ('l17e3','mfv1_l17',3,'我喝水。','Wǒ hē shuǐ.','I drink water.'),
  ('l17e4','mfv1_l17',4,'我吃苹果。','Wǒ chī píngguǒ.','I eat an apple.'),
  ('l18e3','mfv1_l18',3,'我喜欢苹果。','Wǒ xǐhuan píngguǒ.','I like apples.'),
  ('l18e4','mfv1_l18',4,'我喜欢音乐。','Wǒ xǐhuan yīnyuè.','I like music.'),
  ('l24e3','mfv1_l24',3,'你去哪儿？','Nǐ qù nǎr?','Where are you going?'),
  ('l24e4','mfv1_l24',4,'我去学校。','Wǒ qù xuéxiào.','I am going to school.'),
  ('l26e3','mfv1_l26',3,'我去。','Wǒ qù.','I go.'),
  ('l26e4','mfv1_l26',4,'我来。','Wǒ lái.','I come.'),
  ('l27e3','mfv1_l27',3,'我会说中文。','Wǒ huì shuō Zhōngwén.','I can speak Chinese.'),
  ('l27e4','mfv1_l27',4,'我不会写。','Wǒ bú huì xiě.','I cannot write it.'),
  ('l28e3','mfv1_l28',3,'请喝水。','Qǐng hē shuǐ.','Please drink water.'),
  ('l28e4','mfv1_l28',4,'谢谢！不客气。','Xièxie! Bú kèqi.','Thank you! You are welcome.')
) AS v(id, lesson_id, sequence, chinese, pinyin, english)
WHERE NOT EXISTS (SELECT 1 FROM public.examples e WHERE e.id = v.id);

-- Recycle practice: meaning + listen, using this lesson and earlier words.
INSERT INTO public.activities (
  id, lesson_id, type, prompt, answer, distractors, explanation, difficulty,
  source_id, review_status, sequence
)
SELECT v.id, v.lesson_id, v.type, v.prompt, v.answer, v.distractors::jsonb, v.explanation,
       2, 'f1000000-0000-4000-8000-000000000001'::uuid, 'approved', v.sequence
FROM (VALUES
  ('l04a3','mfv1_l04',3,'mcq','What does 你 mean?','you','["hello","teacher","ten"]','你 is you — it comes back in almost every lesson.'),
  ('l04a4','mfv1_l04',4,'mcq','Which question asks for a name?','你叫什么名字？','["你好！","再见！","我八岁。"]','Reuse 叫, 什么 and 名字 together.'),
  ('l05a3','mfv1_l05',3,'mcq','What does 是 mean here?','am / is / are','["hello","goodbye","ten"]','是 links who someone is.'),
  ('l05a4','mfv1_l05',4,'listen_tap','Tap the phrase for “glad to meet you”.','很高兴','["同学","名字","再见"]','Say it after you hear it.'),
  ('l06a3','mfv1_l06',3,'mcq','How do you say no / is not?','不是','["是","对","吗"]','不是 recycles 是 with 不.'),
  ('l06a4','mfv1_l06',4,'mcq','Which word turns a sentence into a yes/no question?','吗','["不","对","是"]','吗 stays at the end.'),
  ('l09a3','mfv1_l09',3,'mcq','“你几岁？” asks about…','age','["colour","food","school"]','几 and 岁 recycle 你.'),
  ('l09a4','mfv1_l09',4,'mcq','How do you say “I am eight”?','我八岁。','["你好！","再见！","我叫乐乐。"]','Numbers from Lessons 7–8 come back.'),
  ('l11a3','mfv1_l11',3,'mcq','What does 妈妈 mean?','mum','["dad","teacher","friend"]','Family words will return in “this is my…”.'),
  ('l11a4','mfv1_l11',4,'mcq','Which word means family members?','家人','["朋友","学生","书包"]','家人 is the set, not one person.'),
  ('l12a3','mfv1_l12',3,'mcq','What does 我的 mean?','my / mine','["your","this","book"]','的 marks whose thing it is.'),
  ('l12a4','mfv1_l12',4,'mcq','“这是我的书。” means…','This is my book.','["This is mum.","I am eight.","Hello, teacher!"]','这 + 我的 + a noun.'),
  ('l13a3','mfv1_l13',3,'mcq','Where does 在 put you?','at / in a place','["in the past","a colour","a number"]','在 + place.'),
  ('l13a4','mfv1_l13',4,'mcq','老师 is a…','teacher','["student","bag","colour"]','You already said 老师好.'),
  ('l16a3','mfv1_l16',3,'mcq','这 is…','this','["that","who","where"]','这 vs 那 is the point of the lesson.'),
  ('l16a4','mfv1_l16',4,'mcq','那 is…','that','["this","I","you"]','Point farther away with 那.'),
  ('l18a3','mfv1_l18',3,'mcq','喜欢 means…','to like','["to go","to eat","to write"]','You will need this for “I don’t like”.'),
  ('l18a4','mfv1_l18',4,'mcq','“我喜欢音乐。” means…','I like music.','["I like milk.","I am eight.","Hello!"]','Subject + 喜欢 + thing.'),
  ('l19a3','mfv1_l19',3,'mcq','How do you make 喜欢 negative?','不喜欢','["很喜欢","也喜欢","要喜欢"]','不 sits in front.'),
  ('l19a4','mfv1_l19',4,'mcq','“我不喜欢牛奶。” means…','I do not like milk.','["I like milk.","I drink water.","I am at school."]','Same pattern as Lesson 18, with 不.'),
  ('l24a3','mfv1_l24',3,'mcq','去 means…','go','["come","eat","write"]','去 + place.'),
  ('l24a4','mfv1_l24',4,'mcq','“你去哪儿？” asks…','where you are going','["your age","your name","the colour"]','哪儿 recycles question words.'),
  ('l26a3','mfv1_l26',3,'mcq','来 is the opposite of…','去','["吃","喝","写"]','Come vs go.'),
  ('l26a4','mfv1_l26',4,'mcq','吃 and 喝 are…','eat and drink','["come and go","please and thanks","today and tomorrow"]','Action pair.'),
  ('l27a3','mfv1_l27',3,'mcq','会 means…','can / know how to','["want","like","go"]','Ability, not “like”.'),
  ('l27a4','mfv1_l27',4,'mcq','“我会说中文。” means…','I can speak Chinese.','["I like Chinese.","I go to school.","Thank you."]','会 + verb.'),
  ('l28a3','mfv1_l28',3,'mcq','谢谢 is answered with…','不客气','["对不起","没关系","再见"]','Pair the courtesy lines.'),
  ('l28a4','mfv1_l28',4,'listen_tap','Tap “thank you”.','谢谢','["请","对不起","不客气"]','Hear it, then choose it.'),
  ('l07a3','mfv1_l07',3,'mcq','三 means…','three','["one","five","eight"]','Keep 1–5 automatic.'),
  ('l07a4','mfv1_l07',4,'mcq','Which set is 1 to 5?','一、二、三、四、五','["六、七、八、九、十","你好、再见","红、蓝、绿"]','Say them in order out loud.'),
  ('l08a3','mfv1_l08',3,'mcq','十 means…','ten','["two","six","nine"]','6–10 complete the set.'),
  ('l08a4','mfv1_l08',4,'mcq','八 is…','eight','["six","seven","nine"]','You need this for 我八岁.'),
  ('l14a3','mfv1_l14',3,'mcq','桌子 is a…','desk / table','["chair","book","bag"]','Classroom object you can point to.'),
  ('l14a4','mfv1_l14',4,'mcq','椅子 is a…','chair','["desk / table","pencil","school bag"]','Pair it with 桌子.'),
  ('l15a3','mfv1_l15',3,'mcq','红色 means…','red','["blue","green","white"]','Colour words come back with 的.'),
  ('l15a4','mfv1_l15',4,'mcq','蓝色 means…','blue','["red","yellow","green"]','Same pattern, new colour.'),
  ('l17a3','mfv1_l17',3,'mcq','米饭 is…','cooked rice','["noodles","milk","apple"]','Food words for 吃.'),
  ('l17a4','mfv1_l17',4,'mcq','水 is…','water','["milk","rice","apple"]','You 喝 water.'),
  ('l21a3','mfv1_l21',3,'mcq','早上好 is…','good morning','["good night","goodbye","thank you"]','Match the greeting to the time of day.'),
  ('l21a4','mfv1_l21',4,'mcq','晚安 is…','good night','["good morning","good afternoon","goodbye"]','Evening close, not 再见.'),
  ('l22a3','mfv1_l22',3,'mcq','明天 is…','tomorrow','["today","yesterday","now"]','Time words recycle in every plan.'),
  ('l22a4','mfv1_l22',4,'mcq','今天 is…','today','["tomorrow","yesterday","now"]','Contrast with 明天.'),
  ('l23a3','mfv1_l23',3,'mcq','星期一 is…','Monday','["Tuesday","Saturday","Sunday"]','Weekdays start here.'),
  ('l23a4','mfv1_l23',4,'mcq','星期天 is…','Sunday','["Monday","Wednesday","Saturday"]','End of the taught week.'),
  ('l25a3','mfv1_l25',3,'mcq','公园 is a…','park','["shop","home","library"]','Place after 去.'),
  ('l25a4','mfv1_l25',4,'mcq','商店 is a…','shop','["park","school","home"]','Another place you can 去.')
) AS v(id, lesson_id, sequence, type, prompt, answer, distractors, explanation)
WHERE NOT EXISTS (SELECT 1 FROM public.activities a WHERE a.id = v.id);

INSERT INTO public.assessment_items (
  id, lesson_id, question, type, correct_answer, distractors, explanation,
  source_id, review_status, sequence
)
SELECT v.id, v.lesson_id, v.question, v.type, v.correct_answer, v.distractors::jsonb,
       v.explanation, 'f1000000-0000-4000-8000-000000000001'::uuid, 'approved', v.sequence
FROM (VALUES
  ('l10q6','mfv1_l10',6,'mcq','Which greeting is respectful for a teacher?','老师好','["你好","再见","不是"]','Module 1 must still greet a teacher.'),
  ('l10q7','mfv1_l10',7,'mcq','“你叫什么名字？” asks for a…','name','["colour","age","school"]','Lessons 4–5.'),
  ('l10q8','mfv1_l10',8,'mcq','How do you say you are not someone?','不是','["是","对","吗"]','Lesson 6.'),
  ('l10q9','mfv1_l10',9,'mcq','十 means…','ten','["two","five","eight"]','Lessons 7–8.'),
  ('l10q10','mfv1_l10',10,'mcq','“我八岁。” tells…','age','["a name","a colour","a place"]','Lesson 9.'),
  ('l20q6','mfv1_l20',6,'mcq','妈妈 is…','mum','["dad","teacher","bag"]','Family from Lesson 11.'),
  ('l20q7','mfv1_l20',7,'mcq','“这是我的书。” uses 的 to show…','possession','["a question","a colour","ability"]','Lesson 12.'),
  ('l20q8','mfv1_l20',8,'mcq','学校 is…','school','["home","park","shop"]','Lesson 13.'),
  ('l20q9','mfv1_l20',9,'mcq','Which is a colour?','蓝色','["书包","米饭","今天"]','Lesson 15.'),
  ('l20q10','mfv1_l20',10,'mcq','喜欢 means…','to like','["to go","not","please"]','Lessons 18–19.'),
  ('l30q6','mfv1_l30',6,'mcq','早上好 is used…','in the morning','["at night only","to say sorry","to count"]','Lesson 21.'),
  ('l30q7','mfv1_l30',7,'mcq','明天 is…','tomorrow','["today","yesterday","now"]','Lesson 22.'),
  ('l30q8','mfv1_l30',8,'mcq','“你去哪儿？” asks…','where you are going','["your age","your name","what you eat"]','Lesson 24.'),
  ('l30q9','mfv1_l30',9,'mcq','会 marks…','ability','["colour","food","time"]','Lesson 27.'),
  ('l30q10','mfv1_l30',10,'mcq','谢谢 is…','thank you','["please","sorry","goodbye"]','Lesson 28.')
) AS v(id, lesson_id, sequence, type, question, correct_answer, distractors, explanation)
WHERE NOT EXISTS (SELECT 1 FROM public.assessment_items a WHERE a.id = v.id);

INSERT INTO public.audio_clips (
  lesson_id, item_type, item_id, audio_text, speech_lang, provider, source_id, review_status
)
SELECT d.lesson_id, 'dialogue', d.id, d.chinese, 'zh-CN', NULL,
       'f1000000-0000-4000-8000-000000000001'::uuid, 'pending'
FROM public.dialogues d
WHERE NOT EXISTS (
  SELECT 1 FROM public.audio_clips c
  WHERE c.item_type = 'dialogue' AND c.item_id = d.id
);

INSERT INTO public.audio_clips (
  lesson_id, item_type, item_id, audio_text, speech_lang, provider, source_id, review_status
)
SELECT e.lesson_id, 'example', e.id, e.chinese, 'zh-CN', NULL,
       'f1000000-0000-4000-8000-000000000001'::uuid, 'pending'
FROM public.examples e
WHERE NOT EXISTS (
  SELECT 1 FROM public.audio_clips c
  WHERE c.item_type = 'example' AND c.item_id = e.id
);
