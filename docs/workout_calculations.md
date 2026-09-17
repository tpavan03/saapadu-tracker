# Workout calorie calculations

The workout catalogue uses selected standard MET values from the [2024 Adult Compendium of Physical Activities](https://pacompendium.com/adult-compendium/). It includes walking, running, cycling, strength training, yoga, badminton, cricket, swimming, HIIT, football, stairs, elliptical training, and dance at common intensity levels.

The app calculates total session energy as:

```text
gross kcal = MET × current weight in kg × duration in minutes ÷ 60
```

The calorie ledger uses energy above rest because the daily calorie target already includes resting energy:

```text
active kcal = max(0, MET − 1) × current weight in kg × duration in minutes ÷ 60
```

The implementation stores the calculated active calories with each workout so a later weight change does not rewrite old workout history. The formula follows the weight-and-duration conversion illustrated by the [2024 Compendium publication](https://pmc.ncbi.nlm.nih.gov/articles/PMC11336313/).

MET values describe typical energy cost across groups and are not an exact personal measurement. Effort, fitness, terrain, technique, temperature, and device error can materially change actual energy expenditure.

## Preventing duplicate calorie credit

Steps, a manually entered fitness-watch total, and logged workouts can overlap. For each day the app takes the largest of those three active-energy estimates instead of adding them together. It then adds 50% of that estimate to the food budget. This conservative rule reduces double counting and wearable estimation error while still reflecting a substantial workout.

