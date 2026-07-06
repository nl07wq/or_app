import '../models/training_template.dart';

const defaultTrainingTemplates = [
  TrainingTemplate(
    name: 'Upper Body',
    exercises: ['ベンチプレス', 'ラットプルダウン','レッグプレス', 'ショルダープレス'],
  ),

  TrainingTemplate(
    name: 'Chest',
    exercises: ['ベンチプレス', 'インクラインベンチプレス', 'チェストプレス'],
  ),

  TrainingTemplate(
    name: 'Pull',
    exercises: ['ラットプルダウン', 'シーテッドロー', 'Dumbbell Curl'],
  ),

  TrainingTemplate(name: 'Leg', exercises: ['スクワット', 'レッグプレス', 'レッグカール']),
];
