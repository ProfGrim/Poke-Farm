# Phase 2: animation behavior integration

The native animation library is complete. Phase 2 governs when those clips are
used, how they transition, and which clips require visual approval before they
can participate in coordinated events.

## Implemented

- Stateful meals: `EatStart` → looping `Eat` → `EatEnd`.
- Stateful nighttime rest: `SleepStart` → `Nap`/`Drowse` → `SleepEnd`.
- Stateful daytime rest: `RestStart` → one `Rest` cycle → `RestEnd`.
- Entry and exit clips are explicitly non-looping.
- Sleep eyes and effects begin on the sustained sleeping pose.
- Ambient actions are weighted toward quiet meadow behavior.
- Strong emotional calls are rare and immediate action repetition is suppressed.
- Stable per-resident preferences create individual behavioral tendencies.
- Ambient actions are deferred when they cannot finish before a protected meal,
  nighttime, or coordinated event window.

## Implemented locomotion polish

- Native left/right turns are reserved for meaningful stationary heading changes.
- Run is selected conservatively for fast, solitary multi-edge strolls; events
  and parades remain on Walk.
- Walk and Run playback speed is calibrated from resident footprint, actual
  travel speed, and native clip length, with safe cadence limits.
- Event discovery now ranks at most four groups within 72 metres. The chosen
  group preloads through the existing nearby-model budget while the current
  portrait finishes, allowing the camera to catch more events without keeping
  extra models resident.

## Next

1. Review the physical-contact queue in `contact_review.tscn`. Its decisions are
   saved after every click, so a review session can stop and resume safely.
2. Promote only verified contact clips to ball, toy, greeting, or group play.
3. Add context rules for mood and social actions.
4. Review representative small, medium, large, flying, and swimming residents.
5. Run an extended four-model stream soak before packaging the next EXE.

## Contact review

`Review contact animations.cmd` opens a dedicated low-cost review meadow. It
shows one exact ranch model at a time, loops the selected candidate animation,
and places an adjustable ball at the expected contact point. Reviewers can mark
the clip as a nudge, kick, greeting, group-play action, rejection, or skip.

Approval means visible contact lines up convincingly with the ball. A cheerful
motion that merely happens near the ball must be rejected or skipped. Results
are stored in `user://contact-review.json`; runtime promotion remains a separate
step so an accidental click cannot enable an interaction in the ranch.

Model, palette, eye, material, effect, scale and embedded-animation corrections
must be staged in the shared `pokemon-model-library` repository first. Ranch-specific
camera and behavior logic remains in this Godot project.

