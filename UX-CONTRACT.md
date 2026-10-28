# Saapadu interaction contract

The app retains its Flutter UI, SharedPreferences keys, JSON backup format,
Supabase user_backups payload, user-ID isolation policies, OAuth callbacks and
existing Vercel project. Changes extend the fasting JSON object compatibly.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
| --- | --- | --- | --- | --- |
| Select/Listbox | Flutter Material dropdown and ChoiceChip | Existing forms / theme.dart | authored Material | widget + browser |
| Date | Flutter showDatePicker / DateNavigator | Local calendar date | authored Material | existing screens |
| Form | Material inputs / screen validation | Profile, FoodItem and calculation models | sheet / dialog | flutter test / analyze |
| Scrollbar | ThemeData.scrollbarTheme / Flutter ScrollBehavior | theme.dart | standard Material | desktop browser |
| Toast | ScaffoldMessenger SnackBar | Calling workflow | success / error | widget and browser |
| CRUD | AppState | SharedPreferences + cloud JSON | food, workout, wellness, fasting | state tests |

Navigation retains its screen until a route or destination is selected. Search
is local, transient, clearable and keyboard-accessible. Food search preserves
recent/frequent foods; Repeat last meal copies quantities after confirmation.
Food deletion confirms the named item for both swipe and button paths. Saving
food disables duplicate submission and preserves a retry path on error.

Fasting is optional, with 12:12 as the new-user default and neutral 14:10,16:8
and custom-duration choices. Existing selected windows remain unchanged. Start
requires the product’s eligibility confirmation; under-18/underweight profiles
cannot start an automated timer. Active target changes and duplicate starts
are ignored. UTC timestamps continue across navigation/reload; the target does
not auto-end a real fast. End & save confirms and creates one history record,
including early endings. Ended histories are capped at the latest 200 records,
included in local/cloud backups, and shown with explicit Load more behavior.

Caloric food logging during an active current-day window asks whether to end it
at entry time. Keeping the timer still logs calories normally. Fasting never
changes calorie goals, exercise credit, hydration or nutrient totals.

All dialogs are app-owned Material dialogs with modal focus/Escape behavior.
Native browser alert/confirm are not used. Target WCAG 2.2 AA through Flutter
semantics, labelled controls, visible focus and narrow layouts. The app is an
estimate-based personal diary; it must not claim authenticated cloud sync was
verified when only a frontend or anonymous endpoint was tested.
