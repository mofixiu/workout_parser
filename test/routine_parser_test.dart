import 'dart:convert';

import 'package:test/test.dart';
import 'package:workout_parser/workout_parser.dart';

import 'fixtures.dart';

void main() {
  final index = ExerciseIndex.builtIn();
  final parser = RoutineParser();

  String? confidentId(ExerciseMatch m) =>
      m.status == MatchStatus.exact || m.status == MatchStatus.fuzzy ? m.exercise?.id : null;

  test('spec example parses exactly, with suggestions marked', () {
    final r = parser.parse(fixtures.first.text);
    expect(r.days.single.name, 'Monday — Push');
    final ex = r.exercises.toList();
    expect(ex, hasLength(4));
    expect(ex[0].restSeconds, 90);
    expect(ex[0].restFrom, Provenance.explicit);
    expect(ex[1].restFrom, Provenance.defaulted);
    expect(ex[2].target, const SetTarget.duration(45));
    expect(ex[3].target, const SetTarget.failure());
    expect(ex.every((e) => e.setsFrom == Provenance.explicit), isTrue);
  });

  test('reps without sets suggest a set count rather than inventing one', () {
    final e = parser.parse('Push ups 20 reps').exercises.single;
    expect(e.sets, 3);
    expect(e.setsFrom, Provenance.suggested);
    expect(e.targetFrom, Provenance.explicit);
  });

  test('order is preserved and nothing is silently replaced', () {
    final r = parser.parse('Landmine press 3x10\nSquat 3x5');
    final ex = r.exercises.toList();
    expect(ex.first.typedName, 'Landmine press');
    expect(ex.first.match.needsReview, isTrue);
    expect(ex.last.match.exercise?.id, 'Barbell_Squat');
  });

  test('unreadable lines become issues, not exercises', () {
    final r = parser.parse('Squat 3x5\nfoo bar baz');
    expect(r.exercises, hasLength(1));
    expect(r.issues.single.line, 'foo bar baz');
  });

  test('dumbbell shorthand never turns into a barbell lift', () {
    final m = index.match('DB press');
    expect(m.exercise?.equipment, 'dumbbell');
  });

  test('weight, rest, tempo and effort on one line', () {
    final e = parser.parse('Squat 5x5 @ 100kg, tempo 3-1-1-0, rest 3 min, RPE 8').exercises.single;
    expect(e.sets, 5);
    expect(e.target, const SetTarget.reps(5));
    expect(e.weight, 100);
    expect(e.unit, WeightUnit.kg);
    expect(e.restSeconds, 180);
    expect(e.tempo, '3-1-1-0');
    expect(e.notes, contains('RPE 8'));
  });

  test('a one-line superset becomes two grouped exercises', () {
    final ex = parser.parse('Curls + pushdowns 3 × 12').exercises.toList();
    expect(ex, hasLength(2));
    expect(ex.map((e) => e.group).toSet(), {'A'});
  });

  test('defaults can be changed or switched off', () {
    final custom =
        RoutineParser(defaultSets: 4, defaultRestSeconds: null, defaultUnit: WeightUnit.lb);
    final e = custom.parse('Bench press 8 reps @ 135').exercises.single;
    expect(e.sets, 4);
    expect(e.restSeconds, isNull);
    expect(e.unit, WeightUnit.lb);
  });

  test('a custom index matches against your own ids', () {
    final own = ExerciseIndex(
      exercises: const [
        IndexedExercise(id: 'squat', name: 'Back Squat'),
        IndexedExercise(id: 'plank', name: 'Plank', timed: true),
      ],
      aliases: const {'squats': 'squat'},
    );
    final ex = RoutineParser(index: own).parse('Squats 3x5\nPlank 3 x 30').exercises.toList();
    expect(ex[0].match.exercise?.id, 'squat');
    expect(ex[1].target, const SetTarget.duration(30));
    expect(ex[1].targetFrom, Provenance.suggested);
  });

  test('empty and odd input never throws', () {
    for (final text in ['', '   \n\n', '###', '3x', '@', 'rest', '×××', '1:', '((()))']) {
      expect(() => parser.parse(text), returnsNormally, reason: text);
    }
    expect(parser.parse('').isEmpty, isTrue);
  });

  test('numbers too big for an int are capped, not thrown', () {
    for (final text in [
      'Squat 3x99999999999999999999',
      'Squat 3x5-99999999999999999999',
      'Squat 3x 10,99999999999999999999',
      '99999999999999999999 rounds\nSquat 5 reps',
      'Plank 3 x 99999999999999999999 sec',
    ]) {
      expect(() => parser.parse(text), returnsNormally, reason: text);
    }
    expect(parser.parse('Squat 99999999999999999999x5').exercises.single.sets, 20);
  });

  test('toJson round-trips through jsonEncode', () {
    final r = parser.parse(fixtures.first.text);
    final decoded = jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
    final first = (decoded['days'] as List).first['exercises'].first as Map<String, dynamic>;
    expect(first['name'], 'Incline Dumbbell Press');
    expect(first['target'], {'kind': 'reps', 'repsMin': 10, 'repsMax': 10});
    expect(first['restSeconds'], 90);
    expect(first['restFrom'], 'explicit');
  });

  test('fixture accuracy', () {
    var fields = 0;
    var correct = 0;
    var names = 0;
    var namesCorrect = 0;
    final misses = <String>[];

    void check(String fixture, String field, Object? want, Object? got) {
      fields++;
      if (want == got) {
        correct++;
      } else {
        misses.add('$fixture · $field: want $want, got $got');
      }
    }

    for (final f in fixtures) {
      final r = parser.parse(f.text);
      check(f.name, 'days', f.days.join(' / '), r.days.map((d) => d.name).join(' / '));
      final got = r.exercises.toList();
      check(f.name, 'count', f.exercises.length, got.length);
      for (var i = 0; i < f.exercises.length && i < got.length; i++) {
        final want = f.exercises[i];
        final g = got[i];
        final label = '${f.name}[$i] ${g.typedName}';
        names++;
        if (want.id == confidentId(g.match)) {
          namesCorrect++;
        } else {
          misses.add(
            '$label · id: want ${want.id}, got ${g.match.status.name} '
            '${g.match.exercise?.id} (${g.match.score.toStringAsFixed(2)})',
          );
        }
        check(label, 'sets', want.sets, g.sets);
        check(label, 'target', want.target, g.target.label);
        check(label, 'rest', want.rest, g.restFrom == Provenance.explicit ? g.restSeconds : null);
        check(label, 'weight', want.weight, g.weight);
        check(label, 'group', want.group, g.group);
        if (want.tempo != null) check(label, 'tempo', want.tempo, g.tempo);
      }
    }

    final fieldAcc = correct / fields;
    final nameAcc = namesCorrect / names;
    printOnFailure(misses.join('\n'));
    // ignore: avoid_print
    print(
      'field accuracy ${(fieldAcc * 100).toStringAsFixed(1)}% ($correct/$fields) · '
      'exercise match ${(nameAcc * 100).toStringAsFixed(1)}% ($namesCorrect/$names)',
    );
    expect(fieldAcc, greaterThanOrEqualTo(.9));
    expect(nameAcc, greaterThanOrEqualTo(.9));
  });
}
