---
version: alpha
colors:
  primary: '#145C47'
  ink: '#153C31'
  background: '#F2F7F4'
  surface: '#FFFFFF'
  accent: '#F3C56B'
  muted: '#61776C'
typography:
  display:
    fontFamily: 'Sora'
  body:
    fontFamily: 'DM Sans'
rounded:
  panel: '22px'
  feature: '32px'
  control: '16px'
spacing:
  unit: '8px'
components:
  card:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.ink}'
    rounded: '{rounded.panel}'
  button:
    backgroundColor: '{colors.primary}'
    textColor: '{colors.surface}'
    rounded: '{rounded.control}'
  timer:
    backgroundColor: '{colors.primary}'
    textColor: '{colors.accent}'
    rounded: '{rounded.feature}'
  caption:
    textColor: '{colors.muted}'
  page:
    backgroundColor: '{colors.background}'
---

# Saapadu

## Overview

A personal South Indian food diary and wellness tool. Preserve the familiar
green identity while giving daily routines the clarity of a thoughtfully laid
out meal: the energy ring is the plate, macros are its compartments, and every
action has a distinct place. This is a product interface, not a fitness advert.
The signature is an emerald circular timer/energy plate with saffron progress.
Avoid weight-loss promises, shame, calorie rewards for fasting, and generic
medical dashboards. India is the primary audience; English uses en-IN dates.

## Colors

The normative runtime owner is `AppColors` in `lib/theme.dart`. Above values map
directly to forest, ink, cream, paper, lime and muted respectively; `lime` retains
its legacy API name but is now saffron. Coral marks food/activity accents, blue
marks water, and neither color judges a person’s progress. Change tokens and
this document together. White cards sit on cool mint; deep green is reserved
for the most useful daily summary and active timer.

## Typography

Self-hosted DM Sans provides readable controls and meal names; Sora provides
restrained display headings and time/numeric highlights. Assets live in
`assets/fonts`, registered in `pubspec.yaml`. Flutter’s text theme owns the
mapping. Preserve platform fallback for Telugu and other user-entered scripts.

## Layout

PageFrame owns natural vertical scrolling, safe areas, 20px side padding and a
1120px maximum content width. At 900px the bottom navigation becomes a 232px
rail. Six destinations have the same order on both surfaces: Today, Diary,
Activity, Fasting, Progress, More. Pair related cards on wide screens and stack
them on phones. Lists remain readable at 390px; never hide primary actions.

## Elevation & Depth

Cards are flat, bordered and quietly rounded. Material sheets and dialogs may
use platform elevation. Do not scatter shadows or gradients across dashboard
metrics. Loading and save feedback reserve existing control geometry.

## Shapes

22px cards, 32px feature panels, and 16px controls follow the existing generous
shape language. Circular icon backgrounds identify habits. Material rounded
icons are the canonical icon set; they always have labels/tooltips for actions.

## Components

ThemeData owns shared cards, controls, chips, typography and scrollbar styles.
PageFrame, SectionEyebrow, MacroBar and CalorieRing are shared presentation.
Material AlertDialog/bottom sheets own confirmations and focus. Reduced-motion
settings use Material defaults; no decorative infinite animation is added.

## Do's and Don'ts

- Say “estimated goal” and “estimated budget”; a projected date is not a promise.
- Treat early fasting endings as valid history. Never label them failures.
- Keep optional fasting separate from calories and nutrition totals.
- Preserve meal, weight, activity and cloud histories during visual changes.
- Show source estimates and provide editable portions rather than implying precision.
