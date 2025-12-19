import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/app_colors.dart';
import 'services/tour_service.dart';
import 'models/user.dart';
import 'main.dart'; // Import your main app file for navigation
import 'services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';


// Enum to track which profile screen is currently active
enum ProfileScreenState {
  main,
  personalInfo,
  accountSecurity,
  appLanguage,
  helpSupport,
}

// final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
//   return AuthService();
// });


class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  late TourService _tourService;

  late AuthService _authService;

  // Current screen state - starts with main profile
  ProfileScreenState _currentScreen = ProfileScreenState.main;

  // User data - would typically come from a user service or state management
  User? _user;
  bool _isLoadingUserDetails = true;

  // Security settings
  bool _biometricEnabled = false;
  bool _faceIdEnabled = false;

  // Language settings
  //TODO : Implement language selection logic
  final List<Map<String, dynamic>> _availableLanguages = [
    {"name": "English(US)", "locale": const Locale('en', 'US'), "flag": "🇺🇸", "selected": false},
    {"name": "Italiano", "locale": const Locale('it', 'IT'), "flag": "🇮🇹", "selected": true},
  ];

  // Controllers for text fields (Personal Info)
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  final TextEditingController _emailController = TextEditingController();

  // NEW: Controllers for Change Password fields
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _tourService = ref.read(tourServiceProvider);
    _loadData();
  }

  Future<void> _loadData() async {
    // Load all data in parallel
    await Future.wait([_loadUserDetails()]);
  }

  Future<void> _loadUserDetails() async {
    try {
      final userDetails = await _tourService.getUserDetails();
      if (mounted) {
        setState(() {
          _user = userDetails;
          _isLoadingUserDetails = false;
          // Initialize text controllers with current values
          _firstNameController.text = _user!.name;
          _lastNameController.text = _user!.surname;
          _emailController.text = _user!.mail;
          _descriptionController.text = _user?.description ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserDetails = false;
          // Set an error message if loading fails
          // _error = 'Failed to load user details: $e'; // You can uncomment this if you want to display the error directly
        });
        _showError('Error loading user Details');
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose(); // NEW: Dispose password controllers
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  // Navigate to the main profile screen
  void _navigateToMainProfile() {
    setState(() {
      _currentScreen = ProfileScreenState.main;
    });
  }

  // Navigate to personal info screen
  void _navigateToPersonalInfo() {
    setState(() {
      _currentScreen = ProfileScreenState.personalInfo;
    });
  }

  // Navigate to account security screen
  void _navigateToAccountSecurity() {
    setState(() {
      _currentScreen = ProfileScreenState.accountSecurity;
    });
  }

  // Navigate to app language screen
  void _navigateToAppLanguage() {
    setState(() {
      _currentScreen = ProfileScreenState.appLanguage;
    });
  }

  // Navigate to help & support screen
  void _navigateToHelpSupport() {
    setState(() {
      _currentScreen = ProfileScreenState.helpSupport;
    });
  }

  // Navigate to home/explore screen
  void _navigateToExplore(BuildContext context) {
    // Navigate to TravelExplorerScreen
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(builder: (context) => const TravelExplorerScreen()),
    // );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // Show logout confirmation bottom sheet
  void _showLogoutConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _buildLogoutBottomSheet(context);
      },
    );
  }

  // NEW: Show Change Password bottom sheet
  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to take full height if needed
      backgroundColor: Colors.transparent, // For custom rounded corners
      builder: (BuildContext context) {
        return _buildChangePasswordSheet(context);
      },
    );
  }

  void _showDeleteAccountSheet(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _buildDeleteAccountSheet(context);
      },
    );

    if (result == true && mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('delete_account_success'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      // Esegui logout o naviga alla schermata iniziale
      _logout(context);
    }

  }

void _handleBack(BuildContext context) {
  if (_currentScreen == ProfileScreenState.main) {
    Navigator.of(context).pop(true); // Torna alla schermata precedente
  } else {
    setState(() {
      _currentScreen = ProfileScreenState.main; // Torna alla schermata principale del profilo
    });
  }
}

  // Save personal info changes
  void _savePersonalInfo() async {
    //TODO: Implement actual save logic, e.g., API call to update user details
      _authService.updateAccount(
      _firstNameController.text,
      _lastNameController.text,
      _emailController.text,
      _descriptionController.text,
    );

    await _loadUserDetails(); // Reload user details after saving

    setState(() {
      // _fullName = _nameController.text;
      // _email = _emailController.text;
      _currentScreen = ProfileScreenState.main;
    });
    // Show a snackbar to confirm changes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('personal_info_update_success'.tr()),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // Save language selection
  void _saveLanguageSelection(Locale selectedLocale) {

    context.setLocale(selectedLocale);

    setState(() {
      _currentScreen = ProfileScreenState.main;
    });

    // Show a snackbar to confirm changes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('language_updated'.tr()),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // NEW: Handle Change Password logic
  void _changePassword() {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmNewPasswordController.text;

    if (newPassword != confirmPassword) {
      _showError('new_password_mismatch'.tr());
      return;
    }
    if (newPassword.length < 6) {
      // Example validation
      _showError('new_password_min_length');
      return;
    }

    print('Attempting to change password:');
    print('Old: $oldPassword, New: $newPassword');

    _authService.updatePassword(oldPassword, newPassword);

    Navigator.of(context).pop(); // Close the bottom sheet

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('password_update_success'.tr()),
        backgroundColor: AppColors.success,
      ),
    );

    // Clear controllers after successful change
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmNewPasswordController.clear();
  }

  // Perform logout action
  void _logout(BuildContext context) async {
    final authService = ref.read(authServiceProvider);

    // In a real app, you would clear user session, tokens, etc.
    Navigator.of(context).pop(); // Close the bottom sheet
    await authService.logout(); // Call the logout method from AuthService
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const AuthChecker(),
      ),
      (route) => false,
    );                            
    // Navigate back to login or onboarding screen
    print('User logged out');
  }

  // Build the main profile screen
  Widget _buildMainProfileScreen(BuildContext context) {
    if (_isLoadingUserDetails || _user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => _handleBack(context),
        ),
        // No leading icon on the main profile screen if it's a root tab
        // If it's pushed onto a stack, you might want a back button here
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Profile header with image, name and email
            Expanded(
              child: ListView(
                children: [
                  // Profile image and info
                  Container(
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
                                  ),
                                ),
                              ),
                            ),
                            // Camera icon for changing profile picture
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
                      ],
                    ),
                  ),

                  // Menu items
                  // Personal Info
                  _buildMenuItemTile(
                    title: 'personal_info_title'.tr(),
                    icon: Icons.person_outline,
                    onTap: _navigateToPersonalInfo,
                  ),

                  // Account & Security
                  _buildMenuItemTile(
                    title: 'account_security_title'.tr(),
                    icon: Icons.security,
                    onTap: _navigateToAccountSecurity,
                  ),

                  // App Language
                  _buildMenuItemTile(
                    title: 'app_language_title'.tr(),
                    icon: Icons.language,
                    onTap: _navigateToAppLanguage,
                  ),

                  // Help & Support
                  // _buildMenuItemTile(
                  //   title: 'help_support_title'.tr(),
                  //   icon: Icons.help_outline,
                  //   onTap: _navigateToHelpSupport,
                  // ),

                  // Logout - with different styling
                  _buildMenuItemTile(
                    title: 'Logout',
                    icon: Icons.logout,
                    textColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () => _showLogoutConfirmation(context),
                  ),
                ],
              ),
            ),

            // Bottom navigation bar
            // _buildBottomNavBar(context, 1), // 1 = Profile tab selected
          ],
        ),
      ),
    );
  }

  // Build a menu item tile with icon and title
  Widget _buildMenuItemTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color textColor = AppColors.textPrimary,
    Color iconColor = AppColors.textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Build the personal info screen
  Widget _buildPersonalInfoScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'personal_info_title'.tr(),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name field
                    Text(
                      'name'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        hintText: 'name_hint',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'surname'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        hintText: 'surname_hint'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),


                    // Email field
                    Text(
                      'email'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'mail_hint'.tr(),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'description'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'description_hint'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),



            // Save button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _savePersonalInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'save'.tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build the account security screen
  Widget _buildAccountSecurityScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'account_security_title',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // // Biometric ID toggle (Commented out as in your original)
                  // _buildToggleSettingTile(
                  //   title: 'Biometric ID',
                  //   value: _biometricEnabled,
                  //   onChanged: (value) {
                  //     setState(() {
                  //       _biometricEnabled = value;
                  //     });
                  //   },
                  // ),

                  // // Face ID toggle (Commented out as in your original)
                  // _buildToggleSettingTile(
                  //   title: 'Face ID',
                  //   value: _faceIdEnabled,
                  //   onChanged: (value) {
                  //     setState(() {
                  //       _faceIdEnabled = value;
                  //     });
                  //   },
                  // ),

                  // Change Password option - NOW CALLS THE BOTTOM SHEET
                  _buildSettingTile(
                    title: 'change_password'.tr(),
                    onTap: () {
                      _showChangePasswordSheet(
                        context,
                      ); // NEW: Call the change password sheet
                    },
                  ),

                  // Delete Account option - with red text
                  _buildSettingTile(
                    title: 'delete_account_title'.tr(),
                    titleColor: Colors.red,
                    subtitle:
                        'delete_account_subtitle'.tr(),
                    onTap: () {
                      _showDeleteAccountSheet(context);
                      // Show delete account confirmation
                    },
                  ),
                ],
              ),
            ),

            // Bottom navigation bar
            _buildBottomNavBar(context, 1), // 1 = Profile tab selected
          ],
        ),
      ),
    );
  }

  // Build a toggle setting tile with better visibility
  Widget _buildToggleSettingTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.lightGrey,
            trackOutlineColor: MaterialStateProperty.resolveWith<Color?>((
              Set<MaterialState> states,
            ) {
              if (states.contains(MaterialState.selected)) {
                return AppColors.primary;
              }
              return AppColors.border;
            }),
          ),
        ],
      ),
    );
  }

  // Build a setting tile with optional subtitle
  Widget _buildSettingTile({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color titleColor = AppColors.textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Build the app language screen
  Widget _buildAppLanguageScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => _handleBack(context),
        ),
        title: Text(
          'language'.tr(),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _availableLanguages.length,
                itemBuilder: (context, index) {
                  final language = _availableLanguages[index];
                  final languageLocale = language["locale"] as Locale;
                  final isSelected = context.locale == languageLocale; 

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _saveLanguageSelection(languageLocale);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          // Flag emoji
                          Text(
                            language["flag"],
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 16),
                          // Language name
                          Text(
                            language["name"],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          // Checkmark for selected language
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build the help & support screen (placeholder)
  Widget _buildHelpSupportScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => _handleBack(context),
        ),
        title: const Text(
          'help_support_title',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildSettingTile(
                    title: 'FAQs',
                    onTap: () {
                      print('Navigate to FAQs');
                    },
                  ),
                  _buildSettingTile(
                    title: 'Contact Support',
                    onTap: () {
                      print('Navigate to Contact Support');
                    },
                  ),
                  _buildSettingTile(
                    title: 'Report a Bug',
                    onTap: () {
                      print('Navigate to Report a Bug');
                    },
                  ),
                  _buildSettingTile(
                    title: 'Privacy Policy',
                    onTap: () {
                      print('Navigate to Privacy Policy');
                    },
                  ),
                  _buildSettingTile(
                    title: 'Terms of Service',
                    onTap: () {
                      print('Navigate to Terms of Service');
                    },
                  ),
                ],
              ),
            ),

            // Bottom navigation bar
            _buildBottomNavBar(context, 1), // 1 = Profile tab selected
          ],
        ),
      ),
    );
  }

  // Build the logout confirmation bottom sheet
  Widget _buildLogoutBottomSheet(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar at top of sheet
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Logout title
          const Text(
            'Logout',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const Divider(),

          const SizedBox(height: 20),

          // Logout icon and message
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(Icons.logout, color: Colors.red[400], size: 30),
          ),

          const SizedBox(height: 20),

          Text(
            'logout_confirm'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 30),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                // Cancel button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'cancel'.tr(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Logout button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'logout_confirm_yes'.tr(),
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountSheet(BuildContext context) {
  final TextEditingController _deletePasswordController = TextEditingController();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'delete_account_title'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_forever, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'delete_account_confirm'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Password field
                  TextField(
                    controller: _deletePasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'delete_account_password'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the sheet
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'cancel'.tr(),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _authService.deleteAccount(_deletePasswordController.text);
                            Navigator.of(context).pop(true); // Close the sheet
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'delete_account_confirm_yes'.tr(),
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Build the Change Password bottom sheet
  Widget _buildChangePasswordSheet(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        // Allow scrolling for keyboard
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'change_password'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Old Password
                  Text(
                    'old_password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _oldPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'old_password_hint',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // New Password
                  Text(
                    'new_password'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'new_password_hint'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm New Password
                  Text(
                    'confirm_new_password'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmNewPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'confirm_new_password'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the sheet
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'cancel'.tr(),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _changePassword, // Call password change logic
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, // As per image
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'change'.tr(),
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return the appropriate screen based on current state
    switch (_currentScreen) {
      case ProfileScreenState.main:
        return _buildMainProfileScreen(context);
      case ProfileScreenState.personalInfo:
        return _buildPersonalInfoScreen(context);
      case ProfileScreenState.accountSecurity:
        return _buildAccountSecurityScreen(context);
      case ProfileScreenState.appLanguage:
        return _buildAppLanguageScreen(context);
      case ProfileScreenState.helpSupport:
        return _buildHelpSupportScreen(context);
      default:
        return _buildMainProfileScreen(context);
    }
  }
}
