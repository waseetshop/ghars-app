import 'plant.dart';

/// مهمة ري واحدة تظهر في شاشة "اليوم"
class TodayTask {
  final Plant plant;
  final String gardenId;
  final String gardenName;

  const TodayTask({
    required this.plant,
    required this.gardenId,
    required this.gardenName,
  });
}
