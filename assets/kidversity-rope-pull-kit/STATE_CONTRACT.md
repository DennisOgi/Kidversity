# Production state and event contract

The arena is presentation-only. Adapt your existing models; this is not a proposed database schema.

| Input | Meaning |
|---|---|
| roundId | Stable identity of this round |
| sequence | Monotonic server snapshot/event version within round |
| phase | lobby / countdown / playing / paused / reconnecting / finished |
| position | Normalized server position: -1 Indigo goal, +1 Teal goal |
| indigoScore / tealScore | Actual displayed scores; do not infer position if game rules differ |
| remainingMs | Server-authoritative time remaining |
| countdown | Current countdown label, only when counting down |
| winner | Indigo / Teal / null for draw; authoritative only |
| answer event ID | Unique ID, team and correct/incorrect result for one feedback impulse |

## Adapter rules

1. Reset snapshot/event tracking when roundId changes.
2. Ignore snapshots whose sequence is not greater than the last applied sequence. The renderer does not itself deduplicate network packets.
3. Call `applyState` on a new accepted snapshot. For initial/reconnect state, use `snap: true` rather than replaying the entire past game.
4. Call `feedback` once for each unseen, confirmed answer event. Do not replay sounds/particles from old events on reconnect. Keep event IDs bounded to the current round.
5. A new snapshot can update position without a feedback event. Do not award points in the renderer.
6. Display server-derived time in the surrounding UI. Never let an animation ticker decide who won.
7. A student can submit for their own authorized team only. The two-input demo is a classroom/local example, not a production authorization model.
8. Disable submission while in flight or disconnected. Preserve local typed input when reasonable; discard stale answers when the question ID changes.
9. Set paused/reconnecting explicitly to freeze scene motion. Resume with the latest server state. Stop renderer tickers when the screen/app is inactive.
10. Handle image preloading before starting a production match. A round must not begin simply because a demo button was pressed while assets are unavailable.

## Flutter hookup sketch

```dart
// Inside the existing service/state adapter, after sequence/round checks:
arena.applyState(
  position: snapshot.position,
  phase: mappedPhase,
  indigoScore: snapshot.indigoScore,
  tealScore: snapshot.tealScore,
  countdown: snapshot.countdown,
  winner: mappedWinner,
  snap: isInitialOrReconnect,
);
// Only for a newly confirmed unique event:
arena.feedback(mappedTeam, correct: event.correct);
```

The identifiers above are illustrative adapter fields, not claims about your repository. Preserve its actual room, question and permission contracts.
