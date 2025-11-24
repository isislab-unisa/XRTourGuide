import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'models/app_colors.dart';
import 'elements/travel_list_item_card.dart';
import 'tour_details_page.dart';
import "category_detail_screen.dart";
import "search_screen.dart";
import 'user_details.dart';
import 'models/tour.dart';
import 'models/category.dart';
import 'services/tour_service.dart';
import 'services/offline_tour_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:easy_localization/easy_localization.dart";

class TravelExplorerScreen extends ConsumerStatefulWidget {
  final bool isGuest;

  const TravelExplorerScreen({Key? key, required this.isGuest})
    : super(key: key);

  @override
  ConsumerState<TravelExplorerScreen> createState() =>
      _TravelExplorerScreenState();
}

class _TravelExplorerScreenState extends ConsumerState<TravelExplorerScreen>
    with RouteAware {
  late TourService _tourService;
  late OfflineStorageService _offlineService;

  // State for online data
  List<Tour>? _nearbyTours;
  List<Category>? _categories = [];
  bool _isLoadingOnlineData = true;

  // State for offline data
  List<Map<String, dynamic>> _offlineTours = [];
  bool _isLoadingOfflineTours = true;

  // State for connectivity
  bool _isOnline = true;
  bool _isCheckingConnection = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _tourService = ref.read(tourServiceProvider);
    _offlineService = ref.read(offlineStorageServiceProvider);

    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (_) => _updateConnectionStatus(),
    );
  }

  Future<void> _checkInitialConnectivity() async {
    if (mounted) setState(() => _isCheckingConnection = true);
    await _updateConnectionStatus();
    if (mounted) setState(() => _isCheckingConnection = false);
  }

  Future<void> _updateConnectionStatus({bool forceReload = false}) async {
    final wasOnline = _isOnline;

    // 1. Check device connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final deviceConnected =
        connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);

    // 2. If device is connected, check server reachability
    bool serverReachable = false;
    if (deviceConnected) {
      print("CHECKING SERVER REACHABILITY");
      serverReachable = await _checkServerReachability();
    }

    final isNowOnline = deviceConnected && serverReachable;
    print("ONLINE?: ${isNowOnline}");

    if (wasOnline != isNowOnline || _isCheckingConnection || forceReload) {
      if (mounted) {
        setState(() {
          _isOnline = isNowOnline;
        });
        await _loadData();
      }
    }
  }

  Future<bool> _checkServerReachability() async {
    try {
      // Use a lightweight, public endpoint. getNearbyTours is a good candidate.
      return await _tourService.apiService.pingServer(
        timeout: const Duration(seconds: 2),
      ).timeout(const Duration(seconds: 2), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _updateConnectionStatus(forceReload: true); // Re-check connection and reload data
    super.didPopNext();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isOnline) {
      if (mounted) setState(() => _isLoadingOnlineData = true);
      await Future.wait([
        _loadNearbyTours(),
        _loadCategories(),
        _loadOfflineTours(),
      ]);
      if (mounted) setState(() => _isLoadingOnlineData = false);
    } else {
      await _loadOfflineTours();
    }
  }

  Future<void> _loadNearbyTours() async {
    try {
      final tours = await _tourService.getNearbyTours(0);
      if (mounted) setState(() => _nearbyTours = tours);
    } catch (e) {
      // Error is handled by reachability check, no need for snackbar here
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _tourService.getCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (e) {
      // Error is handled by reachability check
    }
  }

  Future<void> _loadOfflineTours() async {
    if (mounted) setState(() => _isLoadingOfflineTours = true);
    try {
      final tours = await _offlineService.getOfflineTours();
      if (mounted) setState(() => _offlineTours = tours);
    } catch (e) {
      _showError('error_loading_offline_tours'.tr());
    } finally {
      if (mounted) setState(() => _isLoadingOfflineTours = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingConnection) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(
          "XRTOURGUIDE",
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.06,
            fontWeight: FontWeight.bold,
            fontFamily: "point_panther",
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _updateConnectionStatus,
        child:
            _isOnline ? _buildOnlineBody(context) : _buildOfflineBody(context),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: 'explore_nav'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: 'profile_nav'.tr(),
          ),
        ],
        currentIndex: 0,
        selectedItemColor: AppColors.navActive,
        unselectedItemColor: AppColors.navInactive,
        showUnselectedLabels: true,
        onTap: (int index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserDetailScreen(isGuest: widget.isGuest, isOffline: !_isOnline),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildOnlineBody(BuildContext context) {
    // if (_isLoadingOnlineData) {
    //   return const Center(child: CircularProgressIndicator());
    // }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderImage(context),
          _buildSearchBar(context),
          // _buildOfflineToursSection(context),
          // _buildNearbyToursSection(context),
          // _buildCategoriesSection(context),
          if (_isLoadingOnlineData)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: const Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildNearbyToursSection(context),
            _buildCategoriesSection(context),
            _buildOfflineToursSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineBody(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.amber.withOpacity(0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                'offline_mode_message'.tr(),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: _buildOfflineToursSection(context),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderImage(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.25,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background_app.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.lightOverlay,
                    AppColors.background,
                  ],
                  stops: const [0.6, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: GestureDetector(
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SearchScreen(isGuest: widget.isGuest),
              ),
            ),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.searchBarBackground,
            borderRadius: BorderRadius.circular(30.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  'search_bar_hint'.tr(),
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineToursSection(BuildContext context) {
    if (_isLoadingOfflineTours)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      );
    if (_offlineTours.isEmpty) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Text(
              'offline_tours'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: screenHeight * 0.25,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _offlineTours.length,
              itemBuilder: (context, index) {
                final tour = _offlineTours[index];
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 20.0 : 0.0,
                    right: 15.0,
                  ),
                  child: OfflineTourCard(
                    tourData: tour,
                    cardWidth: screenWidth * 0.6,
                    imageHeight: 140,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => TourDetailScreen(
                                  tourId: tour['id'],
                                  isGuest: widget.isGuest,
                                  isOffline: true,
                                ),
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyToursSection(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Text(
              'recent_tours'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: screenHeight * 0.25,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _nearbyTours?.length ?? 0,
              itemBuilder: (context, index) {
                final tour = _nearbyTours![index];
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 20.0 : 0.0,
                    right: 15.0,
                  ),
                  child: TravelListItemCard(
                    tourId: tour.id,
                    imagePath: tour.imagePath,
                    title: tour.title,
                    description: tour.description,
                    cardWidth: screenWidth * 0.6,
                    imageHeight: 140,
                    category: tour.category,
                    rating: tour.rating,
                    reviewCount: tour.reviewCount,
                    totViews: tour.totViews.toString(),
                    creator: tour.creator,
                    lastEdited: tour.lastEdited,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => TourDetailScreen(
                                  tourId: tour.id,
                                  isGuest: widget.isGuest,
                                ),
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Text(
              'categories'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: screenHeight * 0.12,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories?.length ?? 0,
              itemBuilder: (context, index) {
                final category = _categories![index];
                return GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CategoryDetailScreen(
                                isGuest: widget.isGuest,
                                categoryName: category.name,
                                tours: const [],
                              ),
                        ),
                      ),
                  child: Container(
                    width: screenWidth * 0.4,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 20.0 : 0.0,
                      right: 10.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      image: DecorationImage(
                        image: AssetImage(category.image),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              color: AppColors.darkOverlay,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            category.name[0].toUpperCase() +
                                category.name.substring(1).toLowerCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class OfflineTourCard extends StatefulWidget {
  final Map<String, dynamic> tourData;
  final double cardWidth;
  final double imageHeight;
  final VoidCallback onTap;

  const OfflineTourCard({
    Key? key,
    required this.tourData,
    required this.cardWidth,
    required this.imageHeight,
    required this.onTap,
  }) : super(key: key);

  @override
  State<OfflineTourCard> createState() => _OfflineTourCardState();
}

class _OfflineTourCardState extends State<OfflineTourCard> {
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _getImagePath();
  }

  Future<void> _getImagePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final path =
        '${appDir.path}/offline_tours_data/tour_${widget.tourData['id']}/default_image.jpg';
    if (await File(path).exists()) {
      if (mounted) setState(() => _imagePath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.tourData['title'] ?? 'Untitled Tour';
    final String description = widget.tourData['description'] ?? '';

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.cardWidth,
        child: Card(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12.0),
                ),
                child: Container(
                  height: widget.imageHeight,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child:
                      _imagePath != null
                          ? Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade400,
                                ),
                          )
                          : Center(
                            child: Icon(
                              Icons.image,
                              color: Colors.grey.shade400,
                            ),
                          ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
