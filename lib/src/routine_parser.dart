import 'dart:math' as math;

import 'set_target.dart';
import 'exercise_index.dart';
import 'parsed_routine.dart';

/// Reads pasted workout text into days, exercises and set targets.
///
/// Deterministic and offline: normalise each line, classify it (day heading,
/// exercise, rest, note, superset marker), pull out sets/reps/time/weight/rest/
/// tempo with a small grammar, then match the name against the library.
/// Anything the parser fills in itself is marked with a non-explicit
/// [Provenance], so you can show the user what to check.
///
/// ```dart
/// final routine = RoutineParser().parse('Squat 5x5 @ 100kg, rest 3 min');
/// ```
class RoutineParser {
  /// Uses [ExerciseIndex.builtIn] unless you pass your own [index].
  RoutineParser({
    ExerciseIndex? index,
    this.defaultSets = 3,
    this.defaultRestSeconds = 90,
    this.defaultUnit = WeightUnit.kg,
  }) : index = index ?? ExerciseIndex.builtIn();

  final ExerciseIndex index;

  /// Sets to suggest when a line gives reps or a range but no set count.
  final int defaultSets;

  /// Rest to fill in when none is written. Pass null to leave it empty.
  final int? defaultRestSeconds;

  /// Unit for a bare weight such as "@ 60".
  final WeightUnit defaultUnit;

  /// Reads [text] into a [ParsedRoutine]. Never throws on odd input: lines it
  /// cannot read end up in [ParsedRoutine.issues] or [ParsedRoutine.notes].
  ParsedRoutine parse(String text) {
    final days = <_DayBuilder>[];
    final notes = <String>[];
    final issues = <ParseIssue>[];
    final usedGroups = <String>{};
    String? openGroup;
    int? openRounds;

    _DayBuilder currentDay() {
      if (days.isEmpty) days.add(_DayBuilder('Workout'));
      return days.last;
    }

    String nextGroup() {
      for (var c = 65; c < 91; c++) {
        final letter = String.fromCharCode(c);
        if (usedGroups.add(letter)) return letter;
      }
      return 'Z';
    }

    for (final raw in text.split(RegExp(r'\r?\n'))) {
      var line = raw.trim();
      if (line.isEmpty) {
        openGroup = null;
        openRounds = null;
        continue;
      }

      var heading = false;
      if (line.startsWith('#')) {
        heading = true;
        line = line.replaceFirst(RegExp(r'^#+\s*'), '');
      }
      line = line.replaceAll(RegExp(r'\*\*|__'), '').trim();

      String? label;
      final labelMatch = RegExp(r'^([A-Ha-h])\s?([1-9])\s*[.):\-]?\s+').firstMatch(line);
      if (labelMatch != null) {
        label = labelMatch.group(1)!.toUpperCase();
        usedGroups.add(label);
        line = line.substring(labelMatch.end);
      }
      line = line.replaceFirst(RegExp(r'^(?:[-•*·▪●◦>–—]+|\d{1,2}[.)]|\(\d{1,2}\))\s*'), '').trim();
      if (line.isEmpty) continue;

      final lower = _fold(line);

      if (RegExp(r'^(super\s?set|ss|circuit|giant\s?set|tri\s?set)\b').hasMatch(lower) &&
          !_setsPattern.hasMatch(lower)) {
        openGroup = nextGroup();
        continue;
      }

      final rounds = RegExp(r'^(\d+)\s*(?:rounds?|sets?)(?:\s+of)?\s*:?$').firstMatch(lower);
      if (rounds != null) {
        openRounds = _int(rounds.group(1))!.clamp(1, 20);
        continue;
      }

      final restOnly = RegExp(
        r'^(?:then\s+)?rest\b[^a-z]*(?:sec|secs|seconds|s|min|mins|minutes|m)?[^a-z]*(?:between.*)?$',
      ).hasMatch(lower);
      if (restOnly) {
        final rest = _extractRest(lower);
        final day = days.isEmpty ? null : days.last;
        if (rest != null && day != null && day.exercises.isNotEmpty) {
          final last = day.exercises.removeLast();
          day.exercises.add(
            last.copyWith(restSeconds: rest.seconds, restFrom: Provenance.explicit),
          );
        } else if (rest == null) {
          issues.add(ParseIssue(line: raw.trim(), message: 'Rest without a length. Add a time.'));
        }
        continue;
      }

      if (RegExp(r'^(note|notes|tip|tips|coach|cue|cues)\b\s*[:\-]').hasMatch(lower) ||
          (line.startsWith('(') && line.endsWith(')'))) {
        final note = line
            .replaceFirst(RegExp(r'^[^:\-]*[:\-]\s*'), '')
            .replaceAll(RegExp(r'^\(|\)$'), '')
            .trim();
        final day = days.isEmpty ? null : days.last;
        if (day != null && day.exercises.isNotEmpty) {
          final last = day.exercises.removeLast();
          day.exercises.add(
            last.copyWith(notes: [if (last.notes != null) last.notes!, note].join(' · ')),
          );
        } else {
          notes.add(note);
        }
        continue;
      }

      final hasParams = _setsPattern.hasMatch(lower) ||
          _durationPattern.hasMatch(lower) ||
          RegExp(r'\b(failure|amrap)\b').hasMatch(lower);

      if (!hasParams) {
        if (heading || _isStrongHeading(lower, line)) {
          days.add(_DayBuilder(_cleanHeading(line)));
          openGroup = null;
          continue;
        }
        final match = index.match(line);
        final words = lower.split(' ').length;
        if (words <= 6 &&
            (match.status == MatchStatus.exact || match.status == MatchStatus.fuzzy)) {
          currentDay().exercises.add(
                _build(
                  line: raw.trim(),
                  lower: lower,
                  original: line,
                  group: label ?? openGroup,
                  rounds: openRounds,
                ),
              );
          continue;
        }
        if (words <= 4 && _isSoftHeading(lower)) {
          days.add(_DayBuilder(_cleanHeading(line)));
          openGroup = null;
          continue;
        }
        if (words > 6 || RegExp(r'[.!?:]$').hasMatch(line)) {
          notes.add(line);
        } else {
          issues.add(
            ParseIssue(
              line: raw.trim(),
              message: "No sets, reps or time found. Add them, or add this as an exercise.",
            ),
          );
        }
        continue;
      }

      final parsed = _build(
        line: raw.trim(),
        lower: lower,
        original: line,
        group: label ?? openGroup,
        rounds: openRounds,
      );

      // "Curls + pushdowns 3 × 12" is a superset written on one line.
      final parts = parsed.typedName.split(RegExp(r'\s+(?:\+|&|and|with)\s+'));
      if (parts.length > 1 && parts.every((p) => index.match(p).status != MatchStatus.unmatched)) {
        final group = parsed.group ?? nextGroup();
        for (final part in parts) {
          currentDay().exercises.add(
                ParsedExercise(
                  line: parsed.line,
                  typedName: part.trim(),
                  match: index.match(part),
                  sets: parsed.sets,
                  setsFrom: parsed.setsFrom,
                  target: parsed.target,
                  targetFrom: parsed.targetFrom,
                  perSetReps: parsed.perSetReps,
                  weight: parsed.weight,
                  unit: parsed.unit,
                  restSeconds: parsed.restSeconds,
                  restFrom: parsed.restFrom,
                  tempo: parsed.tempo,
                  group: group,
                  perSide: parsed.perSide,
                  notes: parsed.notes,
                ),
              );
        }
        continue;
      }
      currentDay().exercises.add(parsed);
    }

    return ParsedRoutine(
      days: [
        for (final d in days)
          if (d.exercises.isNotEmpty)
            ParsedDay(name: d.name, exercises: List.unmodifiable(d.exercises)),
      ],
      notes: notes,
      issues: issues,
    );
  }

  ParsedExercise _build({
    required String line,
    required String lower,
    required String original,
    String? group,
    int? rounds,
  }) {
    final spans = <(int, int)>[];
    void claim(Match m) => spans.add((m.start, m.end));

    final rest = _extractRest(lower, claim: claim);
    String? tempo;
    final tempoMatch = _tempoPattern.firstMatch(lower);
    if (tempoMatch != null) {
      tempo = tempoMatch.group(1)!.replaceAll(' ', '').toUpperCase();
      claim(tempoMatch);
    }

    final noteBits = <String>[];
    final effort = RegExp(r'@?\s*\b(rpe|rir)\s*(\d+(?:\.\d)?)').firstMatch(lower);
    if (effort != null) {
      noteBits.add('${effort.group(1)!.toUpperCase()} ${effort.group(2)}');
      claim(effort);
    }

    double? weight;
    var unit = defaultUnit;
    final weightMatch =
        RegExp(r'@\s*(\d+(?:\.\d+)?)\s*(kgs?|lbs?|pounds?|kilos?)?(?![\d:])').firstMatch(lower) ??
            RegExp(r'\b(\d+(?:\.\d+)?)\s*(kgs?|lbs?|pounds?|kilos?)\b').firstMatch(lower);
    if (weightMatch != null) {
      weight = double.tryParse(weightMatch.group(1)!);
      final u = weightMatch.group(2);
      if (u != null) unit = u.startsWith('k') ? WeightUnit.kg : WeightUnit.lb;
      claim(weightMatch);
    }

    final perSide = RegExp(
      r'(?:/|\bper\s|\beach\s)\s*(?:side|leg|arm)s?\b|\beach\b',
    ).hasMatch(lower);
    final perSideMatch = RegExp(r'(?:/|\bper\s|\beach\s)\s*(?:side|leg|arm)s?\b').firstMatch(lower);
    if (perSideMatch != null) claim(perSideMatch);

    final masked = _mask(lower, spans);
    final target = _extractTarget(masked, claim);

    final exerciseName = _nameFrom(original, spans);
    final match = index.match(exerciseName);
    final timedExercise = match.exercise?.timed ?? false;

    var sets = target.sets ?? rounds;
    var setsFrom = Provenance.explicit;
    if (sets == null) {
      // A single written time ("Warm-up 5 min") is one effort, not three.
      sets = (target.target?.isTimed ?? false) ? 1 : defaultSets;
      setsFrom = Provenance.suggested;
    }
    var setTarget = target.target;
    var targetFrom = Provenance.explicit;
    if (setTarget == null) {
      setTarget = timedExercise ? const SetTarget.duration(30) : const SetTarget.reps(10);
      targetFrom = Provenance.suggested;
    } else if (timedExercise && setTarget.kind == TargetKind.reps && target.unitless) {
      // "Plank 3 × 30" almost always means seconds.
      setTarget = SetTarget.duration(setTarget.repsMin!);
      targetFrom = Provenance.suggested;
    }

    final leftover = _leftover(original, spans, exerciseName);
    if (leftover != null) noteBits.add(leftover);

    return ParsedExercise(
      line: line,
      typedName: exerciseName,
      match: match,
      sets: sets.clamp(1, 20),
      setsFrom: setsFrom,
      target: setTarget,
      targetFrom: targetFrom,
      perSetReps: target.perSet,
      weight: weight,
      unit: unit,
      restSeconds: rest?.seconds ?? defaultRestSeconds,
      restFrom: rest == null ? Provenance.defaulted : Provenance.explicit,
      tempo: tempo,
      group: group,
      perSide: perSide,
      notes: noteBits.isEmpty ? null : noteBits.join(' · '),
    );
  }

  _Rest? _extractRest(String lower, {void Function(Match)? claim}) {
    final patterns = [
      RegExp(
        r"\(?\s*\brest(?:ing)?\b\s*(?:for|:|-|=)?\s*(\d+(?::\d{2})?(?:\.\d+)?)(?:\s*-\s*(\d+(?:\.\d+)?))?\s*(seconds?|secs?|s|minutes?|mins?|m|')?\s*\)?",
      ),
      RegExp(
        r"\(?\s*(\d+(?:\.\d+)?)\s*(seconds?|secs?|s|minutes?|mins?|m|')\s+(?:of\s+)?rest\b\s*\)?",
      ),
    ];
    for (final (i, re) in patterns.indexed) {
      final m = re.firstMatch(lower);
      if (m == null) continue;
      final value = m.group(1)!;
      final unit = i == 0 ? m.group(3) : m.group(2);
      claim?.call(m);
      return _Rest(_toSeconds(value, unit, bareMeansMinutesUpTo: 5));
    }
    return null;
  }

  _Target _extractTarget(String s, void Function(Match) claim) {
    const x = r'\s*(?:sets?\s*)?(?:x|\*)\s*';
    const unitRe = r'(seconds?|secs?|s|minutes?|mins?|m)\b';

    Match? m;
    if ((m = RegExp('(\\d+)$x(\\d+)\\s*(?:-|to)\\s*(\\d+)\\s*(?:reps?)?').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: _range(_int(m[2])!, _int(m[3])!));
    }
    if ((m = RegExp('(\\d+)$x(failure|amrap|max(?:\\s*reps)?|f)\\b').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: const SetTarget.failure());
    }
    if ((m = RegExp('(\\d+)$x(\\d+):(\\d{2})').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: SetTarget.duration(_int(m[2])! * 60 + _int(m[3])!));
    }
    if ((m = RegExp('(\\d+)$x(\\d+(?:\\.\\d+)?)\\s*$unitRe').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: SetTarget.duration(_toSeconds(m[2]!, m[3])));
    }
    if ((m = RegExp('(\\d+)$x(\\d+(?:\\s*[,/]\\s*\\d+)+)').firstMatch(s)) != null) {
      claim(m!);
      final reps = m[2]!.split(RegExp(r'[,/]')).map((e) => _int(e.trim())!).toList();
      final sets = _int(m[1])!;
      final lo = reps.reduce((a, b) => a < b ? a : b);
      final hi = reps.reduce((a, b) => a > b ? a : b);
      return _Target(sets: sets, target: _range(lo, hi), perSet: reps.length == sets ? reps : null);
    }
    if ((m = RegExp('(\\d+)$x(\\d+)\\s*(reps?)?').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: SetTarget.reps(_int(m[2])!), unitless: m[3] == null);
    }

    const of = r'\s*sets?\s*(?:of|x|,|:)?\s*';
    if ((m = RegExp('(\\d+)$of(\\d+)\\s*(?:-|to)\\s*(\\d+)').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: _range(_int(m[2])!, _int(m[3])!));
    }
    if ((m = RegExp('(\\d+)\\s*sets?\\s*(?:of|x|to|,)?\\s*(failure|amrap|max)').firstMatch(s)) !=
        null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: const SetTarget.failure());
    }
    if ((m = RegExp('(\\d+)$of(\\d+(?:\\.\\d+)?)\\s*$unitRe').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: SetTarget.duration(_toSeconds(m[2]!, m[3])));
    }
    if ((m = RegExp('(\\d+)$of(\\d+)\\s*(reps?)?').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: _int(m[1]), target: SetTarget.reps(_int(m[2])!), unitless: m[3] == null);
    }

    int? sets;
    final setsOnly = RegExp(r'(\d+)\s*(?:sets?|rounds?)\b').firstMatch(s);
    if (setsOnly != null) {
      claim(setsOnly);
      sets = _int(setsOnly[1]);
    }
    if ((m = RegExp(r'(\d+)\s*(?:-|to)\s*(\d+)\s*reps?\b').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: sets, target: _range(_int(m[1])!, _int(m[2])!));
    }
    if ((m = RegExp(r'(\d+)\s*reps?\b').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: sets, target: SetTarget.reps(_int(m[1])!));
    }
    if ((m = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: sets, target: SetTarget.duration(_int(m[1])! * 60 + _int(m[2])!));
    }
    if ((m = RegExp('(\\d+(?:\\.\\d+)?)\\s*$unitRe').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: sets, target: SetTarget.duration(_toSeconds(m[1]!, m[2])));
    }
    if ((m = RegExp(r'\b(?:to\s+)?(failure|amrap)\b').firstMatch(s)) != null) {
      claim(m!);
      return _Target(sets: sets, target: const SetTarget.failure());
    }
    return _Target(sets: sets);
  }

  SetTarget _range(int a, int b) {
    if (a == b) return SetTarget.reps(a);
    return a < b ? SetTarget.range(a, b) : SetTarget.range(b, a);
  }

  int _toSeconds(String value, String? unit, {int bareMeansMinutesUpTo = 0}) {
    if (value.contains(':')) {
      final p = value.split(':');
      return _int(p[0])! * 60 + _int(p[1])!;
    }
    final v = math.min(double.parse(value), _maxNumber.toDouble());
    final minutes = unit == null ? v <= bareMeansMinutesUpTo : unit.startsWith('m') || unit == "'";
    return (minutes ? v * 60 : v).round();
  }

  /// Numbers past this are typos, and capping them keeps "3x99999999999999999999"
  /// from overflowing.
  static const _maxNumber = 99999;

  static int? _int(String? s) =>
      s == null ? null : math.min(int.tryParse(s) ?? _maxNumber, _maxNumber);

  /// Lowercases and folds look-alike characters one-for-one, so match offsets in
  /// the folded string line up with the original.
  static String _fold(String line) => line
      .toLowerCase()
      .replaceAll(RegExp('[×✕✖]'), 'x')
      .replaceAll(RegExp('[–—−]'), '-')
      .replaceAll(RegExp('[’‘]'), "'");

  static String _mask(String s, List<(int, int)> spans) {
    final chars = s.split('');
    for (final (a, b) in spans) {
      for (var i = a; i < b; i++) {
        chars[i] = ' ';
      }
    }
    return chars.join();
  }

  static String _nameFrom(String original, List<(int, int)> spans) {
    if (spans.isEmpty) return _trimName(original);
    final first = spans.map((s) => s.$1).reduce((a, b) => a < b ? a : b);
    final before = _trimName(original.substring(0, first));
    if (before.isNotEmpty) return before;
    // "3 × 10 squats": the name comes after the numbers.
    final last = spans.map((s) => s.$2).reduce((a, b) => a > b ? a : b);
    return _trimName(original.substring(last.clamp(0, original.length)));
  }

  static String _trimName(String s) => s
      .replaceAll(RegExp(r'^[\s:,;\-–—|(\[]+|[\s:,;\-–—|(\[@]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String? _leftover(String original, List<(int, int)> spans, String name) {
    var rest = _mask(original, spans);
    final at = rest.indexOf(name);
    if (at >= 0) rest = rest.replaceRange(at, at + name.length, '');
    rest = rest
        .replaceAll(RegExp(r'[()\[\],;:|@]'), ' ')
        .replaceAll(RegExp(r'^[\s\-–—]+|[\s\-–—]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    rest = rest.replaceAll(RegExp(r'^(?:reps?|sets?|each|x)\b\s*', caseSensitive: false), '');
    if (RegExp(r'[a-zA-Z]{3,}').hasMatch(rest)) return rest;
    return null;
  }

  static final _setsPattern = RegExp(
    r'\d+\s*(?:sets?\s*)?(?:x|\*)\s*(?:\d|failure|amrap|max|f\b)|\d+\s*sets?\b|\d+\s*reps?\b|\d+\s*rounds?\b',
  );
  static final _durationPattern = RegExp(
    r'\b\d+(?:\.\d+)?\s*(?:seconds?|secs?|s|minutes?|mins?)\b|\b\d{1,2}:\d{2}\b',
  );
  static final _tempoPattern = RegExp(
    r'(?:\btempo\s*[:=]?\s*)?\b([0-9x](?:\s*-\s*[0-9x]){2,3})\b(?!\s*(?:reps?|sets?|s\b|sec|min|kg|lb))',
  );

  static const _weekdays =
      r'(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(day|sday|nesday|rsday|urday)?';

  bool _isStrongHeading(String lower, String original) {
    if (RegExp('^$_weekdays\\b').hasMatch(lower)) return true;
    if (RegExp(r'^(day|week|session|workout)\s*[0-9a-z]?\b').hasMatch(lower)) {
      return true;
    }
    if (original.endsWith(':') && lower.split(' ').length <= 4) return true;
    if (RegExp(r'\s[-|]\s').hasMatch(lower) && lower.split(' ').length <= 6) {
      return index.match(original).status != MatchStatus.exact;
    }
    final letters = original.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.length >= 3 && letters == letters.toUpperCase() && lower.split(' ').length <= 5;
  }

  bool _isSoftHeading(String lower) => RegExp(
        r'^(push|pull|legs?|upper|lower|full\s?body|chest|back|arms?|shoulders?|core|abs|glutes?|cardio|conditioning|warm\s?up|cool\s?down|finisher|accessor(y|ies)|hiit|mobility|strength)\b',
      ).hasMatch(lower);

  static String _cleanHeading(String line) {
    final cleaned = line
        .replaceAll(RegExp(r'[:]+$'), '')
        .replaceAll(RegExp(r'\s*[-–—|]\s*'), ' — ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned == cleaned.toUpperCase() && cleaned.length > 3) {
      return cleaned
          .toLowerCase()
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return cleaned;
  }
}

class _DayBuilder {
  _DayBuilder(this.name);
  final String name;
  final exercises = <ParsedExercise>[];
}

class _Rest {
  const _Rest(this.seconds);
  final int seconds;
}

class _Target {
  const _Target({this.sets, this.target, this.perSet, this.unitless = false});
  final int? sets;
  final SetTarget? target;
  final List<int>? perSet;
  final bool unitless;
}
