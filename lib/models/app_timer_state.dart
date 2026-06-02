enum BlockerPhase {
  /// Screen Time not yet authorized.
  unauthorized,

  /// YouTube is blocked — user hasn't triggered a wait yet.
  idle,

  /// Waiting 10 minutes before access is granted.
  countdown,

  /// YouTube is unlocked; access window ticking down.
  accessible,
}
