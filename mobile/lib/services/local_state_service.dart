import 'package:shared_preferences/shared_preferences.dart';

class LocalStateService {
  static const String scannedWaypointsKey = 'scanned_waypoints';
  static const String completedToursKey = 'completed_tours';

  // Salva i waypoint scansionati per un tour
  Future<void> saveScannedWaypoints(int tourId, List<int> waypointIds) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      '$scannedWaypointsKey-$tourId',
      waypointIds.map((e) => e.toString()).toList(),
    );
  }

  // Recupera i waypoint scansionati per un tour
  Future<List<int>> getScannedWaypoints(int tourId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('$scannedWaypointsKey-$tourId') ?? [];
    return ids.map(int.parse).toList();
  }

  // Salva un tour come completato
  Future<void> markTourCompleted(int tourId) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(completedToursKey) ?? [];
    if (!completed.contains(tourId.toString())) {
      completed.add(tourId.toString());
      prefs.setStringList(completedToursKey, completed);
    }
  }

  // Recupera la lista dei tour completati
  Future<List<int>> getCompletedTours() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(completedToursKey) ?? [];
    return ids.map(int.parse).toList();
  }
}
