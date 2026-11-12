import React from 'react';
import { Composition } from 'remotion';
import { FPS, PROMO_DURATION, Promo } from './Promo';

export const Root: React.FC = () => (
  <Composition
    id="KidversityPromo"
    component={Promo}
    durationInFrames={PROMO_DURATION}
    fps={FPS}
    width={1920}
    height={1080}
  />
);
