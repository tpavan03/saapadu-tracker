# Saapadu

A private, offline-first calorie and wellness tracker designed around everyday South Indian food. Built with Flutter for web and Android.

## Included

- 141 built-in foods with portions, calories, protein, carbohydrates, fat, and fiber
- searchable aliases, custom foods, meal diary, and reusable recent foods
- personal calorie and macro targets based on height, weight, age, activity, and goal
- weight history, BMI context, water, sleep, steps, and activity logging
- 25 workout/intensity choices with MET-based calories and overlap-safe exercise credit
- recommended or custom calorie targets, weekly pace, and goal-date planning
- historical daily target snapshots and an intermittent-fasting timer
- automatic browser persistence plus copy-and-restore JSON backup
- optional Google login and Supabase cloud history across devices
- responsive phone and desktop interface with no account, ads, or analytics

Nutrition references and estimation limits are documented in `docs/nutrition_sources.md`; target logic is documented in `docs/health_calculations.md`.
Workout calculations are documented in `docs/workout_calculations.md`; optional cloud setup is in `docs/cloud_setup.md`.

## Development

```bash
flutter pub get
flutter test
flutter analyze
flutter build web --release
flutter build apk --release
```

Web data is stored through `shared_preferences` in the browser's local storage. Keep a backup from **More → Data & backup** before clearing browser data or moving devices.
