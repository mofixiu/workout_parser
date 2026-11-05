import 'dart:math' as math;

import 'data/exercises.g.dart';

/// A canonical exercise as far as matching is concerned.
class IndexedExercise {
  const IndexedExercise({
    required this.id,
    required this.name,
    this.equipment,
    this.curated = false,
    this.timed = false,
  });

  final String id;
  final String name;
  final String? equipment;
  final bool curated;

  /// Usually prescribed as a hold rather than reps (planks, wall sits).
  final bool timed;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (equipment != null) 'equipment': equipment,
      };

  @override
  String toString() => 'IndexedExercise($id)';
}

enum MatchStatus {
  /// The text is a known name or alias.
  exact,

  /// Close enough to trust, but not word for word.
  fuzzy,

  /// Several exercises fit. Ask the user which one they meant.
  uncertain,

  /// Nothing in the index fits. Treat it as a custom exercise.
  unmatched,
}

class MatchCandidate {
  const MatchCandidate(this.exercise, this.score);
  final IndexedExercise exercise;
  final double score;

  Map<String, Object?> toJson() => {'exercise': exercise.toJson(), 'score': score};
}

class ExerciseMatch {
  const ExerciseMatch({
    required this.status,
    required this.query,
    this.exercise,
    this.score = 0,
    this.candidates = const [],
  });

  final MatchStatus status;

  /// What you wrote, untouched.
  final String query;
  final IndexedExercise? exercise;
  final double score;

  /// Best alternatives, highest first, never including [exercise].
  final List<MatchCandidate> candidates;

  bool get needsReview => status == MatchStatus.uncertain || status == MatchStatus.unmatched;

  Map<String, Object?> toJson() => {
        'status': status.name,
        'query': query,
        if (exercise != null) 'exercise': exercise!.toJson(),
        'score': score,
        if (candidates.isNotEmpty) 'candidates': [for (final c in candidates) c.toJson()],
      };
}

/// Shorthand that people write in routines.
const _abbreviations = {
  'db': 'dumbbell',
  'dbs': 'dumbbell',
  'bb': 'barbell',
  'kb': 'kettlebell',
  'kbs': 'kettlebell',
  'ez': 'ez bar',
  'sm': 'smith machine',
  'bw': 'bodyweight',
  'ext': 'extension',
  'exts': 'extensions',
  'lat': 'lat',
  'tri': 'tricep',
  'tris': 'triceps',
  'bi': 'bicep',
  'bis': 'biceps',
  'sl': 'single leg',
  'sa': 'single arm',
  'oh': 'overhead',
  'inc': 'incline',
  'dec': 'decline',
  'w': 'with',
  'alt': 'alternating',
};

/// Real aliases that still name more than one movement. They resolve to the
/// most common variation but ask you to confirm it.
const _ambiguousAliases = {
  'dumbbell press',
  'db press',
  'press',
  'row',
  'rows',
  'raises',
  'fly',
  'flyes',
  'flys',
  'extension',
  'extensions',
};

const _equipmentWords = {
  'dumbbell',
  'barbell',
  'cable',
  'machine',
  'kettlebell',
  'band',
  'bands',
  'smith',
  'ez',
  'bodyweight',
  'leverage',
};

/// Lowercase, ASCII-ish, single spaces, hyphens as spaces.
String normalizeName(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll(RegExp(r'[’‘`]'), "'");
  s = s.replaceAll(RegExp(r'[-_/–—]'), ' ');
  s = s.replaceAll(RegExp(r"[^a-z0-9' ]"), ' ');
  s = s.replaceAll(RegExp(r"'s\b"), 's');
  s = s.replaceAll("'", '');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _expand(String normalized) =>
    normalized.split(' ').map((w) => _abbreviations[w] ?? w).join(' ');

String _singular(String normalized) => normalized
    .split(' ')
    .map(
      (w) =>
          w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w,
    )
    .join(' ');

/// Looks up exercises by alias, then by fuzzy similarity.
///
/// [ExerciseIndex.builtIn] knows the 884 exercises from free-exercise-db and
/// about 1,200 aliases people write in routines ("OHP", "RDL", "BB row").
/// Build your own to match against your app's exercise ids instead.
class ExerciseIndex {
  /// The bundled index. Built once, on first use.
  factory ExerciseIndex.builtIn() => _builtIn;
  static final _builtIn = ExerciseIndex(exercises: builtInExercises, aliases: builtInAliases);

  ExerciseIndex({
    required Iterable<IndexedExercise> exercises,
    required Map<String, String> aliases,
  }) {
    for (final e in exercises) {
      _byId[e.id] = e;
    }
    aliases.forEach((alias, id) {
      if (_byId.containsKey(id)) _aliases[normalizeName(alias)] = id;
    });
    for (final e in _byId.values) {
      _aliases.putIfAbsent(normalizeName(e.name), () => e.id);
    }
    _singularAliases = {for (final entry in _aliases.entries) _singular(entry.key): entry.value};
    _keys = [
      for (final MapEntry(:key, :value) in _aliases.entries)
        _Key(
          key,
          value,
          key.split(' ').map(_singular).toList(growable: false),
          key.split(' ').toSet().intersection(_equipmentWords),
          _byId[value]!.curated,
        ),
    ];
  }

  final _byId = <String, IndexedExercise>{};
  final _aliases = <String, String>{};
  late final Map<String, String> _singularAliases;
  late final List<_Key> _keys;

  /// Routines repeat names, and the parser asks about some lines twice.
  final _matches = <String, ExerciseMatch>{};
  static const _matchCacheSize = 1024;

  IndexedExercise? byId(String id) => _byId[id];
  Iterable<IndexedExercise> get all => _byId.values;

  /// Confident above this, uncertain between it and [_floor], unmatched below.
  static const _confident = .93;
  static const _floor = .72;

  ExerciseMatch match(String query) {
    final cached = _matches[query];
    if (cached != null) return cached;
    final result = _match(query);
    if (_matches.length >= _matchCacheSize) _matches.clear();
    return _matches[query] = result;
  }

  ExerciseMatch _match(String query) {
    final normalized = normalizeName(query);
    if (normalized.isEmpty) {
      return ExerciseMatch(status: MatchStatus.unmatched, query: query);
    }
    final expanded = _expand(normalized);
    for (final key in [normalized, expanded]) {
      final id = _aliases[key] ?? _singularAliases[_singular(key)];
      if (id != null) {
        final ambiguous = _ambiguousAliases.contains(normalized) || _ambiguousAliases.contains(key);
        return ExerciseMatch(
          status: ambiguous ? MatchStatus.uncertain : MatchStatus.exact,
          query: query,
          exercise: _byId[id],
          score: 1,
          candidates: _ranked(expanded, exclude: id).take(3).toList(),
        );
      }
    }

    final ranked = _ranked(expanded).toList();
    if (ranked.isEmpty || ranked.first.score < _floor) {
      return ExerciseMatch(
        status: MatchStatus.unmatched,
        query: query,
        candidates: ranked.where((c) => c.score >= .5).take(3).toList(),
      );
    }
    final best = ranked.first;
    final runnerUp = ranked.length > 1 ? ranked[1].score : 0.0;
    // A clear winner well above the next option is safe to accept.
    final confident = best.score >= _confident && best.score - runnerUp > .03;
    return ExerciseMatch(
      status: confident ? MatchStatus.fuzzy : MatchStatus.uncertain,
      query: query,
      exercise: best.exercise,
      score: best.score,
      candidates: ranked.skip(1).take(3).toList(),
    );
  }

  /// Free-text search, for a "pick another exercise" list.
  List<IndexedExercise> search(String query, {int limit = 30}) {
    final q = _expand(normalizeName(query));
    if (q.isEmpty) return const [];
    return _ranked(
      q,
      substringBoost: true,
    ).where((c) => c.score > .55).take(limit).map((c) => c.exercise).toList();
  }

  Iterable<MatchCandidate> _ranked(String query, {String? exclude, bool substringBoost = false}) {
    final best = <String, double>{};
    final queryEquipment = query.split(' ').toSet().intersection(_equipmentWords);
    final queryTokens = query.split(' ').map(_singular).toList(growable: false);
    // Key words repeat across ~2,000 names ("press", "dumbbell"), so each
    // word-to-word score is worked out once per query.
    final forwardMemo = <String, double>{};
    final backwardMemo = <String, double>{};
    for (final k in _keys) {
      final id = k.id;
      if (id == exclude) continue;
      var score = query == k.key
          ? 1.0
          : _blend(jaroWinkler(query, k.key), queryTokens, k.tokens, forwardMemo, backwardMemo);
      if (substringBoost && k.key.contains(query)) score = math.max(score, .9);
      // "dumbbell press" must not quietly become a barbell lift.
      if (queryEquipment.isNotEmpty &&
          k.equipment.isNotEmpty &&
          queryEquipment.intersection(k.equipment).isEmpty) {
        score *= .78;
      }
      if (k.curated) score += .015;
      if (score > (best[id] ?? 0)) best[id] = score;
    }
    final list = best.entries
        .map((e) => MatchCandidate(_byId[e.key]!, math.min(e.value, 1)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list;
  }
}

class _Key {
  const _Key(this.key, this.id, this.tokens, this.equipment, this.curated);
  final String key;
  final String id;
  final List<String> tokens;
  final Set<String> equipment;
  final bool curated;
}

/// Blend of whole-string Jaro-Winkler and a soft token overlap, in 0..1.
double similarity(String a, String b) {
  if (a == b) return 1;
  return _blend(
    jaroWinkler(a, b),
    a.split(' ').map(_singular).toList(),
    b.split(' ').map(_singular).toList(),
  );
}

double _blend(
  double whole,
  List<String> ta,
  List<String> tb, [
  Map<String, double>? forwardMemo,
  Map<String, double>? backwardMemo,
]) {
  double soft(List<String> from, List<String> to, Map<String, double>? memo) {
    var sum = 0.0;
    for (final t in from) {
      var m = 0.0;
      for (final u in to) {
        final double s;
        if (t == u) {
          s = 1.0;
        } else if (memo == null) {
          s = jaroWinkler(t, u);
        } else {
          s = memo['$t\u0000$u'] ??= jaroWinkler(t, u);
        }
        if (s > m) m = s;
      }
      // Near misses on short words ("row" vs "raw") count for little.
      sum += m >= .88 ? m : m * .4;
    }
    return from.isEmpty ? 0 : sum / from.length;
  }

  final forward = soft(ta, tb, forwardMemo);
  final backward = soft(tb, ta, backwardMemo);
  final tokens = (forward * .55 + backward * .45);
  return whole * .35 + tokens * .65;
}

double jaroWinkler(String s1, String s2) {
  if (s1 == s2) return 1;
  if (s1.isEmpty || s2.isEmpty) return 0;
  final range = math.max(0, math.max(s1.length, s2.length) ~/ 2 - 1);
  final m1 = List<bool>.filled(s1.length, false);
  final m2 = List<bool>.filled(s2.length, false);
  var matches = 0;
  for (var i = 0; i < s1.length; i++) {
    final start = math.max(0, i - range);
    final end = math.min(i + range + 1, s2.length);
    for (var j = start; j < end; j++) {
      if (m2[j] || s1[i] != s2[j]) continue;
      m1[i] = m2[j] = true;
      matches++;
      break;
    }
  }
  if (matches == 0) return 0;
  var t = 0;
  var k = 0;
  for (var i = 0; i < s1.length; i++) {
    if (!m1[i]) continue;
    while (!m2[k]) {
      k++;
    }
    if (s1[i] != s2[k]) t++;
    k++;
  }
  final m = matches.toDouble();
  final jaro = (m / s1.length + m / s2.length + (m - t / 2) / m) / 3;
  var prefix = 0;
  for (var i = 0; i < math.min(4, math.min(s1.length, s2.length)); i++) {
    if (s1[i] != s2[i]) break;
    prefix++;
  }
  return jaro + prefix * .1 * (1 - jaro);
}
