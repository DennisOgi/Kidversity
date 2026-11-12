import React from 'react';
import {
  AbsoluteFill,
  Img,
  OffthreadVideo,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { loadFont as loadJakarta } from '@remotion/google-fonts/PlusJakartaSans';
import { loadFont as loadDmSans } from '@remotion/google-fonts/DMSans';
import ready from '../public/footage/clips.json';

export const { fontFamily: heading } = loadJakarta('normal', {
  weights: ['700', '800'],
  subsets: ['latin'],
});
export const { fontFamily: body } = loadDmSans('normal', {
  weights: ['400', '500', '700'],
  subsets: ['latin'],
});

/** The app's palette, so the video matches the product. */
export const colors = {
  violetDeep: '#2A1F8F',
  violet: '#4433CC',
  violetLight: '#7B4FE8',
  ink: '#20213B',
  sun: '#FFC845',
  coral: '#FF6B5B',
  mint: '#22B07D',
  sky: '#2F8FEA',
  pink: '#E85AA8',
  paper: '#FBFAFF',
};

/** Seconds into each recording when the app had finished loading. */
const readyAt = ready as Record<string, number>;

/**
 * A recorded clip of the real app, trimmed so it starts once the page is up.
 * [skip] trims extra seconds after that.
 */
export const Footage: React.FC<{
  name: string;
  skip?: number;
  style?: React.CSSProperties;
}> = ({ name, skip = 0, style }) => {
  const { fps } = useVideoConfig();
  const start = Math.round(((readyAt[name] ?? 3) + skip) * fps);
  return (
    <OffthreadVideo
      src={staticFile(`footage/${name}.webm`)}
      startFrom={start}
      muted
      style={{ width: '100%', height: '100%', objectFit: 'cover', ...style }}
    />
  );
};

/** Violet gradient with slowly drifting brand shapes. */
export const Backdrop: React.FC<{ tone?: 'violet' | 'paper' }> = ({
  tone = 'violet',
}) => {
  const frame = useCurrentFrame();
  const drift = (speed: number, range: number) =>
    Math.sin((frame / 30) * speed) * range;
  const violet = tone === 'violet';
  return (
    <AbsoluteFill
      style={{
        background: violet
          ? `linear-gradient(135deg, ${colors.violetDeep} 0%, ${colors.violet} 55%, ${colors.violetLight} 100%)`
          : colors.paper,
        overflow: 'hidden',
      }}
    >
      <Blob size={620} color={colors.sun} x={1520 + drift(0.4, 20)} y={-260 + drift(0.3, 25)} opacity={violet ? 1 : 0.35} />
      <Blob size={460} color={colors.coral} x={-180 + drift(0.35, 25)} y={760 + drift(0.5, 20)} opacity={violet ? 0.6 : 0.25} />
      <Blob size={90} color={colors.mint} x={1700 + drift(0.6, 15)} y={880 + drift(0.4, 18)} radius={24} rotate={20 + frame * 0.2} opacity={violet ? 1 : 0.5} />
      <Blob size={34} color={colors.sky} x={980 + drift(0.8, 30)} y={90 + drift(0.6, 12)} opacity={violet ? 1 : 0.6} />
      <Blob size={46} color={colors.pink} x={240 + drift(0.5, 20)} y={170 + drift(0.7, 14)} radius={12} rotate={-15 - frame * 0.3} opacity={violet ? 0.9 : 0.5} />
    </AbsoluteFill>
  );
};

const Blob: React.FC<{
  size: number;
  color: string;
  x: number;
  y: number;
  radius?: number;
  rotate?: number;
  opacity?: number;
}> = ({ size, color, x, y, radius, rotate = 0, opacity = 1 }) => (
  <div
    style={{
      position: 'absolute',
      left: x,
      top: y,
      width: size,
      height: size,
      background: color,
      opacity,
      borderRadius: radius ?? size,
      transform: `rotate(${rotate}deg)`,
    }}
  />
);

/** Springs from 0 to 1 starting at [delay] frames. */
export function useEnter(delay = 0, damping = 16) {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return spring({ frame: frame - delay, fps, config: { damping, mass: 0.7 } });
}

/** Headline and supporting line that rise in. */
export const Caption: React.FC<{
  eyebrow?: string;
  title: string;
  sub?: string;
  color?: string;
  align?: 'left' | 'center';
  width?: number;
}> = ({ eyebrow, title, sub, color = '#fff', align = 'left', width = 760 }) => {
  const a = useEnter(4);
  const b = useEnter(10);
  const c = useEnter(16);
  const rise = (t: number) => ({
    opacity: t,
    transform: `translateY(${interpolate(t, [0, 1], [30, 0])}px)`,
  });
  return (
    <div style={{ width, textAlign: align }}>
      {eyebrow ? (
        <div
          style={{
            ...rise(a),
            display: 'inline-block',
            padding: '8px 18px',
            borderRadius: 999,
            background: colors.sun,
            color: colors.ink,
            fontFamily: body,
            fontWeight: 700,
            fontSize: 22,
            letterSpacing: 1.5,
            marginBottom: 22,
          }}
        >
          {eyebrow.toUpperCase()}
        </div>
      ) : null}
      <div
        style={{
          ...rise(b),
          fontFamily: heading,
          fontWeight: 800,
          fontSize: 76,
          lineHeight: 1.05,
          letterSpacing: -2,
          color,
        }}
      >
        {title}
      </div>
      {sub ? (
        <div
          style={{
            ...rise(c),
            marginTop: 22,
            fontFamily: body,
            fontSize: 30,
            lineHeight: 1.45,
            color: color === '#fff' ? '#EDEAFF' : '#4B4D66',
          }}
        >
          {sub}
        </div>
      ) : null}
    </div>
  );
};

/** A clean browser window around desktop footage. */
export const BrowserFrame: React.FC<{
  width: number;
  url: string;
  children: React.ReactNode;
  delay?: number;
}> = ({ width, url, children, delay = 6 }) => {
  const t = useEnter(delay, 18);
  const height = (width * 900) / 1440;
  return (
    <div
      style={{
        width,
        borderRadius: 22,
        overflow: 'hidden',
        background: '#fff',
        boxShadow: '0 40px 90px rgba(20, 8, 90, 0.45)',
        opacity: t,
        transform: `translateY(${interpolate(t, [0, 1], [70, 0])}px) scale(${interpolate(t, [0, 1], [0.94, 1])})`,
      }}
    >
      <div
        style={{
          height: 46,
          display: 'flex',
          alignItems: 'center',
          gap: 9,
          padding: '0 18px',
          background: '#F1EFFA',
          borderBottom: '1px solid #E4E1F2',
        }}
      >
        {['#FF6B5B', '#FFC845', '#22B07D'].map((c) => (
          <div key={c} style={{ width: 13, height: 13, borderRadius: 13, background: c }} />
        ))}
        <div
          style={{
            marginLeft: 18,
            flex: 1,
            maxWidth: 520,
            height: 28,
            borderRadius: 14,
            background: '#fff',
            display: 'flex',
            alignItems: 'center',
            padding: '0 14px',
            fontFamily: body,
            fontSize: 16,
            color: '#5F6378',
          }}
        >
          {url}
        </div>
      </div>
      <div style={{ width, height, position: 'relative' }}>{children}</div>
    </div>
  );
};

/** A phone around phone-sized footage. */
export const PhoneFrame: React.FC<{
  height: number;
  children: React.ReactNode;
  delay?: number;
  tilt?: number;
}> = ({ height, children, delay = 6, tilt = 0 }) => {
  const t = useEnter(delay, 18);
  const width = (height * 390) / 844;
  const bezel = 14;
  return (
    <div
      style={{
        width: width + bezel * 2,
        height: height + bezel * 2,
        padding: bezel,
        borderRadius: 56,
        background: '#14152A',
        boxShadow: '0 40px 90px rgba(20, 8, 90, 0.5)',
        opacity: t,
        transform: `translateY(${interpolate(t, [0, 1], [90, 0])}px) rotate(${tilt}deg)`,
      }}
    >
      <div
        style={{
          width,
          height,
          borderRadius: 44,
          overflow: 'hidden',
          position: 'relative',
          background: '#fff',
        }}
      >
        {children}
      </div>
    </div>
  );
};

export const Logo: React.FC<{ size?: number; dark?: boolean }> = ({
  size = 120,
  dark = false,
}) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.29,
      background: dark ? colors.violet : '#fff',
      display: 'grid',
      placeItems: 'center',
      boxShadow: '0 30px 60px rgba(20, 8, 90, 0.35)',
    }}
  >
    <Img
      src={staticFile(dark ? 'brand/mark-white.svg' : 'brand/mark-indigo.svg')}
      style={{ width: size * 0.58, height: size * 0.58 }}
    />
  </div>
);
