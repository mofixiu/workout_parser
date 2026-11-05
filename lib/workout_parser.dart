/// Reads workout routines written as plain text into structured days,
/// exercises and set targets, offline and without an API.
library;

export 'src/exercise_index.dart'
    show ExerciseIndex, ExerciseMatch, IndexedExercise, MatchCandidate, MatchStatus;
export 'src/parsed_routine.dart';
export 'src/routine_parser.dart';
export 'src/set_target.dart';
