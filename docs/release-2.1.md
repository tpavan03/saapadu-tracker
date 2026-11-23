# Saapadu 2.1.0 (+5)

## What is new

- **294 built-in foods** (was 141): street food, drinks, hotel and restaurant
  dishes, sweets and packaged staples, with regional aliases. See
  [`nutrition_sources.md`](nutrition_sources.md).
- **Continuous quantities**: the add-food sheet and diary entry editing use a
  smooth slider with synced servings and grams fields (0.1–10 servings).
- **Water defaults to 4 L** per day; edit only when you drank less or more, or
  reset a day back to 4 L. The −250 / +250 / +500 buttons adjust from the
  value shown.
- **Health Connect (Android, read-only)**: steps, active energy, exercise
  sessions, sleep, weight, body fat, lean mass, body water and BMR.
- **Smart reminders (Android)**: breakfast/lunch/dinner only when not logged,
  an evening "fill today's log" nudge, weekly weigh-in (with tape
  measurements every two weeks), fasting start/end and per-supplement
  reminders. All off by default; a one-time prompt on Today offers them.
- **Quick logging**: recent and frequent foods, copy yesterday's meal, saved
  combos (create from a diary meal's ⋮ menu; edit or delete in More).
- **Supplements**: daily tick-off on Today with optional kcal/protein, streak
  and "taken X of Y days" this month.
- **Protein per meal** in the diary with a dismissible nudge under ~20 g.
- **Body measurements and smart-scale readings** on dated check-ins, with
  small trends on Progress. They do not change calorie targets.
- **Logging streak and weekly summary** on Today and Progress.

## Data compatibility

The backup format string stays `saapadu-backup-v1`, because 2.0 rejects any
other value. All changes are additive:

| Data | Storage | Older app |
| --- | --- | --- |
| Water default | `waterSet` flag on a day; `waterDefaultStart` date in prefs and backup | Ignores both; shows stored water |
| Health Connect values | `importedSteps`, `importedActiveCalories`, `importedSleepHours` beside the manual fields; `source: "health_connect"` on imported weights and workouts | Ignores the extra keys; reads imported weights/workouts as ordinary records |
| Combos, supplements, intakes, body readings | New top-level backup keys and preference keys | Ignores them |

Integers that 2.0 reads with `as int?` (`waterMl`, `steps`,
`exerciseCalories`) remain integers.

**Water history.** The 4 L default only applies on and after
`waterDefaultStart`, the date this diary first opened 2.1 (saved once and
copied into the backup; restoring a backup can move it earlier, never later).
Every earlier day shows exactly its stored value, including a stored 0. A
constant release date was not used because a user updating later would
have their days between the release date and their update reinterpreted.

**Health Connect.** Imports never touch days before `waterDefaultStart`, so
pre-upgrade history keeps its numbers. Manual steps, sleep and watch calories
win when above zero; a manual weight on a date is never replaced; imported
workouts only count on a day without manual workouts; the activity credit
still uses the largest single movement source.

**Mixed versions.** If a 2.0 app restores and re-uploads a 2.1 backup, it
drops the 2.1-only keys. 2.1 keeps its local combos, supplements and body
readings when a restored backup lacks those keys, and Health Connect data is
re-read on the next sync.

## Android

- `minSdk` 24 → **26** (Health Connect's client library requires API 26;
  Health Connect itself needs Android 9+). `compileSdk` 37, core library
  desugaring enabled, `MainActivity` extends `FlutterFragmentActivity`.
- New permissions: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and read-only
  `health.READ_*` permissions. No exact-alarm or write permissions.
- No database migration.
