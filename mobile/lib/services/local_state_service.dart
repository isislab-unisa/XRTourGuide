import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


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

  Future<void> addScannedWaypoint(int tourId, int waypointId) async {
    final scannedWaypoints = await getScannedWaypoints(tourId);
    if (!scannedWaypoints.contains(waypointId)) {
      scannedWaypoints.add(waypointId);
      await saveScannedWaypoints(tourId, scannedWaypoints);
    }
  }

  // NUOVO: Verifica se un waypoint è stato scansionato
  Future<bool> isWaypointScanned(int tourId, int waypointId) async {
    final scannedWaypoints = await getScannedWaypoints(tourId);
    return scannedWaypoints.contains(waypointId);
  }

  // NUOVO: Rimuove un waypoint dai visitati (se necessario)
  Future<void> removeScannedWaypoint(int tourId, int waypointId) async {
    final scannedWaypoints = await getScannedWaypoints(tourId);
    scannedWaypoints.remove(waypointId);
    await saveScannedWaypoints(tourId, scannedWaypoints);
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

  Future<bool> isTourCompleted(int tourId) async {
    final completedTours = await getCompletedTours();
    return completedTours.contains(tourId);
  }

  // NUOVO: Cancella tutti i dati salvati
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // NUOVO: Cancella i dati di un tour specifico
  Future<void> clearTourData(int tourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$scannedWaypointsKey-$tourId');

    final completed = prefs.getStringList(completedToursKey) ?? [];
    completed.remove(tourId.toString());
    await prefs.setStringList(completedToursKey, completed);
  }

  final localStateServiceProvider = Provider<LocalStateService>((ref) {
    return LocalStateService();
  });

}
