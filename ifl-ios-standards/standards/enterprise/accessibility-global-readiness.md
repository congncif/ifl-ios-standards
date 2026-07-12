# Accessibility and Global Readiness

Owner: Accessibility Owner  
Requirement: `ENT-ACCESSIBILITY`  
Profile: `core`  
Rationale: `ADR-0005`

## 1. Purpose

Ensure iOS experiences remain understandable and operable across assistive technologies, content sizes, motion preferences, input methods, languages, scripts, directions, and locales. Preserve the humble-View boundary: the Presenter or equivalent mapper owns semantic formatting and display-ready copy, while Views own platform accessibility and rendering mechanics over those prepared values.

## 2. Applicability

Apply to every customer-visible screen, system extension, notification, widget, reusable component, navigation flow, text and media surface, custom gesture, animation, chart, form, error, and localized resource. Include equivalent UIKit and SwiftUI behavior. Reassess when interaction, layout, copy, semantic grouping, navigation order, locale support, or platform accessibility APIs change.

## 3. Non-negotiable rules

- `A11Y-VOICE-001`: provide meaningful VoiceOver semantics, grouping, traits, values, actions, and order; hide purely decorative content.
- `A11Y-TYPE-001`: use Dynamic Type and layouts that remain usable at supported accessibility sizes without clipping essential content.
- `A11Y-CONTRAST-001`: meet the organization's current approved WCAG AA contrast targets and never use color as the only carrier of meaning.
- `A11Y-MOTION-001`: respect Reduce Motion and provide an equivalent non-motion path for information and actions.
- `A11Y-FOCUS-001`: maintain logical reading and focus order and restore focus after meaningful UI transitions.
- `A11Y-INPUT-001`: make every action available without a precision-only gesture and support applicable keyboard, switch, voice, and assistive input.
- `I18N-LOCALIZE-001`: keep user-facing copy in the localization system with owned, stable semantic keys.
- `I18N-PLURAL-001`: express plurals and grammatical variants through locale-aware resources, never string concatenation.
- `I18N-RTL-001`: use semantic direction and intentionally mirror or preserve directional assets and layout.
- `I18N-FORMAT-001`: format raw dates, numbers, currency, measurements, names, lists, and errors through the Presenter or equivalent locale-aware mapper before the View renders them.

## 4. Decision guidance

Design the semantic experience before applying framework modifiers. Ask what an element is, what value and state it communicates, what action it performs, and where it belongs in reading and focus order. Prefer native controls and semantic text styles. Treat maximum content sizes, long translations, RTL, reduced motion, and non-touch input as normal operating conditions.

Do not move domain values or formatting into a View to access a convenient formatter. The Presenter or equivalent mapper supplies localized display-ready text and semantic state. UIKit and SwiftUI Views apply platform mechanics such as labels, traits, focus, actions, layout, and reduced-motion rendering to that state.

## 5. Implementation patterns

### Semantic controls and focus

Use native controls when possible. For custom composites, expose one meaningful element or an intentional group, with label, value, hint only when needed, state, traits, and typed accessibility actions. Keep reading order consistent with meaning rather than visual implementation order. Move or restore focus after modal presentation, navigation, validation, asynchronous replacement, and destructive actions.

### Content size, contrast, motion, and input

Use semantic text styles and scalable metrics. Let layouts wrap and grow, avoid fixed heights around text, and preserve essential controls at accessibility sizes. Meet approved contrast thresholds in every state and pair color with text, shape, iconography, or pattern. Under Reduce Motion, replace spatial or continuous motion with crossfade or immediate state changes while preserving sequence and outcome. Expose alternatives for drag, swipe, hover, multi-finger, or timed gestures.

### Localization and formatting

Store user-facing text in String Catalogs or the approved localization system. Use semantic keys, developer context, substitutions, plural variations, and grammatical agreement. Use leading/trailing and directional APIs rather than left/right assumptions. The presentation mapper selects locale-aware date, number, currency, measurement, person-name, list, and error representations; the View receives final strings or structured display-ready tokens.

## 6. Compliant and non-compliant examples

Compliant:

- A Presenter supplies a localized price and accessibility value; UIKit and SwiftUI apply their platform semantics without reformatting the amount.
- A custom quantity control exposes increment and decrement accessibility actions and remains operable by keyboard and Switch Control.
- A layout grows at accessibility text sizes and moves secondary content below the primary action instead of clipping it.
- An RTL layout uses semantic alignment and preserves a media-play icon whose meaning must not mirror.

Non-compliant:

- A View receives a `Decimal` and formats currency inside `body` or `render`.
- An icon-only control has no accessible name or relies on its asset filename.
- Text is fixed at one size inside a fixed-height row.
- Error state is communicated only by red color or a shake animation.
- A sentence or plural is assembled by concatenating localized fragments.
- Layout logic assumes left always means start or next.

## 7. Anti-patterns

- Adding accessibility labels as a release-end patch without reviewing semantics and order.
- Duplicating visible text and accessibility text so VoiceOver reads the same meaning twice.
- Hiding a difficult control from accessibility instead of making it operable.
- Treating screenshot similarity as proof of Dynamic Type or RTL support.
- Forcing animation despite Reduce Motion because it is part of brand identity.
- Hard-coding copy, plural forms, locale, calendar, currency, or measurement units in Views.
- Sending raw domain values to Views under the name “flexibility.”

## 8. Verification

The single final joined AI consistency review confirms all ten Rules, chapter/ADR/profile ownership, and dependencies on the humble-View and UIKit/SwiftUI display-ready semantics. It checks that guidance covers VoiceOver, Dynamic Type, contrast, reduced motion, focus, alternate input, localization, plurals, RTL, and locale formatting, while keeping semantic formatting outside Views. Runtime accessibility, localization, and layout behavior remain subject to the consuming repository's ordinary tests and manual platform evaluation; CI operation is outside this plugin.

## 9. Exceptions

An exception identifies the exact Rule, affected user capability, screen and versions, reason native behavior cannot be met, equivalent access path, owner, approving Accessibility authority, expiry, review event, and removal plan. Exceptions cannot waive access to an essential task or move presentation formatting into a View. Legal or policy interpretations require the designated human authority.

## 10. Migration and adoption

Inventory screens, custom controls, gestures, fixed layouts, animations, focus transitions, hard-coded copy, concatenated strings, directional assumptions, and in-View formatting. Fix blocked essential tasks and missing semantics first. Then adopt semantic text styles and flexible layout, reduced-motion variants, focus restoration, alternate actions, String Catalogs, plural resources, RTL-safe layout, and Presenter-owned locale formatting. Migrate reusable components before one-off screens to reduce repeated defects.

## 11. Ownership

The Accessibility Owner owns this chapter, interpretation, review practice, and exceptions. Feature and design owners own semantic experience and remediation. Localization owners manage catalogs, translation context, locale coverage, and linguistic quality. Presentation owners keep formatting in Presenter-equivalent boundaries. UIKit and SwiftUI component owners implement equivalent platform mechanics.

## 12. Metrics

Track critical flows evaluated with VoiceOver and alternate input, controls missing semantic names or actions, screens usable at supported accessibility sizes, contrast defects, motion paths without reduced variants, focus defects, hard-coded user copy, concatenated plurals, RTL regressions, locale-formatting performed outside presentation mappers, and accessibility exceptions nearing expiry. Prefer outcome and coverage metrics over raw modifier counts.

## 13. Review cadence

Review at least quarterly and before release when critical flows, design systems, supported locales, localization tooling, custom controls, navigation, animation, or platform accessibility APIs change. Evaluate active exceptions before expiry and promptly after user-reported access barriers or changes to organizational accessibility targets.
