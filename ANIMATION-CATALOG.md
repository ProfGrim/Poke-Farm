# Shiny Ranch animation catalog

This document describes the standardized animation names used by the Godot Shiny Ranch, their intended ranch behavior, current coverage, and the safety rules used when importing additional clips.

## Current expansion status

Final verified snapshot: 2026-11-16 America/New_York.

- Ranch model files: **1,453**
- Models with an exact compatible SwSh or Scarlet/Violet source selected for this pass: **1,276**
- Compatible models completed: **1,276 / 1,276**
- Unresolved compatible models: **0**
- Newly merged clips: **10,233**
- Total animation entries across the 1,453 ranch GLBs: **19,307**
- The entire conversion and repair pass ran under the verified 2% total CPU hard cap.
- Every changed GLB is backed up before its first animation merge.

## Standard animation types

| Ranch clip | Intended use | Loop behavior | Coverage |
|---|---|---:|---:|
| `Idle` | Default standing, floating, or stationary pose | Loop | 1,453 |
| `IdleAction` | A longer native idle gesture used to break up stationary periods | One shot | 514 |
| `IdleAlt` | Alternate native idle pose or behavior | One shot unless the source requires a loop | 957 |
| `Walk` | Normal ranch locomotion | Loop | 1,453 |
| `Run` | Faster native locomotion, retained for later speed-matched behavior | Loop | 1,274 |
| `TurnLeft` | Native 90-degree left turn | One shot | 515 |
| `TurnRight` | Native 90-degree right turn | One shot | 515 |
| `Look` | Notice, inspect, touch-response, or look-around behavior | One shot | 849 |
| `Stretch` | Refresh, stretch, shake-out, or similar idle variety | One shot | 512 |
| `Happy` | Glad, cheerful, or excited reaction | One shot | 631 |
| `Grumpy` | Dislike, angry, annoyed, or upset reaction | One shot | 1,261 |
| `Lonely` | Lonely or searching behavior | One shot | 103 |
| `Call` | Cry, roar, vocal gesture, or attention call | One shot | 1,216 |
| `Play` | General native play/glad animation | One shot | 1,248 |
| `BallAction` | Manually verified ball-contact action | One shot | 2 |
| `EatStart` | Transition from normal behavior into eating | One shot | 1,247 |
| `Eat` | Sustained eating pose | Loop | 1,247 |
| `EatEnd` | Transition from eating back to normal behavior | One shot | 1,247 |
| `RestStart` | Transition into a resting pose | One shot | 293 |
| `Rest` | Quiet resting or settled-down pose | Loop in source; may be played once for daytime variety | 293 |
| `RestEnd` | Transition out of the resting pose | One shot | 293 |
| `SleepStart` | Lie down, curl up, or otherwise enter the sleeping pose | One shot | 511 |
| `Nap` | Proper sustained sleeping animation | Loop | 1,064 |
| `Drowse` | Safe drowsing substitute when a proper nap is unavailable | Loop | 56 |
| `SleepEnd` | Wake and return to the normal pose | One shot | 511 |

## Core baseline coverage

Before this native-clip expansion began, the ranch had the following dependable baseline:

| Sequence | Coverage | Notes |
|---|---:|---|
| Idle | 1,453 | Every ranch model |
| Walk/movement | 1,453 | Every ranch model; some stationary residents use the clip without translating |
| Play | 1,248 | General play/glad animation, not proof of physical ball contact |
| Complete eating sequence | 1,247 | All three of `EatStart`, `Eat`, and `EatEnd` |
| Proper nap | 1,064 | Sustained night loop |
| Drowse substitute | 56 | Added only after skeleton-safe review |
| Verified ball contact | 2 | Ball participation remains deliberately strict |

`Play` and `BallAction` are intentionally different. A Pokémon having a cheerful play animation does not mean its feet, nose, hand, or body visibly contacts the ball. Ball events should only use residents whose contact has been visually verified.

## Runtime use

The ranch currently considers these clips for visible ambient variety:

- `IdleAction`
- `IdleAlt`
- `Look`
- `Stretch`
- `Rest`
- `Happy`
- `Grumpy`
- `Lonely`
- `Call`

Ambient actions only start when the resident's 3D model is loaded near the camera. Off-camera simulated residents therefore do not pay the animation/model cost. Ambient actions are cancelled or deferred for meals, nighttime sleep, and coordinated group events.

Phase-two runtime integration has begun:

- `RestStart` → `Rest` → `RestEnd` now runs as a bounded daytime sequence when all three exact clips exist. The loop is played for one complete cycle rather than trapping the resident in the settled pose.
- `SleepStart` → `Nap` or `Drowse` → `SleepEnd` now uses distinct entry, sustained-loop, and waking states. Entry and exit clips are never looped, and closed-eye/sleep effects begin with the sustained sleep pose.
- Meals already use `EatStart` → looping `Eat` → `EatEnd`, aligned to the shared meal window.

The following imported clips are retained but still need behavior-specific timing before general runtime use:

- `Run` needs movement speed matched to footfall speed.
- `TurnLeft` and `TurnRight` need to be coordinated with navigation heading changes.

## Native source mapping

Scarlet/Violet clips are standardized from the resident's exact native files. Common mappings include:

| Native suffix | Ranch name |
|---|---|
| `defaultwait01_loop` | `Idle` |
| `defaultidle01` | `IdleAction` |
| `defaultidle02` | `IdleAlt` |
| `walk01_loop` | `Walk` |
| `run01_loop` | `Run` |
| `turn_l090` | `TurnLeft` |
| `turn_r090` | `TurnRight` |
| `notice01` | `Look` |
| `refresh01` | `Stretch` |
| `glad01` | `Happy` / general `Play` source |
| `hate01` | `Grumpy` |
| `roar01` | `Call` |
| `rest01_start` / `loop` / `end` | Rest sequence |
| `sleep01_start` / `loop` / `end` | Sleep sequence |
| `eat01_start` / `loop` / `end` | Eating sequence |

SwSh animation names vary more between species. The importer safely checks exact native assets such as wait, walk/run, happy, hate/mad, lonely, touch/movement, roar, play, eat, and sleep/drowse clips. A missing native asset is skipped rather than substituted from another skeleton.

Galarian Ponyta and Galarian Slowpoke also retain a small number of raw SwSh-named clips for specialist review, including `kw*` camp reactions, `ba*` battle/reaction clips, `fi21_run01`, `eye01`, and `mouth01`. These raw names are not universal ranch API names and should not be assumed to exist on other residents.

## Import and compatibility rules

1. Only use an animation extracted for the exact model's compatible native skeleton.
2. Never force or retarget a clip merely because another Pokémon has a similarly named bone structure.
3. Match the source game to the ranch GLB's actual skeleton naming. Existing Shield-derived models use the Shield skeleton; lowercase SV skeletons use the SV source.
4. Merge only animation accessors and tracks into the existing GLB. Do not replace the resident model.
5. Preserve existing meshes, materials, textures, eyes, palettes, glow/reflection work, special effects, sleep repairs, and custom clips.
6. Keep the original GLB backup until the expanded model passes integrity and ranch launch tests.
7. Treat loop, entry, and exit clips as separate state-machine pieces. Do not loop entry or exit clips.
8. Visually verify clips that imply physical contact, props, root motion, unusual scale changes, or special effects before enabling them in events.

## Final repair and verification

The final three holds were repaired without replacing their live meshes or materials:

- **Alolan Muk** and **Iron Jugulis:** animation-only conversion now stops after loading the exact skeleton, bypassing irrelevant game shader construction.
- **Krabby:** the merge omits only a missing non-deforming `Eff*` effect-anchor channel; all compatible skeletal channels remain intact.

Final automated verification passed:

1. All **1,453 GLBs** parse successfully.
2. All animation channel node, sampler, accessor, and buffer-view references are valid.
3. All **1,276 compatible models** completed, with **0 holds**.
4. Godot 4.7.2 completed the project import/editor check under the 2% CPU cap.
5. A capped main-scene launch reached `READY residents=0 nav=2996` and exited normally after the test window.

