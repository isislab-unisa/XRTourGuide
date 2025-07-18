import 'package:flutter/material.dart';
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
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:easy_localization/easy_localization.dart";


class TravelExplorerScreen extends ConsumerStatefulWidget {
  final bool isGuest;

  const TravelExplorerScreen({Key? key, required this.isGuest}) : super(key: key);

  @override
  ConsumerState<TravelExplorerScreen> createState() => _TravelExplorerScreenState();
}

class _TravelExplorerScreenState extends ConsumerState<TravelExplorerScreen> with RouteAware {
  late TourService _tourService;

  // State variables for data
  List<Tour>? _nearbyTours;
  List<Tour>? _cookingTours;
  List<Category>? _categories = [];

  // INSIDE, OUTSIDE, THINGS, MIXED

  // Loading states
  bool _isLoadingNearby = true;
  bool _isLoadingCooking = true;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _tourService = ref.read(tourServiceProvider);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _loadData(); // Reload data when returning to this screen
    super.didPopNext();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load all data in parallel
    await Future.wait([
      _loadNearbyTours(),
      // _loadCookingTours(),
      _loadCategories(),
    ]);
  }

  Future<void> _loadNearbyTours() async {
    try {
      final tours = await _tourService.getNearbyTours();
      if (mounted) {
        setState(() {
          _nearbyTours = tours;
          _isLoadingNearby = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNearby = false;
        });
        _showError('error_loading_tours'.tr());
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _tourService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
        _showError('error_loading_categories'.tr());
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Build a category item widget
  Widget _buildCategoryItem({
    required BuildContext context,
    required int index,
    required double width,
    required Category category,
    EdgeInsets? margin,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => CategoryDetailScreen(
                  isGuest: widget.isGuest,
                  categoryName: category.name,
                  tours:
                      _nearbyTours ??
                      [], // Pass relevant tours for the category
                ),
          ),
        );
      },
      child: Container(
        width: width,
        margin:
            margin ??
            EdgeInsets.only(left: index == 0 ? 20.0 : 0.0, right: 10.0),
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
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(
          "XRTOURGUIDE",
          style: TextStyle(
            fontSize: screenWidth * 0.06,
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
        onRefresh: _loadData,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: screenHeight * 0.25,
                    width: screenWidth,
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
                  ),
                ],
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder:
                            (context, animation, secondaryAnimation) =>
                                SearchScreen(isGuest: widget.isGuest),
                        transitionsBuilder: (
                          context,
                          animation,
                          secondaryAnimation,
                          child,
                        ) {
                          const begin = Offset(0.0, 0.05);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;

                          var slideAnimation = Tween(
                            begin: begin,
                            end: end,
                          ).animate(
                            CurvedAnimation(parent: animation, curve: curve),
                          );

                          var fadeAnimation = Tween(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(
                            CurvedAnimation(parent: animation, curve: curve),
                          );

                          return FadeTransition(
                            opacity: fadeAnimation,
                            child: SlideTransition(
                              position: slideAnimation,
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 250),
                      ),
                    );
                  },
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
                          Icon(Icons.search, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Text(
                            'search_bar_hint'.tr(),
                            style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Nearby Tours Section
              Padding(
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: screenHeight * 0.25,
                      child:
                          _isLoadingNearby
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
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
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => TourDetailScreen(
                                                  tourId: tour.id,
                                                  // tourName: tour.title,
                                                  // location: tour.location,
                                                  // rating: tour.rating,
                                                  // reviewCount: tour.reviewCount,
                                                  // images: tour.images,
                                                  // category: tour.category,
                                                  // description: tour.description,
                                                  // creator: tour.creator,
                                                  // lastEdited: tour.lastEdited,
                                                  // totViews: tour.totViews.toString(),
                                                  // latitude: tour.latitude,
                                                  // longitude: tour.longitude,
                                                  isGuest: widget.isGuest,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),

              // Categories Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 20.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'categories'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    // TextButton(
                    //   onPressed: () {
                    //     // TODO: Navigate to categories screen
                    //   },
                    //   child: Text(
                    //     'See More',
                    //     style: TextStyle(color: AppColors.primary),
                    //   ),
                    // ),
                  ],
                ),
              ),

              SizedBox(
                height: screenHeight * 0.12,
                child:
                    _isLoadingCategories
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories?.length ?? 0,
                          itemBuilder: (context, index) {
                            return _buildCategoryItem(
                              context: context,
                              index: index,
                              width: screenWidth * 0.4,
                              category: _categories![index],
                            );
                          },
                        ),
              ),

              // Cooking Tours Section
              // Padding(
              //   padding: const EdgeInsets.symmetric(vertical: 10.0),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Padding(
              //         padding: const EdgeInsets.symmetric(
              //           horizontal: 20.0,
              //           vertical: 10.0,
              //         ),
              //         child: Text(
              //           'Cooking Tours around you',
              //           style: TextStyle(
              //             fontSize: 20,
              //             fontWeight: FontWeight.bold,
              //             color: AppColors.textPrimary,
              //           ),
              //         ),
              //       ),
              //       SizedBox(
              //         height: screenHeight * 0.3,
              //         child:
              //             _isLoadingCooking
              //                 ? const Center(child: CircularProgressIndicator())
              //                 : ListView.builder(
              //                   scrollDirection: Axis.horizontal,
              //                   itemCount: _cookingTours?.length ?? 0,
              //                   itemBuilder: (context, index) {
              //                     final tour = _cookingTours![index];
              //                     return Padding(
              //                       padding: EdgeInsets.only(
              //                         left: index == 0 ? 20.0 : 0.0,
              //                         right: 15.0,
              //                       ),
              //                       child: TravelListItemCard(
              //                         tourId: tour.id,
              //                         imagePath: tour.imagePath,
              //                         title: tour.title,
              //                         description: tour.description,
              //                         cardWidth: screenWidth * 0.6,
              //                         imageHeight: 180,
              //                         category: tour.category,
              //                         rating: tour.rating,
              //                         reviewCount: tour.reviewCount,
              //                         onTap: () {
              //                           Navigator.push(
              //                             context,
              //                             MaterialPageRoute(
              //                               builder:
              //                                   (context) => TourDetailScreen(
              //                                     tourId: tour.id,
              //                                     isGuest: widget.isGuest,
              //                                   ),
              //                             ),
              //                           );
              //                         },
              //                       ),
              //                     );
              //                   },
              //                 ),
              //       ),
              //     ],
              //   ),
              // ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'explore_nav'.tr()),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'profile_nav'.tr(),
          ),
        ],
        currentIndex: 0,
        selectedItemColor: AppColors.navActive,
        unselectedItemColor: AppColors.navInactive,
        showUnselectedLabels: true,
        onTap: (int index) {
          if (index == 0) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => UserDetailScreen(isGuest: widget.isGuest)),
            );
          }
        },
      ),
    );
  }
}
