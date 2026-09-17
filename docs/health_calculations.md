# Health calculations and safety rules

This document defines the adult calorie, weight, activity, sleep, and fasting logic for the app. It is a product specification, not a diagnosis or a substitute for a clinician. Every calculated value must be labelled as an estimate.

## Supported population

Automatic targets are for adults aged 18 or older. Do not calculate a calorie deficit or fasting recommendation for:

- anyone under 18;
- pregnancy or breastfeeding;
- BMI below 18.5;
- a user who says they have an active or previous eating disorder;
- a user who says they have type 1 diabetes, use insulin or a sulfonylurea, have frequent low blood sugar, or have been told to follow a medically prescribed diet.

For those cases, the app may still act as a food, weight, sleep, steps, or fasting-event diary, but it must switch calorie goals to a user-entered target and show: **“Ask a qualified clinician or dietitian to set your calorie and fasting targets.”**

The NIH Body Weight Planner is likewise intended for adults and excludes pregnancy and breastfeeding. Fasting evidence is limited, and diabetes medicines can require adjustment when meal timing changes.

## Units and rounding

Store canonical values without display rounding:

- body mass: kilograms (`kg`)
- height: centimetres (`cm`)
- energy: kilocalories (`kcal`; the “Calories” shown on food labels)
- time: UTC timestamps plus the user's IANA time zone
- distance: kilometres

Convert pounds with `kg = lb * 0.45359237` and inches with `cm = in * 2.54`. Round displayed daily calorie targets to the nearest 10 kcal, food totals to the nearest 1 kcal, weights to 0.1 kg, and BMI to one decimal. Perform all comparisons on unrounded values.

## Resting energy expenditure

Use the Mifflin–St Jeor resting energy expenditure (REE) equation for adults:

```text
common = 10 * weightKg + 6.25 * heightCm - 5 * ageYears
REE (male reference)   = common + 5
REE (female reference) = common - 161
```

The original equation calls this REE, so the UI should use **“estimated resting calories”**, not imply that it is a laboratory-measured basal metabolic rate.

The equation was published with binary sex coefficients. In onboarding, explain why this input exists rather than relabelling it as gender:

> **Body reference for the calorie equation**  
> This equation was developed with male and female body-reference coefficients. Choose the reference that best matches your physiology, or set a calorie target manually.

Options: `Female reference`, `Male reference`, `Set manually`. A user's gender identity can be stored separately if the product needs it and must not silently select the equation coefficient. For a transgender user or anyone unsure which coefficient is appropriate, offer manual target and clinician guidance. Do not invent an average coefficient because it has not been validated.

Required inputs and validation for automatic calculation:

- age: 18–120 years
- height: 100–250 cm
- current weight: 30–350 kg
- one equation reference

Values outside these implementation ranges should use a manual goal rather than being silently clamped.

## Total daily energy expenditure

Estimate maintenance calories with a physical activity level (PAL):

```text
estimatedTdee = ree * pal
```

Use these National Academies PAL category midpoints:

| App choice | PAL | Picker guidance |
|---|---:|---|
| Inactive | 1.40 | Mostly seated; only ordinary daily tasks |
| Low active | 1.60 | Regular walking and light activity |
| Active | 1.75 | Substantial moderate activity most days |
| Very active | 2.05 | Long or demanding activity most days |

Default to `Inactive`; never infer a higher level from a single workout or one high-step day. Ask about the user's usual recent routine. The National Academies describes approximate category ranges of 1.0–<1.53, 1.53–<1.68, 1.68–<1.85, and 1.85–<2.50. These values are population estimates, not precise measurements for an individual.

The app needs one of two explicit activity modes to avoid counting the same movement in both PAL and the daily exercise ledger:

- **Daily activity credit (default):** use the Inactive PAL of 1.40 as the base and add deduplicated device or manually logged active energy through the conservative exercise-credit rule below. This is the closest match to a MyFitnessPal-style changing daily budget.
- **Fixed activity estimate:** use the selected PAL as the complete maintenance estimate and default exercise credit to `None (0%)`. A user may opt into credit for an exceptional workout, but the UI must explain that a workout already represented by their chosen activity level should not be added again.

Store the mode with each daily target snapshot. Never apply a PAL above 1.40 and full imported daily active energy without an explicit double-counting warning.

Show this below the result:

> **Maintenance estimate: 2,180 kcal/day**  
> Your real needs can be higher or lower. Your weight trend is more useful than any single-day estimate.

Recalculate REE and TDEE after a new weight is saved, but freeze the displayed food goal for the rest of that local calendar day. Apply the new goal the next day so the historical ledger does not change.

## Weight-loss target

Support `Maintain` and `Lose weight` in the first release. Do not treat a desired date as permission to create an extreme deficit.

For a requested goal date:

```text
weightToLoseKg = currentWeightKg - goalWeightKg
daysToGoal = goalDate - today
requestedKgPerWeek = weightToLoseKg * 7 / daysToGoal
```

Reject a loss target when `goalWeightKg >= currentWeightKg`; direct the user to maintenance (or a future gain workflow). Do not offer automatic weight loss when current BMI or goal BMI is below 18.5.

CDC describes gradual loss of about 1–2 lb (roughly 0.45–0.9 kg) per week as the usual sustainable range. Offer presets of 0.25, 0.5, and 0.75 kg/week, allow up to 0.9 kg/week, and reject a requested rate above 0.9 kg/week. For a rejected date, show the earliest date at 0.9 kg/week:

> **That date requires losing about 1.2 kg each week.**  
> A gradual target is no more than about 0.9 kg per week. The earliest target date we can calculate is 14 February.

For the simple first-release model:

```text
plannedDailyDeficit = requestedKgPerWeek * 7700 / 7
plannedDailyDeficit = min(plannedDailyDeficit, 1000)
rawFoodGoal = estimatedTdee - plannedDailyDeficit
```

`7,700 kcal/kg` is the rounded metric equivalent of the traditional 3,500 kcal/lb rule. It is only a planning approximation. Human weight change is dynamic, and energy needs change as weight changes. The NIH Body Weight Planner uses a dynamic mathematical model; do not promise that the simple formula predicts an exact date.

### Minimum automatic targets

The app must not automatically set a base food target below:

- 1,200 kcal/day for the female equation reference;
- 1,500 kcal/day for the male equation reference.

These are conservative product floors based on calorie ranges used in NHLBI adult weight-loss interventions. They are not universal biological thresholds. If the raw goal is below the floor:

```text
baseFoodGoal = floor
achievableDailyDeficit = max(0, estimatedTdee - baseFoodGoal)
estimatedKgPerWeek = achievableDailyDeficit * 7 / 7700
```

Show the slower estimate rather than hiding the clamp:

> **Your safer app target is 1,200 kcal/day.**  
> At your estimated maintenance calories, your selected pace would require a lower intake. We adjusted the pace to about 0.3 kg per week.

For maintenance, `baseFoodGoal = roundToNearest10(estimatedTdee)`.

Do not use “calories remaining” as a command to eat or to stop eating. Preferred text is **“Estimated budget remaining”** with an info action that explains estimation error and nutrition quality.

## Daily calorie ledger

Keep these quantities separate:

```text
foodEaten = sum(foodEntryCalories)
creditedExercise = sum(deduplicatedActiveCalories * exerciseCreditRate)
adjustedFoodBudget = baseFoodGoal + creditedExercise
estimatedBudgetRemaining = adjustedFoodBudget - foodEaten
netCalories = foodEaten - creditedExercise
```

In **Daily activity credit** mode, use `exerciseCreditRate = 0.50` by default. Let the user select `None (0%)`, `Conservative (50%)`, or `Full estimate (100%)`, with conservative preselected. In **Fixed activity estimate** mode, preselect `None (0%)`. These percentages are cautious product policies, not clinical formulas. Consumer wearables estimate energy expenditure with substantial individual error; one Stanford validation found mean error of 27% even for the best tested device.

UI wording:

> **Exercise credit: +140 kcal**  
> We credited 50% of the 280 kcal estimate because watch and activity calories can be inaccurate. Change this in Settings.

Never apply negative exercise calories. Flag, but do not automatically delete, an active-energy import over 1,500 kcal/day or a single session over 1,000 kcal for user review. Exercise credit raises the day's food budget; it must never lower the minimum base target.

### Prevent double counting

Each activity event needs `source`, `externalId`, `startTime`, `endTime`, `activityType`, and `activeKcal` where available.

1. Import **active energy**, not a device's total daily energy (which includes resting energy already represented in TDEE).
2. Upsert by `(source, externalId)`.
3. If two sources overlap by at least 80% of duration and describe the same activity, retain the user's preferred source or the event with direct active-energy data; do not sum both.
4. If a workout has active calories and its steps are also in the daily step total, display both metrics but credit calories only from the workout/active-energy event.
5. A manually logged workout that overlaps an imported workout should prompt: **“This may be the same workout. Keep both or merge?”** Default to merge.

The activity-level estimate already includes ordinary movement. The exercise ledger is therefore an intentionally approximate same-day adjustment. Make this visible in Settings and avoid claims of exact “earned” food.

### Manual activity estimate

When no device calorie value exists, use a MET from the 2024 Adult Compendium of Physical Activities:

```text
grossKcal = met * weightKg * durationMinutes / 60
activeKcal = max(0, (met - 1) * weightKg * durationMinutes / 60)
```

Subtracting 1 MET produces an active-energy estimate and avoids crediting the resting energy already included in TDEE. Label it **“estimated active calories.”** The standard MET is approximately 1 kcal/kg/hour and is a population convention, so individual cost varies.

For steps/odometer data:

- import the platform's active-energy record when it is available;
- if only steps are available, show steps and distance but do not invent calorie credit from steps alone;
- if duration, body mass, and a reliable walking pace are available, choose the matching walking MET and calculate active calories once;
- never credit both the walking estimate and an overlapping active-energy record.

## BMI display and caveats

```text
bmi = weightKg / ((heightCm / 100) ^ 2)
```

Standard adult display categories:

| BMI | Label |
|---:|---|
| <18.5 | Underweight |
| 18.5–24.9 | Healthy-weight range |
| 25.0–29.9 | Overweight range |
| ≥30.0 | Obesity range |

Always place this text beside the category:

> BMI is a screening measure based only on height and weight. It does not diagnose body fat or health and may not reflect muscle mass, body composition, age, or ethnicity.

Because the intended audience includes South Indian users, add:

> People from South Asian backgrounds can develop diabetes and heart-health risks at lower BMI values. A BMI of 23 or 27.5 may be used as an action point for increased or high risk; consider discussing your BMI and waist measurement with a clinician.

Do not change the calorie equation solely because of BMI category or ethnicity. Do not call a user “obese”; describe a value as being in a range.

## Weight trend and recalculation

- Permit daily weigh-ins, but present a 7-day rolling median once at least three readings exist.
- Compare weekly medians; never label one day's increase as fat gain.
- Recalculate the next day's target from current trend weight no more than once per week.
- If actual trend differs from the estimate, show **“Your trend differs from the estimate”** and invite the user to check portions, imports, activity setting, medication/health changes, and clinician advice. Do not shame the user.
- Do not automatically reduce calories in response to a short plateau. Water, glycogen, sodium, digestion, menstrual cycle, and measurement conditions can move scale weight independently of fat.

## Sleep tracking

Sleep is a tracked health behavior and must not add or subtract calories. Use CDC adult targets:

| Age | Displayed target |
|---:|---|
| 18–60 | 7 or more hours |
| 61–64 | 7–9 hours |
| 65+ | 7–8 hours |

Store sleep start/end, duration, source, and optional quality. Merge overlapping device and manual records. UI wording:

> **Sleep: 6 h 35 min**  
> Most adults your age are recommended to get at least 7 hours. Sleep does not change today's calorie budget.

Do not calculate a sleep calorie penalty, claim that one poor night caused weight gain, or diagnose a sleep disorder. If a user repeatedly reports difficulty sleeping, use: **“Consider discussing ongoing sleep problems with a healthcare professional.”**

## Intermittent fasting

Fasting is an optional timer and schedule, not a required weight-loss plan and not a source of bonus calories. It does not change `baseFoodGoal`, `creditedExercise`, or nutrient totals.

Offer `12:12`, `14:10`, and `16:8` time-window presets plus custom start/end times. Preselect 12:12 and describe all presets neutrally. Do not default to alternate-day fasting, 5:2 restriction, multi-day fasting, or a sub-1,200/1,500 kcal “fast day.” The NIA says evidence is insufficient to recommend a fasting regimen broadly and long-term safety remains uncertain.

Before enabling a schedule, ask the exclusion questions from **Supported population**. Pregnancy/breastfeeding, under 18, eating-disorder history, BMI below 18.5, diabetes medicines that can cause low blood sugar, frailty, or a clinician-prescribed meal schedule should block automated fasting schedules and show clinician guidance.

Timer semantics:

- A fast begins when the user taps `Start fast` or at a scheduled time only if they enabled automatic scheduling.
- Logging food or a caloric drink during an active fast prompts: **“End fast at this entry time?”** Do not silently edit either record.
- Water and zero-calorie drinks do not end the app's nutrition fast by default; make the rule configurable because religious and personal definitions differ.
- Medication must never be discouraged or delayed by the timer.
- An ended-early fast remains a valid history record; use neutral language such as **“Fast ended”**, never “failed.”

Persistent safety copy:

> Fasting is optional and may not suit everyone. It does not replace a balanced diet or change your calorie target. Stop the fast if you feel unwell. If you use diabetes medicine or have a medical condition, ask your clinician before changing meal timing.

## Required explanations in the app

The calculation-details sheet should show the user's current numbers, for example:

```text
Resting estimate                     1,560 kcal
Activity level (Low active × 1.60)   2,496 kcal maintenance
Planned deficit                        550 kcal
Base food target                     1,950 kcal (rounded)
Exercise estimate today                300 kcal
Exercise credit (50%)                  150 kcal
Today's adjusted budget              2,100 kcal
Food logged                          1,420 kcal
Estimated budget remaining             680 kcal
```

Also show when it was recalculated and which weight was used. Every source field and manual override must remain editable. Historical daily totals must be snapshots so later food-database or formula changes do not rewrite the past.

## Implementation invariants

These conditions should become unit tests when the calorie engine exists:

1. Mifflin–St Jeor returns 1,623.75 kcal/day for a 35-year-old, 70 kg, 175 cm male-reference profile and 1,457.75 for the female-reference profile.
2. TDEE is REE multiplied by exactly one PAL.
3. A rate above 0.9 kg/week is rejected, not clamped invisibly.
4. A base loss target never falls below its reference floor.
5. Exercise credit never changes the base target and is zero when credit rate is zero.
6. Total device energy is never accepted as active energy.
7. Duplicate/overlapping activities contribute calorie credit once.
8. Food logged during a fast is still counted normally.
9. Sleep duration never changes calories.
10. Weight/BMI inputs outside supported bounds produce a validation result rather than `NaN`, infinity, or a silently clamped value.
11. A goal BMI below 18.5 cannot produce an automatic loss target.
12. All ledger operations are deterministic in the user's local calendar day across UTC offsets and daylight-saving changes.

## Sources

- Mifflin MD et al. “A new predictive equation for resting energy expenditure in healthy individuals,” *American Journal of Clinical Nutrition* (original equation and coefficients): https://ajcn.nutrition.org/article/S0002-9165%2823%2916698-6/pdf
- National Academies, 2023 DRI energy highlights (PAL categories, ranges, and example activities): https://nap.nationalacademies.org/resource/26818/DRIs_for_Energy_Highlights.pdf
- NHLBI/NIH systematic evidence review for adult weight management (energy deficits, calorie ranges, physical activity, and self-monitoring): https://www.nhlbi.nih.gov/sites/default/files/media/docs/obesity-evidence-review.pdf
- CDC, “Steps for Losing Weight” (gradual 1–2 lb/week loss): https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html
- NIDDK/NIH, research behind the Body Weight Planner (dynamic weight model and supported population): https://www.niddk.nih.gov/research-funding/at-niddk/labs-branches/laboratory-biological-modeling/integrative-physiology-section/research/body-weight-planner
- NHLBI/NIH, overweight and obesity diagnosis (BMI is a screening tool, not a diagnosis): https://www.nhlbi.nih.gov/health/overweight-and-obesity/symptoms
- WHO expert consultation discussion of Asian BMI action points (international cutoffs retained; 23 and 27.5 identified as action points): https://publications.iarc.who.int/_publications/media/download/4585/91d921510561a455bd4b0e290de6c89a11a3d3b9.pdf
- 2024 Adult Compendium of Physical Activities (MET definitions and activity values): https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/
- Stanford Medicine summary of wearable validation (energy expenditure error): https://med.stanford.edu/news/all-news/2017/05/fitness-trackers-accurately-measure-heart-rate-but-not-calories-burned.html
- CDC, “About Sleep” (age-specific sleep duration): https://www.cdc.gov/sleep/about/
- National Institute on Aging/NIH, “Calorie restriction and fasting diets: What do we know?” (definitions, evidence uncertainty, and clinical guidance): https://www.nia.nih.gov/news/calorie-restriction-and-fasting-diets-what-do-we-know
- Clinical review of fasting with diabetes (hypoglycaemia risk, medication adjustment, hydration, and groups for whom fasting is unsuitable): https://pmc.ncbi.nlm.nih.gov/articles/PMC6521152/
