/// Hand-verified routines for parser accuracy. Each expected exercise lists the
/// canonical id (null = should stay custom), sets, target label, explicit rest
/// (null = none written) and weight.
class Expect {
  const Expect(this.id, this.sets, this.target, {this.rest, this.weight, this.group, this.tempo});
  final String? id;
  final int sets;
  final String target;
  final int? rest;
  final double? weight;
  final String? group;
  final String? tempo;
}

class Fixture {
  const Fixture(this.name, this.text, this.days, this.exercises);
  final String name;
  final String text;
  final List<String> days;
  final List<Expect> exercises;
}

const fixtures = <Fixture>[
  Fixture(
    'spec example',
    '''Monday — Push
Incline DB Press 3 × 10, rest 90 sec
Lateral Raises 3 × 15
Plank 3 × 45 sec
Push-ups 2 × failure''',
    ['Monday — Push'],
    [
      Expect('Incline_Dumbbell_Press', 3, '10 reps', rest: 90),
      Expect('Side_Lateral_Raise', 3, '15 reps'),
      Expect('Plank', 3, '45 sec'),
      Expect('Pushups', 2, 'to failure'),
    ],
  ),
  Fixture(
    'bullets and ranges',
    '''- Bench press 4x6-8
- BB row 4x8-10
- OHP 3x8
- Lat pulldown 3x10-12''',
    ['Workout'],
    [
      Expect('Barbell_Bench_Press_-_Medium_Grip', 4, '6–8 reps'),
      Expect('Bent_Over_Barbell_Row', 4, '8–10 reps'),
      Expect('Standing_Military_Press', 3, '8 reps'),
      Expect('Wide-Grip_Lat_Pulldown', 3, '10–12 reps'),
    ],
  ),
  Fixture(
    'numbered with weights',
    '''1. Squat 5x5 @ 100kg
2. RDL 3x8 @ 70kg
3. Leg press 3x12 140kg
4. Calf raises 4x15''',
    ['Workout'],
    [
      Expect('Barbell_Squat', 5, '5 reps', weight: 100),
      Expect('Romanian_Deadlift', 3, '8 reps', weight: 70),
      Expect('Leg_Press', 3, '12 reps', weight: 140),
      Expect('Standing_Calf_Raises', 4, '15 reps'),
    ],
  ),
  Fixture(
    'sets of reps wording',
    '''Day 1: Pull
Pull-ups: 3 sets of 8
Dumbbell rows - 3 sets of 10-12 reps
Face pulls 3 sets of 15, rest 60s
Hammer curls 3 sets x 12''',
    ['Day 1: Pull'],
    [
      Expect('Pullups', 3, '8 reps'),
      Expect('One-Arm_Dumbbell_Row', 3, '10–12 reps'),
      Expect('Face_Pull', 3, '15 reps', rest: 60),
      Expect('Hammer_Curls', 3, '12 reps'),
    ],
  ),
  Fixture(
    'two days',
    '''UPPER
Bench 3x8
Pulldown 3x10

LOWER
Back squat 3x6
Leg curl 3x12''',
    ['Upper', 'Lower'],
    [
      Expect('Barbell_Bench_Press_-_Medium_Grip', 3, '8 reps'),
      Expect('Wide-Grip_Lat_Pulldown', 3, '10 reps'),
      Expect('Barbell_Squat', 3, '6 reps'),
      Expect('Lying_Leg_Curls', 3, '12 reps'),
    ],
  ),
  Fixture(
    'timed holds',
    '''Core finisher
Plank 3x60s
Wall sit 3 x 45 seconds
Side plank 2 x 30 sec
Dead hang 3 x 1 min''',
    ['Core finisher'],
    [
      Expect('Plank', 3, '1 min'),
      Expect('nefa_wall_sit', 3, '45 sec'),
      Expect('nefa_side_plank', 2, '30 sec'),
      Expect('nefa_dead_hang', 3, '1 min'),
    ],
  ),
  Fixture(
    'rest on its own line',
    '''Deadlift 5x3 @ 140kg
Rest 3 min
Pull ups 4 x AMRAP
rest 2 minutes''',
    ['Workout'],
    [
      Expect('Barbell_Deadlift', 5, '3 reps', weight: 140, rest: 180),
      Expect('Pullups', 4, 'to failure', rest: 120),
    ],
  ),
  Fixture(
    'superset labels',
    '''A1. DB bench press 3x10
A2. Chest supported row 3x12
B1. Curls 3x12
B2. Tricep pushdown 3x15''',
    ['Workout'],
    [
      Expect('Dumbbell_Bench_Press', 3, '10 reps', group: 'A'),
      Expect(null, 3, '12 reps', group: 'A'),
      Expect('Dumbbell_Bicep_Curl', 3, '12 reps', group: 'B'),
      Expect('Triceps_Pushdown', 3, '15 reps', group: 'B'),
    ],
  ),
  Fixture(
    'superset header block',
    '''Superset:
Lateral raises 3x15
Rear delt fly 3x15

Skull crushers 3x10''',
    ['Workout'],
    [
      Expect('Side_Lateral_Raise', 3, '15 reps', group: 'A'),
      Expect('Reverse_Flyes', 3, '15 reps', group: 'A'),
      Expect('EZ-Bar_Skullcrusher', 3, '10 reps'),
    ],
  ),
  Fixture('plus on one line', '''Bicep curls + tricep pushdowns 3x12''', [
    'Workout'
  ], [
    Expect('Dumbbell_Bicep_Curl', 3, '12 reps', group: 'A'),
    Expect('Triceps_Pushdown', 3, '12 reps', group: 'A'),
  ]),
  Fixture(
    'tempo',
    '''Goblet squat 3x10 tempo 3-1-1-0
Bulgarian split squat 3 x 8 each leg 3-0-1-0''',
    ['Workout'],
    [
      Expect('Goblet_Squat', 3, '10 reps', tempo: '3-1-1-0'),
      Expect('nefa_bulgarian_split_squat', 3, '8 reps', tempo: '3-0-1-0'),
    ],
  ),
  Fixture(
    'pounds',
    '''Bench press 3 x 5 @ 185 lbs
Incline dumbbell press 3x10 50lb''',
    ['Workout'],
    [
      Expect('Barbell_Bench_Press_-_Medium_Grip', 3, '5 reps', weight: 185),
      Expect('Incline_Dumbbell_Press', 3, '10 reps', weight: 50),
    ],
  ),
  Fixture(
    'reps without sets',
    '''Push ups 20 reps
Squats 15 reps
Lunges 10 reps each leg''',
    ['Workout'],
    [
      Expect('Pushups', 3, '20 reps'),
      Expect('Barbell_Squat', 3, '15 reps'),
      Expect('Dumbbell_Lunges', 3, '10 reps'),
    ],
  ),
  Fixture(
    'descending reps',
    '''Leg press 4x12,10,8,6
Leg extension 3x15''',
    ['Workout'],
    [Expect('Leg_Press', 4, '6–12 reps'), Expect('Leg_Extensions', 3, '15 reps')],
  ),
  Fixture(
    'markdown headings',
    '''## Thursday – Legs
* **Hack squat** 4x10
* **Hip thrust** 3x12 @ 80kg
* **Seated leg curl** 3x12''',
    ['Thursday — Legs'],
    [
      Expect('Hack_Squat', 4, '10 reps'),
      Expect('Barbell_Hip_Thrust', 3, '12 reps', weight: 80),
      Expect('Seated_Leg_Curl', 3, '12 reps'),
    ],
  ),
  Fixture(
    'chatbot style',
    '''Here is your full body workout:

Warm-up: 5 min easy cardio

1. Goblet Squats – 3 sets × 12 reps (rest 60 seconds)
2. Push-Ups – 3 sets × 10–12 reps (rest 60 seconds)
3. Dumbbell Romanian Deadlift – 3 sets × 10 reps (rest 90 seconds)
4. Plank – 3 × 30 seconds''',
    ['Workout'],
    [
      Expect(null, 1, '5 min'),
      Expect('Goblet_Squat', 3, '12 reps', rest: 60),
      Expect('Pushups', 3, '10–12 reps', rest: 60),
      Expect('Stiff-Legged_Dumbbell_Deadlift', 3, '10 reps', rest: 90),
      Expect('Plank', 3, '30 sec'),
    ],
  ),
  Fixture(
    'compact x',
    '''Dips 3X10
Chin ups 3X6
Shrugs 3X15''',
    ['Workout'],
    [
      Expect('Dips_-_Chest_Version', 3, '10 reps'),
      Expect('Chin-Up', 3, '6 reps'),
      Expect('Dumbbell_Shrug', 3, '15 reps'),
    ],
  ),
  Fixture(
    'rest in minutes shorthand',
    '''Squat 3x5 rest 3
Bench 3x5 rest 2-3 min''',
    ['Workout'],
    [
      Expect('Barbell_Squat', 3, '5 reps', rest: 180),
      Expect('Barbell_Bench_Press_-_Medium_Grip', 3, '5 reps', rest: 120),
    ],
  ),
  Fixture(
    'cable work',
    '''Cable fly 3x15
Cable lateral raise 3x15
Seated cable row 3x12
Rope pushdown 3x15''',
    ['Workout'],
    [
      Expect('Flat_Bench_Cable_Flyes', 3, '15 reps'),
      Expect('Cable_Seated_Lateral_Raise', 3, '15 reps'),
      Expect('Seated_Cable_Rows', 3, '12 reps'),
      Expect('Triceps_Pushdown_-_Rope_Attachment', 3, '15 reps'),
    ],
  ),
  Fixture(
    'home workout',
    '''Jumping jacks 3 x 45s
Burpees 3x10
Mountain climbers 3 x 30 sec
Glute bridge 3x15
Russian twists 3x20''',
    ['Workout'],
    [
      Expect('nefa_jumping_jack', 3, '45 sec'),
      Expect('nefa_burpee', 3, '10 reps'),
      Expect('Mountain_Climbers', 3, '30 sec'),
      Expect('Butt_Lift_Bridge', 3, '15 reps'),
      Expect('Russian_Twist', 3, '20 reps'),
    ],
  ),
  Fixture(
    'abbrevs',
    '''DB shoulder press 3x10
DB curl 3x12
KB swings 4x15
BB curl 3x10''',
    ['Workout'],
    [
      Expect('Dumbbell_Shoulder_Press', 3, '10 reps'),
      Expect('Dumbbell_Bicep_Curl', 3, '12 reps'),
      Expect('One-Arm_Kettlebell_Swings', 4, '15 reps'),
      Expect('Barbell_Curl', 3, '10 reps'),
    ],
  ),
  Fixture(
    'typos',
    '''Romanian dedlift 3x8
Lateral rasies 3x15
Bulgarain split squat 3x10''',
    ['Workout'],
    [
      Expect('Romanian_Deadlift', 3, '8 reps'),
      Expect('Side_Lateral_Raise', 3, '15 reps'),
      Expect('nefa_bulgarian_split_squat', 3, '10 reps'),
    ],
  ),
  Fixture(
    'weekday headers',
    '''Tuesday
Front squat 4x6
Walking lunges 3x12

Saturday
Sumo deadlift 3x5
Farmers walk 3 x 40s''',
    ['Tuesday', 'Saturday'],
    [
      Expect('Front_Squat_Clean_Grip', 4, '6 reps'),
      Expect('Bodyweight_Walking_Lunge', 3, '12 reps'),
      Expect('Sumo_Deadlift', 3, '5 reps'),
      Expect('Farmers_Walk', 3, '40 sec'),
    ],
  ),
  Fixture(
    'rpe and notes',
    '''Bench press 3x5 @RPE8 pause on chest
Incline DB press 3x10 (slow negatives)''',
    ['Workout'],
    [
      Expect('Barbell_Bench_Press_-_Medium_Grip', 3, '5 reps'),
      Expect('Incline_Dumbbell_Press', 3, '10 reps'),
    ],
  ),
  Fixture(
    'failure words',
    '''Push-ups 3 sets to failure
Pull-ups 3 x max
Dips 2xAMRAP''',
    ['Workout'],
    [
      Expect('Pushups', 3, 'to failure'),
      Expect('Pullups', 3, 'to failure'),
      Expect('Dips_-_Chest_Version', 2, 'to failure'),
    ],
  ),
  Fixture(
    'pipes and dashes',
    '''Week 1 | Push
Chest press machine | 3x12
Pec deck - 3x15
Overhead tricep extension — 3x12''',
    ['Week 1 — Push'],
    [
      Expect('Machine_Bench_Press', 3, '12 reps'),
      Expect('Butterfly', 3, '15 reps'),
      Expect('Cable_Rope_Overhead_Triceps_Extension', 3, '12 reps'),
    ],
  ),
  Fixture(
    'mm:ss holds',
    '''Plank 3 x 1:30
Hollow hold 3 x 0:40''',
    ['Workout'],
    [Expect('Plank', 3, '1:30'), Expect('nefa_hollow_hold', 3, '40 sec')],
  ),
  Fixture(
    'arms day',
    '''Arms
Preacher curl 3x10
Incline curl 3x12
Skullcrushers 3x10
Tricep kickbacks 3x15
Concentration curls 2x12''',
    ['Arms'],
    [
      Expect('Preacher_Curl', 3, '10 reps'),
      Expect('Incline_Dumbbell_Curl', 3, '12 reps'),
      Expect('EZ-Bar_Skullcrusher', 3, '10 reps'),
      Expect('Tricep_Dumbbell_Kickback', 3, '15 reps'),
      Expect('Concentration_Curls', 2, '12 reps'),
    ],
  ),
  Fixture(
    'shoulders',
    '''Shoulders:
Arnold press 4x10
Upright row 3x12
Front raises 3x12
Reverse fly 3x15''',
    ['Shoulders'],
    [
      Expect('Arnold_Dumbbell_Press', 4, '10 reps'),
      Expect('Upright_Barbell_Row', 3, '12 reps'),
      Expect('Front_Plate_Raise', 3, '12 reps'),
      Expect('Reverse_Flyes', 3, '15 reps'),
    ],
  ),
  Fixture(
    'back',
    '''T-bar row 4x8
Straight arm pulldown 3x12
Inverted rows 3x10
Good mornings 3x10''',
    ['Workout'],
    [
      Expect('T-Bar_Row_with_Handle', 4, '8 reps'),
      Expect('Straight-Arm_Pulldown', 3, '12 reps'),
      Expect('Inverted_Row', 3, '10 reps'),
      Expect('Good_Morning', 3, '10 reps'),
    ],
  ),
  Fixture(
    'abs',
    '''Hanging leg raises 3x12
Cable crunch 3x15
Ab wheel 3x10
Bicycle crunches 3x20
Dead bug 3x10''',
    ['Workout'],
    [
      Expect('Hanging_Leg_Raise', 3, '12 reps'),
      Expect('Cable_Crunch', 3, '15 reps'),
      Expect('Ab_Roller', 3, '10 reps'),
      Expect('nefa_bicycle_crunch', 3, '20 reps'),
      Expect('Dead_Bug', 3, '10 reps'),
    ],
  ),
  Fixture(
    'reverse name order',
    '''3x10 squats
4 x 8 bench press''',
    ['Workout'],
    [
      Expect('Barbell_Squat', 3, '10 reps'),
      Expect('Barbell_Bench_Press_-_Medium_Grip', 4, '8 reps'),
    ],
  ),
  Fixture(
    'rest before',
    '''Lat pulldown 3x12 - 60s rest
Seated row 3x12 - 90 sec rest''',
    ['Workout'],
    [
      Expect('Wide-Grip_Lat_Pulldown', 3, '12 reps', rest: 60),
      Expect('Seated_Cable_Rows', 3, '12 reps', rest: 90),
    ],
  ),
  Fixture(
    'legs machine',
    '''Leg Day
Leg Extensions 3 x 15
Lying leg curls 3 x 12
Seated calf raise 4 x 20
Glute kickbacks 3 x 15 per leg''',
    ['Leg Day'],
    [
      Expect('Leg_Extensions', 3, '15 reps'),
      Expect('Lying_Leg_Curls', 3, '12 reps'),
      Expect('Seated_Calf_Raise', 4, '20 reps'),
      Expect('Glute_Kickback', 3, '15 reps'),
    ],
  ),
  Fixture(
    'conditioning',
    '''Finisher
Jump rope 3 x 60 sec
Box jumps 3x8
Battle ropes 4 x 20s''',
    ['Finisher'],
    [
      Expect('Rope_Jumping', 3, '1 min'),
      Expect('Front_Box_Jump', 3, '8 reps'),
      Expect('Battling_Ropes', 4, '20 sec'),
    ],
  ),
  Fixture(
    'decimals',
    '''Lateral raise 3x15 @ 7.5kg
DB press 3x10 @ 22.5 kg''',
    ['Workout'],
    [
      Expect('Side_Lateral_Raise', 3, '15 reps', weight: 7.5),
      // "DB press" could be bench or shoulder press: asks to confirm.
      Expect(null, 3, '10 reps', weight: 22.5),
    ],
  ),
  Fixture(
    'rounds',
    '''Circuit
3 rounds
Burpees 10 reps
Air squats 20 reps''',
    ['Workout'],
    [
      Expect('nefa_burpee', 3, '10 reps', group: 'A'),
      Expect('Bodyweight_Squat', 3, '20 reps', group: 'A'),
    ],
  ),
  Fixture(
    'sets reps commas',
    '''Close grip bench, 3 sets, 8 reps
Decline push-ups, 3 sets, 12 reps''',
    ['Workout'],
    [
      Expect('Close-Grip_Barbell_Bench_Press', 3, '8 reps'),
      Expect('Decline_Push-Up', 3, '12 reps'),
    ],
  ),
  Fixture(
    'unknown movement',
    '''Zercher carry 3 x 40s
Landmine press 3x10''',
    ['Workout'],
    [Expect(null, 3, '40 sec'), Expect(null, 3, '10 reps')],
  ),
];
