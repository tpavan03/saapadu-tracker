# Record and correct dated weight check-ins

Open **Progress → Log weight** to record a measurement with a date. There is one reading per calendar date: saving another reading for that date corrects the entry instead of counting the same day twice. Use **View and edit weight check-ins** to revisit the history.

Backdated entries improve the timeline but do not replace the current weight with an older measurement. The latest dated reading remains the current measurement. Future-dated readings are rejected. Check the selected date before saving a correction, especially when copying measurements from another app.

The weekly prompt is shown inside Saapadu; it is not a scheduled Android notification. Sparse history can still be logged normally. A personal trend estimate needs enough dated evidence, so a first check-in does not instantly create an observed weekly rate.

## Implementation references

- [lib/screens/progress_screen.dart](../../lib/screens/progress_screen.dart)
- [lib/app_state.dart](../../lib/app_state.dart)
