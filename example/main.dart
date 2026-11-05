import 'dart:convert';

import 'package:workout_parser/workout_parser.dart';

const routine = '''
Monday — Push
Incline DB Press 3 × 10, rest 90 sec
Lateral Raises 3 × 15
Plank 3 × 45 sec
Push-ups 2 × failure

Thursday — Legs
Squat 5x5 @ 100kg, rest 3 min
RDL 3 x 8-10
A1 Leg curl 3x12
A2 Calf raise 3x15
Tip: keep the last set of each lift one rep short of failure.
Landmine press 3x10
Bicep curls 12 reps
''';

void main() {
  final result = RoutineParser().parse(routine);

  for (final day in result.days) {
    print(day.name);
    for (final e in day.exercises) {
      final mark = e.hasSuggestions || e.match.needsReview ? ' *' : '';
      final group = e.group == null ? '' : '[${e.group}] ';
      final weight = e.weight == null ? '' : ' @ ${_trim(e.weight!)} ${e.unit.name}';
      // Rest you didn't write is the parser's default (90 sec unless you change it).
      final rest =
          e.restFrom == Provenance.explicit ? ', rest ${formatSeconds(e.restSeconds!)}' : '';
      final notes = e.notes == null ? '' : '  (${e.notes})';
      print('  $group${e.displayName}: ${e.sets} × ${e.target.label}$weight$rest$mark$notes');
    }
  }
  if (result.notes.isNotEmpty) print('\nNotes: ${result.notes.join(' / ')}');
  if (result.issues.isNotEmpty) {
    print('\nCould not read: ${result.issues.map((i) => i.line).join(' / ')}');
  }
  print('\n${result.flaggedCount} exercises need a look (marked *).');

  // Everything serialises, e.g. to send to a backend or store as a draft.
  final json =
      const JsonEncoder.withIndent('  ').convert(result.days.first.exercises.first.toJson());
  print('\n$json');
}

String _trim(double n) => n == n.roundToDouble() ? n.toStringAsFixed(0) : '$n';
