import 'package:flutter/material.dart';

import 'onote_theme.dart';
import 'tokens.dart';

/// **One built-in appearance, as data.**
///
/// Until the theme catalogue (#12) this app had exactly two `ThemeData`s —
/// one light, one dark — handed to `MaterialApp` as `theme:` and
/// `darkTheme:`. That shape cannot hold a third appearance: every new theme
/// would need another field on `MaterialApp`, and "which theme does System
/// mode pick up" would stop having an answer.
///
/// An appearance here is a registry entry, not a branch in a switch: the
/// catalogue is a list of these, Settings persists the id, and `MaterialApp`
/// is handed whichever entries the id and the mode resolve to. Adding True
/// Black or a high-contrast variant later is adding a value to [appearances]
/// — no call site changes.
@immutable
class OnoteAppearance {
  const OnoteAppearance({
    required this.id,
    required this.brightness,
    required this.label,
    this.surfaces,
  });

  /// Stable, machine-readable, and persisted (`Settings → appearanceId`).
  /// Never rename a live id: a student's saved choice is a string, and
  /// renaming it silently reverts them to the default.
  final String id;

  /// Which brightness family this appearance belongs to. An appearance is
  /// concrete — it knows whether it is light or dark — so a mode that
  /// resolves to the other family falls back to that family's own entry
  /// rather than rendering a light theme in a dark slot.
  final Brightness brightness;

  /// The Settings row's caption. Plain English rather than a localisation
  /// key: the two existing appearances were never named anywhere a student
  /// could see them, and the catalogue's names are a design-review question
  /// (#12), not a translation question.
  final String label;

  /// The `ThemeData` this appearance paints with. Built on demand and not
  /// cached by the registry: `MaterialApp` already memoises against its
  /// theme arguments, so a second build with the same appearance is free
  /// without the registry holding theme objects alive.
  ThemeData buildTheme() => onoteTheme(brightness, surfaces: surfaces);

  /// The surface set this appearance paints with — its own, or null for the
  /// brightness family's default, which is the theme every caller before
  /// the catalogue got. True Black answers `OnoteSurfaces.trueBlack`; Light
  /// and Night ink answer null and keep the exact themes they always had.
  final OnoteSurfaces? surfaces;

  /// True when this is the brightness family's own default — what `System`
  /// resolves to when the chosen appearance belongs to the other family
  /// (see [appearanceFor]).
  bool get isFamilyDefault =>
      id == (brightness == Brightness.light ? 'light' : 'night-ink');
}

/// **The catalogue of built-in appearances, in Settings order.**
///
/// The registry #12 asks for, holding the two appearances that exist today
/// and nothing else — this change is the plumbing, not the palette. New
/// entries append here and nowhere else.
const List<OnoteAppearance> appearances = [
  OnoteAppearance(id: 'light', brightness: Brightness.light, label: 'Light'),
  OnoteAppearance(
      id: 'night-ink', brightness: Brightness.dark, label: 'Night ink'),
  // The OLED appearance — #12's headline request. Dark family, so a student
  // on Auto gets it only by choosing it; the family default above is what
  // Auto still resolves to.
  OnoteAppearance(
      id: 'true-black',
      brightness: Brightness.dark,
      label: 'True Black',
      surfaces: OnoteSurfaces.trueBlack),
];

/// The entry [id] names, or the light default for an id this build does not
/// know — a saved choice from a newer Openote must not crash an older one,
/// which is the same rule every settings read in `AppState.init` follows.
OnoteAppearance appearanceById(String? id) => appearances.firstWhere(
      (a) => a.id == id,
      orElse: () => appearances.first,
    );

/// **The appearance that serves the brightness [b], given the student's
/// choice [preferred].**
///
/// Their choice wins when it belongs to the family the mode resolved to;
/// otherwise the family's own DEFAULT serves — Night ink for dark, not True
/// Black, because a student who chose Light and set their computer to dark
/// asked for "a dark theme", not for the OLED look specifically. With two
/// dark entries in the catalogue this stops being academic: `firstWhere
/// (brightness == b)` would hand True Black to everybody on Auto.
OnoteAppearance appearanceFor(Brightness b, OnoteAppearance preferred) =>
    preferred.brightness == b
        ? preferred
        : appearances.firstWhere((a) => a.brightness == b && a.isFamilyDefault);

/// **The two `ThemeData`s `MaterialApp` is handed for [mode], given the
/// chosen [appearance].**
///
/// `MaterialApp` takes exactly one light and one dark theme and picks
/// between them by mode; that contract does not change with a catalogue —
/// what changes is which appearance fills each slot. With the two-entry
/// registry this resolves to the same pair the app has always been built
/// with, `onoteTheme(Brightness.light)` and `onoteTheme(Brightness.dark)`.
({ThemeData light, ThemeData dark}) themesForMode(
    ThemeMode mode, OnoteAppearance appearance) {
  // System mode follows the platform, as before; the concrete modes are the
  // student overriding it. Only System reads the platform brightness, and
  // only here — nothing else in the app needs to know how the mode resolves.
  final platformLight =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.light;
  final modeLight = switch (mode) {
    ThemeMode.system => platformLight,
    ThemeMode.light => true,
    ThemeMode.dark => false,
  };
  final chosen =
      appearanceFor(modeLight ? Brightness.light : Brightness.dark, appearance);
  return (
    light: appearanceFor(Brightness.light, chosen).buildTheme(),
    dark: appearanceFor(Brightness.dark, chosen).buildTheme(),
  );
}
