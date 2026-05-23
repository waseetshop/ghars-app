import 'package:flutter/material.dart';

/// غَرْس color palette — nature-inspired, built around the green calligraphy logo.
/// Light mode: Oasis Sand backgrounds, white cards, earth tones.
class GharsColors {
  // ── Backgrounds / Surfaces ──────────────────────────────────
  /// Oasis Sand — main scaffold background
  static const charcoal900 = Color(0xFFF9F9F6);
  /// White — card / sheet surface
  static const charcoal800 = Color(0xFFFFFFFF);
  /// Quartz Gray — input fill, subtle surface
  static const charcoal700 = Color(0xFFE4ECE5);
  /// Slightly deeper surface (disabled states)
  static const charcoal600 = Color(0xFFF0F4F1);
  /// Medium border / divider
  static const charcoal500 = Color(0xFFD6E0D8);

  // ── Brand Green (Ghars Green) ───────────────────────────────
  static const green      = Color(0xFF389E48);
  static const greenDark  = Color(0xFF2C7D38);
  static const greenFaint = Color(0xFFE9F5EB);

  // ── Premium Accent (Earth Gold) ────────────────────────────
  static const gold     = Color(0xFFCBA062);
  static const goldDim  = Color(0xFFA87E4A);
  static const goldGlow = Color(0xFFD4B676);

  // ── Legacy tint ────────────────────────────────────────────
  static const pink    = Color(0xFFD9A3AA);
  static const pinkDim = Color(0xFFB8848C);

  // ── Text ───────────────────────────────────────────────────
  /// Tree Bark — primary text on light background
  static const textPrimary   = Color(0xFF2C302E);
  /// Muted Olive — secondary text, labels
  static const textSecondary = Color(0xFF7B827A);
  /// Lighter olive — hints, meta text
  static const textMuted     = Color(0xFFADB5AB);

  // ── Plant Health ───────────────────────────────────────────
  static const healthy   = Color(0xFF389E48);  // Ghars Green
  static const stressed  = Color(0xFFE8C064);  // Morning Sun
  static const diseased  = Color(0xFFC76D59);  // Terracotta Red
  static const critical  = Color(0xFFB5432A);  // Deep Terracotta
  static const recovering = gold;              // Earth Gold
}
