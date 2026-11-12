import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
} from 'remotion';
import { TransitionSeries, linearTiming } from '@remotion/transitions';
import { slide } from '@remotion/transitions/slide';
import { fade } from '@remotion/transitions/fade';
import {
  Backdrop,
  BrowserFrame,
  Caption,
  Footage,
  Logo,
  PhoneFrame,
  body,
  colors,
  heading,
  useEnter,
} from './parts';

export const FPS = 30;

// Scene lengths in frames (30 fps). Transitions overlap by TRANSITION.
const TRANSITION = 15;
const SCENES = {
  intro: 90,
  landing: 210,
  student: 180,
  rope: 330,
  teacher: 180,
  school: 210,
  parent: 165,
  phone: 210,
  outro: 135,
};

export const PROMO_DURATION =
  Object.values(SCENES).reduce((a, b) => a + b, 0) -
  TRANSITION * (Object.keys(SCENES).length - 1);

/** Caption on the left, the app in a browser on the right. */
const Split: React.FC<{
  eyebrow: string;
  title: string;
  sub: string;
  url: string;
  clip: string;
  skip?: number;
  tone?: 'violet' | 'paper';
}> = ({ eyebrow, title, sub, url, clip, skip, tone = 'violet' }) => (
  <AbsoluteFill>
    <Backdrop tone={tone} />
    <AbsoluteFill
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        padding: '0 90px',
        gap: 70,
      }}
    >
      <Caption
        eyebrow={eyebrow}
        title={title}
        sub={sub}
        width={560}
        color={tone === 'violet' ? '#fff' : colors.ink}
      />
      <BrowserFrame width={1130} url={url}>
        <Footage name={clip} skip={skip} />
      </BrowserFrame>
    </AbsoluteFill>
  </AbsoluteFill>
);

const Intro: React.FC = () => {
  const logo = useEnter(0, 12);
  const word = useEnter(12);
  const line = useEnter(22);
  return (
    <AbsoluteFill>
      <Backdrop />
      <AbsoluteFill
        style={{ alignItems: 'center', justifyContent: 'center', gap: 34 }}
      >
        <div style={{ transform: `scale(${logo})` }}>
          <Logo size={170} />
        </div>
        <div
          style={{
            opacity: word,
            transform: `translateY(${interpolate(word, [0, 1], [30, 0])}px)`,
            fontFamily: heading,
            fontWeight: 800,
            fontSize: 110,
            letterSpacing: -3,
            color: '#fff',
          }}
        >
          kidversity
        </div>
        <div
          style={{
            opacity: line,
            fontFamily: body,
            fontSize: 38,
            color: '#EDEAFF',
          }}
        >
          Learning that feels like play.
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

/** Full-width arena with the game's own sound cues. */
const Rope: React.FC = () => {
  const frame = useCurrentFrame();
  // The demo match pulls every 1.3 s and finishes on the eighth pull.
  const pulls = Array.from({ length: 8 }, (_, i) => Math.round((i + 1) * 1.3 * FPS));
  const zoom = interpolate(frame, [0, SCENES.rope], [1, 1.06]);
  return (
    <AbsoluteFill>
      <Backdrop />
      <AbsoluteFill style={{ alignItems: 'center', paddingTop: 60 }}>
        <Caption
          eyebrow="Play"
          title="Live Rope Pull with classmates"
          sub="Answer fast. Every right answer pulls the rope for your team."
          align="center"
          width={1300}
        />
        <div style={{ marginTop: 40, transform: `scale(${zoom})` }}>
          <BrowserFrame width={1080} url="kidversity.app/student/play" delay={10}>
            <Footage name="rope" />
          </BrowserFrame>
        </div>
      </AbsoluteFill>
      <Audio src={staticFile('audio/start.wav')} volume={0.5} />
      {pulls.slice(0, 7).map((at) => (
        <Sequence key={at} from={at} durationInFrames={30}>
          <Audio src={staticFile('audio/correct.wav')} volume={0.35} />
        </Sequence>
      ))}
      <Sequence from={pulls[7]}>
        <Audio src={staticFile('audio/win.wav')} volume={0.55} />
      </Sequence>
    </AbsoluteFill>
  );
};

/** Two school pages, overview then staff invites. */
const School: React.FC = () => (
  <AbsoluteFill>
    <Backdrop tone="paper" />
    <AbsoluteFill
      style={{ flexDirection: 'row', alignItems: 'center', padding: '0 90px', gap: 70 }}
    >
      <Caption
        eyebrow="Schools"
        title="Set up your whole school in minutes"
        sub="Invite teachers with one staff code, place every student in a class, and follow the school at a glance."
        width={560}
        color={colors.ink}
      />
      <BrowserFrame width={1130} url="kidversity.app/school">
        <Sequence durationInFrames={110}>
          <Footage name="school" />
        </Sequence>
        <Sequence from={110}>
          <Footage name="school-teachers" />
        </Sequence>
      </BrowserFrame>
    </AbsoluteFill>
  </AbsoluteFill>
);

const Phones: React.FC = () => (
  <AbsoluteFill>
    <Backdrop />
    <AbsoluteFill
      style={{ flexDirection: 'row', alignItems: 'center', padding: '0 110px', gap: 80 }}
    >
      <Caption
        eyebrow="Any device"
        title="Made for the phones children already have"
        sub="No download. Open it in the browser and start learning."
        width={620}
      />
      <div style={{ display: 'flex', gap: 46, alignItems: 'center' }}>
        <PhoneFrame height={760} delay={8} tilt={-3}>
          <Footage name="phone-landing" />
        </PhoneFrame>
        <PhoneFrame height={760} delay={16} tilt={3}>
          <Footage name="phone-student" />
        </PhoneFrame>
      </div>
    </AbsoluteFill>
  </AbsoluteFill>
);

const Outro: React.FC = () => {
  const a = useEnter(0, 12);
  const b = useEnter(12);
  const c = useEnter(22);
  return (
    <AbsoluteFill>
      <Backdrop />
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', gap: 30 }}>
        <div style={{ transform: `scale(${a})` }}>
          <Logo size={140} />
        </div>
        <div
          style={{
            opacity: b,
            transform: `translateY(${interpolate(b, [0, 1], [30, 0])}px)`,
            fontFamily: heading,
            fontWeight: 800,
            fontSize: 84,
            letterSpacing: -2,
            color: '#fff',
            textAlign: 'center',
            lineHeight: 1.08,
          }}
        >
          One learning home
          <br />
          for your whole school.
        </div>
        <div
          style={{
            opacity: c,
            transform: `scale(${interpolate(c, [0, 1], [0.9, 1])})`,
            marginTop: 14,
            padding: '22px 46px',
            borderRadius: 22,
            background: colors.sun,
            boxShadow: '0 10px 0 #D9A21C',
            fontFamily: heading,
            fontWeight: 800,
            fontSize: 40,
            color: colors.ink,
          }}
        >
          Get started free at kidversity.app
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const Promo: React.FC = () => {
  const timing = linearTiming({ durationInFrames: TRANSITION });
  return (
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={SCENES.intro}>
        <Intro />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.landing}>
        <Split
          eyebrow="Kidversity"
          title="Learning that feels like play"
          sub="Mandarin, mental maths, WAEC and UTME past questions, science labs and live games, in one place."
          url="kidversity.app"
          clip="landing"
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={slide({ direction: 'from-right' })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.student}>
        <Split
          tone="paper"
          eyebrow="Students"
          title="A clear next step, every day"
          sub="The next lesson, today's work from the teacher, streaks and XP, all on one colourful home."
          url="kidversity.app/student"
          clip="student"
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={slide({ direction: 'from-right' })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.rope}>
        <Rope />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={slide({ direction: 'from-right' })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.teacher}>
        <Split
          tone="paper"
          eyebrow="Teachers"
          title="See who needs you, at a glance"
          sub="Set lessons, maths and past papers. Know who handed in, who is stuck, and why."
          url="kidversity.app/teacher/home"
          clip="teacher"
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={slide({ direction: 'from-right' })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.school}>
        <School />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={slide({ direction: 'from-right' })} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.parent}>
        <Split
          eyebrow="Parents"
          title="Follow your child's week"
          sub="Streaks, time learning and where they are in every subject. One family code links every child."
          url="kidversity.app/parent/family"
          clip="parent"
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.phone}>
        <Phones />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={timing} />

      <TransitionSeries.Sequence durationInFrames={SCENES.outro}>
        <Outro />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  );
};
