# workout_parser

Turns a workout routine written as plain text into structured data. The text
can come from a note, a WhatsApp message or an AI chat:

```
Monday — Push
Incline DB Press 3 × 10, rest 90 sec
Lateral Raises 3 × 15
Plank 3 × 45 sec
Push-ups 2 × failure
```

```dart
import 'package:workout_parser/workout_parser.dart';

final routine = RoutineParser().parse(text);

for (final day in routine.days) {
  print(day.name); // Monday — Push
  for (final e in day.exercises) {
    print('${e.displayName}: ${e.sets} × ${e.target.label}');
    // Incline Dumbbell Press: 3 × 10 reps
    // Side Lateral Raise: 3 × 15 reps
    // Plank: 3 × 45 sec
    // Pushups: 2 × to failure
  }
}
```

It runs offline in pure Dart, with no API calls and no Flutter dependency, so
it works in apps, servers and command-line tools. I built it for
[neFaRec](https://github.com/mofixiu/neFaRecmobile), where you paste the
routine you already follow and check what was read before you train it.

## What it reads

| You write | You get |
| --- | --- |
| `Bench press 4x6-8` | 4 sets of 6–8 reps |
| `Squat 5x5 @ 100kg, rest 3 min` | weight 100 kg, rest 180 s |
| `Deadlift 4 x 8, 6, 4, 2` | per-set reps `[8, 6, 4, 2]` |
| `Plank 3 × 45 sec`, `Wall sit 3 x 1:30` | timed holds |
| `Push-ups 2 × failure`, `AMRAP` | sets to failure |
| `RDL 3x10 tempo 3-1-1-0 @ RPE 8` | tempo `3-1-1-0`, note `RPE 8` |
| `Lunges 3x12 each leg` | `perSide: true` |
| `A1 Leg curl 3x12` / `A2 Calf raise 3x15` | superset group `A` |
| `Superset:` followed by lines | one group for the block |
| `Curls + pushdowns 3 × 12` | two exercises in one group |
| `3 rounds:` followed by lines | 3 sets each |
| `rest 2 min` on its own line | rest for the exercise above |
| `Day 1`, `Monday`, `PUSH`, `## Legs` | a new day |
| `Tip: …`, `(…)` | a note on the exercise above |

It also understands `×`, en and em dashes, bullet characters, numbered lists
and Markdown bold.

## Check before you trust it

Pasted text is messy, so the parser never guesses silently. Every exercise
tells you where each value came from:

```dart
e.setsFrom   // Provenance.explicit, .suggested or .defaulted
e.targetFrom
e.restFrom
e.hasSuggestions     // any value the parser filled in
e.match.needsReview  // the name was ambiguous or unknown
routine.flaggedCount // how many exercises need a look
routine.issues       // lines it could not read, with a reason
routine.notes        // advice lines that are not exercises
```

`Push ups 20 reps` gives 20 reps (explicit) and 3 sets (suggested).
`Plank 3 × 30` gives 30 seconds (suggested), because a plank is a hold.
Highlight anything that is not explicit and let the user confirm it.

## Exercise matching

`ExerciseIndex.builtIn()` knows the 884 exercises from
[free-exercise-db](https://github.com/yuhonas/free-exercise-db) and 1,195
aliases people actually write, such as `OHP`, `RDL`, `BB row`, `skull crushers`
and `lat pulldown`. Shorthand like `DB`, `BB`, `KB` and `inc` is expanded
before matching.

Names that aren't an exact alias are fuzzy-matched by name similarity. The
matcher keeps equipment apart, so `DB press` never becomes a barbell lift.
Generic names such as `press` or `row` come back as `MatchStatus.uncertain`,
with the closest alternatives in `match.candidates`.

To match against your own exercise ids, build your own index:

```dart
final index = ExerciseIndex(
  exercises: [
    IndexedExercise(id: 'sq', name: 'Back Squat'),
    IndexedExercise(id: 'pl', name: 'Plank', timed: true),
  ],
  aliases: {'squats': 'sq', 'front plank': 'pl'},
);
final parser = RoutineParser(index: index);
```

`index.search('incline')` gives ranked results for a "pick another exercise"
list.

## Options

```dart
RoutineParser(
  defaultSets: 3,           // when a line has reps but no set count
  defaultRestSeconds: 90,   // null to leave rest empty when none is written
  defaultUnit: WeightUnit.kg, // for a bare "@ 60"
);
```

## JSON

`ParsedRoutine`, `ParsedDay`, `ParsedExercise`, `SetTarget` and `ExerciseMatch`
all have `toJson()`, so you can send a draft to a backend or store it.

## Accuracy

The test suite checks the parser against 39 routines written the way people
actually write them: bullets, Markdown, supersets, circuits, timed holds,
weekday splits and AI-formatted plans. It gets all 700 checked fields and all
124 exercise names right. A typical routine parses in about 10 ms.

## Licence

MIT. The exercise names and ids come from free-exercise-db, released under the
Unlicense.
