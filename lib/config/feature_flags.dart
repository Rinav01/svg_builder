/// Global feature flags controlling experimental or platform-specific modules.
class FeatureFlags {
  /// Toggle for real-time CRDT peer collaboration.
  /// Kept false while prioritizing the core Android tablet stylus & vector authoring experience.
  static const bool enableCollaboration = false;
}
