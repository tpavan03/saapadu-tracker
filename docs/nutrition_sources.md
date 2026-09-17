# Nutrition seed data: sources and limits

`assets/data/south_indian_foods.json` is an offline starter catalogue for meal logging. It contains 141 common South Indian and basic Indian foods. Nutrient values are for the named serving, not per 100 g, unless `servingLabel` explicitly says `100 g`.

## Source key map

| `sourceKey` | Meaning |
| --- | --- |
| `IFCT2017_SCALED` | A simple food or ingredient value based primarily on ICMR-NIN Indian Food Composition Tables 2017 and scaled to the stated edible serving mass. |
| `USDA_FDC_SCALED` | A simple food value based on USDA FoodData Central Foundation/SR/FNDDS data and scaled to the stated serving mass. This is mainly used for cooked staples, fruit, milk, eggs, and other foods where a familiar edible serving is represented directly in FoodData Central. |
| `IFCT_RECIPE_ESTIMATE` | A calculated household-recipe estimate. Ingredient nutrient values are based primarily on IFCT 2017; customary ingredient proportions, cooking yield, oil, and the stated serving mass were applied. This is not an analysed IFCT value for the finished dish. |
| `IFCT_USDA_RECIPE_ESTIMATE` | A calculated recipe estimate that uses both IFCT ingredient values and a USDA cooked-food or yield match. |

## Primary references

1. Longvah T, Ananthan R, Bhaskarachary K, Venkaiah K. *Indian Food Composition Tables 2017*. ICMR-National Institute of Nutrition, Hyderabad. Official full text: <https://www.nin.res.in/ebooks/IFCT2017.pdf>. A searchable official copy is available at <https://www.nin.res.in/ebooks/IFCT2017_16122024.pdf>.
2. ICMR-NIN Expert Committee. *Dietary Guidelines for Indians 2024*. Official PDF: <https://www.nin.res.in/dietaryguidelines/pdfjs/locale/DGI24thJune2024fin.pdf>. The guideline's food-group examples and Indian household measures informed food selection and reasonable portion ranges; they are not the direct source of every nutrient value.
3. USDA Agricultural Research Service. *FoodData Central*. Data documentation: <https://fdc.nal.usda.gov/data-documentation/>. Downloadable datasets: <https://fdc.nal.usda.gov/download-datasets/>.
4. FAO/INFOODS. *Standards and Guidelines*: <https://www.fao.org/infoods/infoods/standards-guidelines/en/>. Recipe calculation resources: <https://www.fao.org/infoods/infoods/recipes/en/>. These references informed food matching, unit conversion, and the decision to identify calculated recipes separately from analysed foods.

IFCT 2017 is the preferred reference because its sampling and foods are Indian. It reports 528 foods and more than 150 food components. With limited exceptions noted in IFCT, its entries describe raw foods. A cooked mixed dish therefore cannot be treated as though IFCT directly analysed the app's particular idli, dosa, sambar, or curry recipe.

## Estimation method

- `calories`, `proteinG`, `carbsG`, `fatG`, and `fiberG` describe one `servingLabel` weighing approximately `servingGrams`.
- Simple-food values were converted from the reference amount to the listed serving and rounded for practical logging.
- Mixed dishes were estimated from a representative home recipe: edible ingredient weights were combined, visible oil/ghee was included, and the cooked yield was divided into household servings.
- `calories` may not exactly equal `4 × protein + 4 × carbohydrate + 9 × fat`. Published energy factors, fibre treatment, organic acids, alcohols, and rounding can produce differences.
- Aliases are search terms, not separate nutrient records. Regional spelling and recipe names can refer to materially different preparations.

## Product limitations

These values are useful defaults, not laboratory results for the user's actual plate. Rice-to-dal ratio, fermentation, coconut, sugar, meat cut, absorbed frying oil, and serving size can change calories substantially. Restaurant dosa, biryani, parotta, fried snacks, sweets, chutney, and curries often vary the most. The app should let users change grams, save a custom recipe, and prefer a package label for branded foods.

The dataset does not represent a therapeutic diet and should not be used to dose medication or manage a medical condition without a qualified clinician. For commercial redistribution, confirm the current reuse terms of each upstream publication and preserve source attribution.

## Maintenance checks

When changing this file:

1. Keep `id` stable and unique.
2. Keep all nutrient values non-negative and numeric.
3. State the serving in both plain language and grams.
4. Use `*_SCALED` only for a close food match. Use a recipe-estimate key for mixed dishes.
5. Review extreme calorie-density values and compare calories with the protein/carbohydrate/fat totals.
6. Record new upstream references here before adding a new `sourceKey`.
