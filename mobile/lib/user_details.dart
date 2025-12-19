import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/app_colors.dart';
import 'services/tour_service.dart';
import 'models/user.dart';
import 'models/review.dart';
import 'user_settings.dart'; // Ensure this import is correct for UserProfileScreen
import 'review_list.dart';
import 'main.dart'; // Adjust import based on your project structure
import "package:easy_localization/easy_localization.dart";


// Enum to track which profile screen is currently active
enum ProfileScreenState {
  main,
  personalInfo,
  accountSecurity,
  appLanguage,
  helpSupport,
}

class UserDetailScreen extends ConsumerStatefulWidget {
  // NEW: Add isGuest parameter to the constructor
  final bool isGuest;
  final bool isOffline;

  const UserDetailScreen({Key? key, this.isGuest = false, this.isOffline = false})
    : super(key: key); // Default to false

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  late TourService _tourService;

  // Current screen state - starts with main profile
  ProfileScreenState _currentScreen = ProfileScreenState.main;

  // User data - would typically come from a user service or state management
  User? _user;
  bool _isLoadingUserDetails = true;

  List<Review> _reviews = [];
  int _totalReviewCount = 0;
  bool _isLoadingReviews = true;

  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tourService = ref.read(tourServiceProvider);
    if(widget.isOffline) {
      _isLoadingUserDetails = false;
      _isLoadingReviews = false;
      return;
    }

    // Only load user data if not in guest mode
    if (!widget.isGuest) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // Load all data in parallel
    await Future.wait([_loadUserDetails(), _loadUserReviews()]);
  }

  Future<void> _loadUserDetails() async {
    try {
      final userDetails = await _tourService.getUserDetails();
      if (mounted) {
        setState(() {
          _user = userDetails;
          _isLoadingUserDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserDetails = false;
        });
        _showError('Error loading user Details');
      }
    }
  }

  Future<void> _loadUserReviews() async {
    try {
      final result = await _tourService.getReviewByUser(3);
      final reviews = result.reviews;
      final totalCount = result.totalCount;
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _totalReviewCount = totalCount;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
        _showError('Error loading nearby tours');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Navigate to user settings
  void _navigateToUserSettings() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(),
      ),
    );
    if (result == true) {
      // If the user updated their profile, reload the data
      _loadData();
      setState(() {});
    }
  }

  // Navigate to home/explore screen
  void _navigateToExplore(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Build the main profile screen for a logged-in user
  Widget _buildMainProfileScreen(BuildContext context) {
    if (_isLoadingUserDetails || _user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Profile header with image, name and email
                SizedBox(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        // Profile image with camera icon
                        Stack(
                          children: [
                            // Profile image with border
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  color: Colors.blue.shade100,
                                  child: const Icon(
                                    Icons.person,
                                    size: 70,
                                    color: AppColors.accent,
                                  )
                                ),
                              ),
                            ),
                            // // Camera icon for changing profile picture
                            // Positioned(
                            //   bottom: 0,
                            //   right: 0,
                            //   child: Container(
                            //     padding: const EdgeInsets.all(4),
                            //     decoration: BoxDecoration(
                            //       color: AppColors.background,
                            //       shape: BoxShape.circle,
                            //       border: Border.all(
                            //         color: AppColors.primary,
                            //         width: 2,
                            //       ),
                            //     ),
                            //     child: const Icon(
                            //       Icons.camera_alt,
                            //       color: AppColors.primary,
                            //       size: 20,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // User name
                        Text(
                          '${_user!.name} ${_user!.surname}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // User email
                        Text(
                          _user!.mail,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Row(
                            children: [
                              const SizedBox(width: 165),
                              const Icon(
                                Icons.location_city,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _user!.city,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_user!.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    _user!.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'your_reviews'.tr(),
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${_totalReviewCount.toString()})',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 4),
                      const SizedBox(height: 16),
                      //load the first two elements from _reviews
                    if (_isLoadingReviews)
                      const Center(child: CircularProgressIndicator())
                    else if (_reviews.isNotEmpty) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          return _buildReviewItem(
                            name: _reviews[index].user,
                            date: _reviews[index].date,
                            rating: _reviews[index].rating,
                            comment: _reviews[index].comment,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          //TODO: Navigate to all review page
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ReviewListScreen(
                                      isTour: false,
                                      userId: _user!.id,
                                      reviewCount: _user!.reviewCount,
                                    ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'more'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            "no_reviews".tr(),
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ], ],
                  ),
                ),
                // // Bottom navigation bar
                // _buildBottomNavBar(context, 1), // 1 = Profile tab selected
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: AppColors.primary,
                  size: 30,
                ),
                onPressed: () {
                  _navigateToUserSettings();
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context, 1),
    );
  }

  // Build the guest profile screen
  Widget _buildGuestProfileScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Guest profile image
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Icon(Icons.person, size: 100, color: AppColors.textSecondary)
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'guest'.tr(), // As shown in profile_guest.jpg
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Implement Log In navigation
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const AuthFlowScreen(),
                                ),
                                (route) => false,
                              );                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(
                              'login'.tr(), // As shown in profile_guest.jpg
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // SizedBox(
                        //   width: double.infinity,
                        //   height: 50,
                        //   child: ElevatedButton(
                        //     onPressed: () {
                        //       // TODO: Implement Registrati navigation (Sign Up)
                        //       print('Navigate to Registrati (Sign Up) screen');
                        //     },
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: AppColors.primary,
                        //       foregroundColor: Colors.white,
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(25),
                        //       ),
                        //     ),
                        //     child: const Text(
                        //       'Registrati', // As shown in profile_guest.jpg
                        //       style: TextStyle(
                        //         fontSize: 16,
                        //         fontWeight: FontWeight.bold,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomNavBar(context, 1), // 1 = Profile tab selected
          ],
        ),
      ),
    );
  }

  // Build the bottom navigation bar
  Widget _buildBottomNavBar(BuildContext context, int selectedIndex) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: AppColors.navActive,
        unselectedItemColor: AppColors.navInactive,
        backgroundColor: AppColors.background,
        elevation: 0,
        onTap: (index) {
          if (index == 0) {
            // Navigate to Explore tab
            _navigateToExplore(context);
          } else {
            // Already on Profile tab, or handle other tabs
            // In a real app, you'd navigate to the respective root screen for each tab
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'explore_nav'.tr()),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'profile_nav'.tr()),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required String name,
    required String date,
    required double rating,
    required String comment,
    String imageUrl = "",
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 20,
                backgroundImage:
                    imageUrl.isNotEmpty ? AssetImage(imageUrl) : null,
                child:
                    imageUrl.isEmpty
                        ? const Icon(
                          Icons.person,
                          size: 24,
                          color: AppColors.textSecondary,
                        )
                        : null,
              ),
              const SizedBox(width: 12),

              // User name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Review comment
          Text(
            comment,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 8),

          // Read more button
          // GestureDetector(
          //   onTap: () {},
          //   child: const Text(
          //     'Read more',
          //     style: TextStyle(
          //       fontSize: 14,
          //       fontWeight: FontWeight.bold,
          //       color: AppColors.primary,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOffline) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal:24.0),
            child: Text(
              'offline_mode_user_details'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    // Conditional rendering based on isGuest
    if (widget.isGuest) {
      return _buildGuestProfileScreen(context);
    } else {
      return _buildMainProfileScreen(context);
    }
  }
}
