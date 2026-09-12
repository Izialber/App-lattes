/// Breakpoints responsivos únicos para todo o app (ver ARQUITETURA.md,
/// seção "Estratégia responsiva"). Nunca usar valores mágicos de largura
/// fora daqui — qualquer novo breakpoint entra nesta classe.
class Breakpoints {
  Breakpoints._();

  static const double compactMax = 599;
  static const double mediumMax = 1023;
  static const double expandedMax = 1919;
  // >= 1920 => large

  static const double minTouchTarget = 48.0;
  static const double maxContentWidthLarge = 1600.0;
}

enum ScreenSize { compact, medium, expanded, large }

ScreenSize screenSizeFor(double width) {
  if (width <= Breakpoints.compactMax) return ScreenSize.compact;
  if (width <= Breakpoints.mediumMax) return ScreenSize.medium;
  if (width <= Breakpoints.expandedMax) return ScreenSize.expanded;
  return ScreenSize.large;
}
