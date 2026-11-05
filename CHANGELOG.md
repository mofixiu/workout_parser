## 0.1.0

- First release, extracted from the neFaRec workout app.
- `RoutineParser` reads days, exercises, sets, reps, rep ranges, per-set reps,
  timed holds, sets to failure, rest, weight, tempo, RPE/RIR, per-side work and
  supersets from plain text.
- `ExerciseIndex.builtIn()` matches names against 884 exercises and 1,195
  aliases, with fuzzy matching that keeps dumbbell and barbell lifts apart.
- Every value records whether it was written, suggested or defaulted.
- `toJson()` on every result.
