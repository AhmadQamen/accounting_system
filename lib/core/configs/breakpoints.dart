/// Central layout sizing for the adaptive desktop shell and feature pages.
///
/// Breakpoints are based on the *available* window/content width. Keep them
/// here so the shell, dashboard and feature grids make the same decisions.
abstract final class Breakpoints {
  static const double sidebarWidth = 240;
  static const double sidebarCollapsedWidth = 76;
  static const double topBarHeight = 54;
  static const double contentMaxWidth = 1440;

  /// Full navigation with labels.
  static const double expandedSidebar = 1180;

  /// Two-column content generally becomes one column below this width.
  static const double tablet = 820;

  /// Compact page spacing / stacked controls.
  static const double compact = 620;

  /// Kept for backward compatibility with older code.
  static const double desktop = 600;
}
