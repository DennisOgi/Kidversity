# Kidversity — Explainer Video Walkthrough Script

**Runtime:** ~8–10 minutes  
**URL:** https://kidversity.vercel.app  
**Demo login:** Auth page → **Demo as Student** / **Demo as Teacher** (or `student@kidversity.demo` / `teacher@kidversity.demo`, password `Demo1234!`)

**Before recording:** Hard refresh (`Ctrl+Shift+R`). Apply Supabase migration `20260705190000_fix_assigned_lesson_access_and_award_xp.sql` in SQL Editor if lesson assign/XP still fails.

---

## Scene 1 — Hook (0:00–0:30)

**[Screen: Landing / auth page]**

> Kidversity is a K–12 learning app where teachers upload or AI-generate lessons, assign them to class, run live timed quizzes, and students learn with slides, audio narration, checkpoints, XP, and badges.

**[Click “Sign in” or scroll to auth]**

> We’ll walk through both sides — teacher and student — using the built-in demo accounts.

---

## Scene 2 — Teacher sign-in (0:30–1:00)

**[Auth → tap “Demo as Teacher”]**

> One tap signs in as Ms. Adebayo, a teacher. The dashboard shows class overview, metrics, and quick actions.

**[Teacher Home tab]**

> Home gives a snapshot: student count, lesson count, average score, and shortcuts to create lessons or start a live quiz.

---

## Scene 3 — Teacher: AI lesson creation (1:00–2:30)

**[Bottom nav → Create]**

> On Create, teachers choose Upload or AI Generate. For the demo, tap **AI Generate**.

**[Enter topic, e.g. “Numbers 1–10 in Mandarin for Grade 3” → Generate]**

> Kidversity drafts slides, narration text, and quiz checkpoints — using OpenAI when configured, or smart local templates otherwise.

**[Preview screen → Assign to class]**

> After preview, tap **Assign to class**. The lesson publishes to Supabase and is assigned to every student in the teacher’s class.

**[Success modal / snackbar]**

> Students instantly see it on their Home tab under Continue learning.

---

## Scene 4 — Teacher: Class roster (2:30–3:00)

**[Bottom nav → Class]**

> The Class tab shows enrolled students, mastery rings, weekly activity, and strength/growth tags.

> For this demo, the student account is pre-linked. In production you’d invite students — for the video, open an **incognito window** and sign in as **Demo as Student**.

---

## Scene 5 — Teacher: Live quiz (3:00–4:30)

**[Bottom nav → Live]**

> Live is for timed class quizzes. Pick a quick template — Mandarin, Maths, or Science — or build custom questions.

**[Tap a template → Go live]**

> The teacher gets a monitor screen with join code, countdown, live leaderboard, and answer breakdowns as students submit.

**[Keep this tab open on monitor view]**

> Leave this running — we’ll join from the student side next.

---

## Scene 6 — Student sign-in (4:30–5:00)

**[Incognito window → kidversity.vercel.app/auth → Demo as Student]**

> Chioma’s student dashboard shows streak, XP, level, and assigned lessons.

**[Point at Continue learning carousel]**

> Here’s the lesson the teacher just assigned. Tap any card to open the lesson player.

---

## Scene 7 — Student: Lesson player (5:00–6:30)

**[Open a lesson — e.g. Mandarin Numbers]**

> Lessons play as slides with emoji visuals, captions, and text-to-speech narration. Students can pause, replay, and scrub audio.

**[Advance through slides → checkpoint quiz]**

> Checkpoints verify understanding — multiple choice or pronunciation-style questions.

**[Complete lesson → celebration screen]**

> Finishing a lesson saves progress, awards XP, updates streak, and can unlock badges.

**[Profile tab → toggle “Always show captions” or “Dyslexia-friendly text”]**

> Accessibility settings apply in the lesson player — larger spacing and caption defaults.

---

## Scene 8 — Student: Live quiz join (6:30–7:30)

**[Student Home — live quiz banner appears when teacher started a quiz]**

> When a live quiz is active, students see a banner on Home. Tap **Join**.

**[Answer questions → Submit]**

> Students answer under a countdown; results show score and correct answers when time’s up or the teacher ends the quiz.

**[Switch back to teacher monitor]**

> The teacher monitor updates in real time — joined count, submissions, and per-question stats.

---

## Scene 9 — Student: Explore & Rewards (7:30–8:30)

**[Explore tab]**

> Explore lists all published catalog lessons — search and filter by subject.

**[Rewards tab]**

> Rewards shows earned badges and the class leaderboard (if the student opted in via Profile settings).

**[Profile tab]**

> Profile summarizes XP, skills mastered by subject, and learning preferences.

---

## Scene 10 — Close (8:30–9:00)

**[Split screen or cut between teacher Home and student Home]**

> Kidversity connects teachers and students in one flow: create, assign, learn, quiz live, and track progress — all from the browser.

**[End card: kidversity.vercel.app]**

> Try it free with the demo buttons on the sign-in page.

---

## Recording tips

| Tip | Detail |
|-----|--------|
| Two browsers | Chrome normal = teacher, Incognito = student |
| Resolution | 390×844 mobile or 1280×800 desktop — app is responsive |
| Order matters | Create & assign lesson **before** student incognito login so carousel updates |
| Live quiz | Start live quiz on teacher **before** switching to student for banner |
| Skip upload demo | Upload UI picks files but uses placeholder slides — focus on AI + assign for video |
| Hard refresh | After deploy, force reload so latest build loads |

---

## Feature checklist (what to show vs skip)

| Show in video | Skip / mention only |
|---------------|---------------------|
| Demo login buttons | Manual email typing |
| AI generate + assign | PPT/PDF upload parsing |
| Lesson player + quiz | Per-slide record audio |
| Live quiz template | Custom quiz builder (optional B-roll) |
| Student XP / badges | Static “Recommended” banner on Home |
| Class roster with demo student | In-app student invite (not built yet) |
