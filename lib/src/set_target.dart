/// What kind of goal one prescribed set has.
enum TargetKind { reps, range, failure, duration }

/// Where a value came from.
///
/// [explicit] values were written in the text. [suggested] values were
/// filled in by the parser from context ("Plank 3 × 30" becomes 30 seconds).
/// [defaulted] values come from the parser's defaults because nothing was
/// written. Show anything that is not [explicit] to the user so they can
/// check it.
enum Provenance { explicit, suggested, defaulted }

enum WeightUnit { kg, lb }

/// What one prescribed set asks for: a rep count, a rep range, a set to
/// failure or a timed hold.
class SetTarget {
  const SetTarget._({
    required this.kind,
    this.repsMin,
    this.repsMax,
    this.durationSeconds,
  });

  const SetTarget.reps(int reps) : this._(kind: TargetKind.reps, repsMin: reps, repsMax: reps);

  const SetTarget.range(int min, int max)
      : this._(kind: TargetKind.range, repsMin: min, repsMax: max);

  const SetTarget.failure() : this._(kind: TargetKind.failure);

  const SetTarget.duration(int seconds)
      : this._(kind: TargetKind.duration, durationSeconds: seconds);

  final TargetKind kind;
  final int? repsMin;
  final int? repsMax;
  final int? durationSeconds;

  bool get isTimed => kind == TargetKind.duration;

  /// "10 reps", "8–12 reps", "to failure", "45 sec".
  String get label => switch (kind) {
        TargetKind.reps => '$repsMin reps',
        TargetKind.range => '$repsMin–$repsMax reps',
        TargetKind.failure => 'to failure',
        TargetKind.duration => formatSeconds(durationSeconds!),
      };

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        if (repsMin != null) 'repsMin': repsMin,
        if (repsMax != null) 'repsMax': repsMax,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      };

  @override
  bool operator ==(Object other) =>
      other is SetTarget &&
      other.kind == kind &&
      other.repsMin == repsMin &&
      other.repsMax == repsMax &&
      other.durationSeconds == durationSeconds;

  @override
  int get hashCode => Object.hash(kind, repsMin, repsMax, durationSeconds);

  @override
  String toString() => 'SetTarget($label)';
}

/// "45 sec", "1:30", "2 min". [compact] gives "45s", "1:30", "2m".
String formatSeconds(int seconds, {bool compact = false}) {
  if (seconds < 60) return compact ? '${seconds}s' : '$seconds sec';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (s == 0) return compact ? '${m}m' : '$m min';
  return '$m:${s.toString().padLeft(2, '0')}';
}
