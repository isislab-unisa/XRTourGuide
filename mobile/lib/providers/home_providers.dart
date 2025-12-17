import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tour.dart';
import '../models/category.dart';
import '../services/tour_service.dart';

// Stato per i tour vicini
class NearbyToursState {
  final List<Tour>? tours;
  final bool isLoading;
  final DateTime? lastUpdated;

  NearbyToursState({this.tours, this.isLoading = false, this.lastUpdated});

  NearbyToursState copyWith({
    List<Tour>? tours,
    bool? isLoading,
    DateTime? lastUpdated,
  }) {
    return NearbyToursState(
      tours: tours ?? this.tours,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class NearbyToursNotifier extends StateNotifier<NearbyToursState> {
  final TourService _tourService;

  NearbyToursNotifier(this._tourService) : super(NearbyToursState());

  Future<void> loadTours({
    bool forceRefresh = false,
    double? lat,
    double? lon,
  }) async {
    // Se abbiamo già i dati e non è un refresh forzato, non fare nulla
    if (!forceRefresh && state.tours != null && state.tours!.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      List<Tour> tours;
      if (lat != null && lon != null) {
        tours = await _tourService.getNearbyTours(0, lat, lon);
      } else {
        tours = await _tourService.getAllNearbyTours(0);
      }
      state = state.copyWith(
        tours: tours,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print("Error loading tours: $e");
    }
  }
}

final nearbyToursProvider =
    StateNotifierProvider<NearbyToursNotifier, NearbyToursState>((ref) {
      final tourService = ref.watch(tourServiceProvider);
      return NearbyToursNotifier(tourService);
    });

// Provider per le categorie (usiamo FutureProvider ma con keepAlive per caching semplice)
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final tourService = ref.watch(tourServiceProvider);
  return tourService.getCategories();
});
