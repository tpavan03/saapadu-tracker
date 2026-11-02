---
version: alpha
colors:
  primary: '#A2DDC2'
  ink: '#F4F2E9'
  background: '#091719'
  surface: '#12292B'
  accent: '#E9BE75'
  muted: '#AAC1BB'
  hero: '#173F40'
  onAccent: '#09201B'
  line: '#2D4848'
  dangerSurface: '#713D35'
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
    textColor: '{colors.onAccent}'
    rounded: '{rounded.control}'
  timer:
    backgroundColor: '{colors.hero}'
    textColor: '{colors.accent}'
    rounded: '{rounded.feature}'
  caption:
    textColor: '{colors.muted}'
  page:
    backgroundColor: '{colors.background}'
  destructiveSwipe:
    backgroundColor: '{colors.dangerSurface}'
    textColor: '{colors.ink}'
  divider:
    backgroundColor: '{colors.line}'
---

# Saapadu

## Overview

A personal South Indian food diary and wellness tool, now built for a native
phone routine. The visual direction is an after-hours kitchen: deep teal,
rice-colored type, green leaves and warm brass. Its signature is the open
saffron energy plate with three small rice-grain marks, paired with an original
steaming bowl wordmark. Keep the surrounding workspace quiet and practical.
This is a product interface, not a fitness advert.
Avoid weight-loss promises, shame, calorie rewards for fasting, and generic
medical dashboards. India is the primary audience; English uses en-IN dates.

## Colors

The normative runtime owner is `AppColors` in `lib/theme.dart`. Above values map
directly to forest, ink, cream, paper, lime, muted, hero, onAccent and line;
`lime` retains its legacy API name but is saffron. `forest` and `ink` are
foregrounds. Feature backgrounds must use `hero`, and text/icons on filled
saffron or mint controls use `onAccent`; never reuse a foreground token as a
hero background. Pale coral #F3AC93 marks food/activity, blue #A0D3ED marks water,
and lavender #C5B9EA marks sleep. Neither color judges a person’s progress.
Destructive swipe surfaces use the separate dark clay dangerSurface #713D35
with light icons; the pale coral foreground is not used as a white-icon fill.
Change tokens and this document together. The native workspace is dark by
default, including dialogs, pickers, menus, sheets, keyboard-facing forms and
navigation; no stray white cards or neon glow.

## Typography

Self-hosted DM Sans provides readable controls and meal names; Sora provides
restrained display headings and time/numeric highlights. Assets live in
`assets/fonts`, registered in `pubspec.yaml`. Flutter’s text theme owns the
mapping. Preserve platform fallback for Telugu and other user-entered scripts.

## Layout

PageFrame owns natural vertical scrolling, safe areas, 20px side padding and a
1120px maximum content width. Its owned scroll controller gives every page a
visible, usable scrollbar. At 900px the bottom navigation becomes a 232px
rail. Six destinations have the same order on both surfaces: Today, Diary,
Activity, Fasting, Progress, More. Pair related cards on wide screens and stack
them on phones. An IndexedStack preserves each destination's scroll and local
view state when switching tabs. Lists remain readable at 320px and larger text;
never hide primary actions. The wordmark may fit its available width, while
functional text wraps and retains the user's text scale. Wellness signal cards
become one column when narrow or when larger text needs the room.

## Elevation & Depth

Cards are flat, bordered and quietly rounded. Feature panels use the deeper
teal surface without scattered gradients or decorative lighting. Material sheets and dialogs may
use platform elevation. Do not scatter shadows or gradients across dashboard
metrics. Loading and save feedback reserve existing control geometry.

## Shapes

22px cards, 28–32px feature panels, and 16px controls follow the existing generous
shape language. Circular icon backgrounds identify habits. Material rounded
icons are the canonical icon set; they always have labels/tooltips for actions.

## Components

ThemeData owns shared cards, controls, chips, typography and scrollbar styles.
PageFrame, SaapaduMark, SectionEyebrow, MacroBar and CalorieRing are shared presentation.
The original SaapaduMark is a cooking bowl, rising steam and rice grains rather
than a generic medical or fitness symbol. CalorieRing is an accessible visual
of logged intake against the estimated budget; it never invents completion or
calls an over-budget day a failure. Today's weekly check-in card navigates to
the actual Progress workflow and derives its due state from saved readings.
Material AlertDialog/bottom sheets own confirmations and focus. Reduced-motion
settings use Material defaults; no decorative infinite animation is added.

## Do's and Don'ts

- Say “estimated goal” and “estimated budget”; a projected date is not a promise.
- Treat early fasting endings as valid history. Never label them failures.
- Keep optional fasting separate from calories and nutrition totals.
- Preserve meal, weight, activity and cloud histories during visual changes.
- Show source estimates and provide editable portions rather than implying precision.
