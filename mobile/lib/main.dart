import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/app_colors.dart';
import 'home_screen.dart';
import 'package:flutter_downloader/flutter_downloader.dart'; // Import flutter_downloader
import 'services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

// This is a top-level function and MUST NOT be a method of a class.
// It serves as the entry point for FlutterDownloader's background tasks.
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  print('Download task ($id) is $status and progress is $progress');
  // You can implement custom logic here, like updating UI using isolates or state management.
}

// final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
//   return AuthService();
// });

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for plugin initialization
  await FlutterDownloader.initialize(
    debug: true, // Set to false in production for less console output
    ignoreSsl: false, // Set to true if you need to ignore SSL verification (not recommended for production)
  );

  // Register the callback function for background downloads
  FlutterDownloader.registerCallback(downloadCallback);

  // Set transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );


  runApp(
    const ProviderScope(child: MyApp()),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XR Tour Guide',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: AppColors.accent,
        ),
        // scaffoldBackgroundColor: AppColors.background,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: TextStyle(color: AppColors.textSecondary),
        ),
      ),
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends ConsumerWidget {
  const AuthChecker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    switch (authService.authStatus) {
      case AuthStatus.loading:
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()),
        );      
      case AuthStatus.authenticated:
        return const TravelExplorerScreen(isGuest: false);
      case AuthStatus.unauthenticated:
        return const AuthFlowScreen();
      case AuthStatus.registering:
        return const AuthFlowScreen(registeredTemp: true,); // You can handle this state differently if needed
    }
  }
}

enum AuthState { onboarding, login, register }

class AuthFlowScreen extends ConsumerStatefulWidget {
  final bool registeredTemp;


  const AuthFlowScreen({Key? key, this.registeredTemp = false}) : super(key: key);

  @override
  ConsumerState<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends ConsumerState<AuthFlowScreen> {
  AuthState currentState = AuthState.onboarding;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // Controllers for form fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.registeredTemp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registered successfully, now verify your email to login'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 40, left: 16, right: 16),
            duration: Duration(seconds: 5),
          ),
        );
      });  
    } 
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    setState(() {
      currentState = AuthState.login;
    });
  }

  void _navigateToRegister() {
    setState(() {
      currentState = AuthState.register;
    });
  }

  void _navigateToOnboarding() {
    setState(() {
      currentState = AuthState.onboarding;
    });
  }

  Widget _buildSocialButton({
    required String text,
    required Widget icon,
    required VoidCallback onPressed,
    required BuildContext context,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth > 600 ? 400 : double.infinity,
      height: 50,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? (screenWidth - 400) / 2 : 20,
        vertical: 8,
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          backgroundColor: AppColors.background,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    required BuildContext context,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth > 600 ? 400 : double.infinity,
      height: 50,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? (screenWidth - 400) / 2 : 20,
        vertical: 16,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 2,
          shadowColor: AppColors.cardShadow,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required BuildContext context,
    bool isPassword = false,
    bool isEmail = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          width: screenWidth > 600 ? 400 : double.infinity,
          child: TextField(
            controller: controller,
            obscureText: isPassword ? _obscurePassword : false,
            keyboardType:
                isEmail ? TextInputType.emailAddress : TextInputType.text,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: Icon(icon, color: AppColors.textSecondary),
              suffixIcon:
                  isPassword
                      ? IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      )
                      : null,
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
              filled: true,
              fillColor: AppColors.searchBarBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;
          final isTablet = screenWidth > 600;

          return SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - MediaQuery.of(context).padding.top,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: screenHeight * 0.1,
                        bottom: screenHeight * 0.05,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Iniziamo!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 80 : 40,
                            ),
                            child: const Text(
                              'Welcome to your journey! We\'re thrilled to have you here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.08),
                          _buildSocialButton(
                            text: 'Continue With Google',
                            icon: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(
                                    'https://developers.google.com/identity/images/g-logo.png',
                                  ),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            onPressed: () async {
                              print('Google login tapped');
                            },
                            context: context,
                          ),
                          _buildSocialButton(
                            text: 'Continue With Facebook',
                            icon: const Icon(
                              Icons.facebook,
                              color: Colors.blue,
                              size: 24,
                            ),
                            onPressed: () {
                              print('Facebook login tapped');
                            },
                            context: context,
                          ),
                          // _buildSocialButton(
                          //   text: 'Continue With Apple',
                          //   icon: const Icon(
                          //     Icons.apple,
                          //     color: Colors.black,
                          //     size: 24,
                          //   ),
                          //   onPressed: () {
                          //     print('Apple login tapped');
                          //   },
                          //   context: context,
                          // ),
                          const SizedBox(height: 20),
                          Container(
                            margin: EdgeInsets.symmetric(
                              horizontal:
                                  isTablet ? (screenWidth - 400) / 2 : 20,
                            ),
                            width: isTablet ? 400 : double.infinity,
                            child: const Row(
                              children: [
                                Expanded(
                                  child: Divider(color: AppColors.divider),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: AppColors.divider),
                                ),
                              ],
                            ),
                          ),
                          _buildPrimaryButton(
                            text: 'Log In',
                            onPressed: _navigateToLogin,
                            context: context,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: screenHeight * 0.05),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Non ha un account? ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: _navigateToRegister,
                            child: const Text(
                              'Registrati',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildPrimaryButton(
                      text: 'Guest Log In',
                      onPressed: () {
                        setState(() {
                          //navigate to main page as guest
                          // TODO: Replace this with your actual navigation logic
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      TravelExplorerScreen(isGuest: true),
                            ),
                          );
                        });
                      },
                      context: context,
                    ),

                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginScreen() {

    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _navigateToOnboarding,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;
          final isTablet = screenWidth > 600;
          final horizontalPadding = isTablet ? (screenWidth - 400) / 2 : 20.0;

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Accedi Al Tuo Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: isTablet ? 400 : double.infinity,
                      child: const Text(
                        'Welcome back! Please log in to your account to continue where you left off.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    _buildInputField(
                      label: 'Username',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      isEmail: true,
                      context: context,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    _buildInputField(
                      label: 'Password',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      isPassword: true,
                      context: context,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: isTablet ? 400 : double.infinity,
                      margin: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                activeColor: AppColors.primary,
                                checkColor: Colors.white,
                              ),
                              const Text(
                                'Ricordami',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              //TODO: Implement forgot password logic
                              print('Forgot password tapped');
                            },
                            child: const Text(
                              'Dimenticata La Password?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildPrimaryButton(
                      text: 'Log In',
                      onPressed: () async {
                        print("UserLogin");
                        try {
                          await authService.login(
                            _emailController.text,
                            _passwordController.text,
                          );
                        } catch (e) {
                          _showError(authService.loginErrorMessage ?? 'Login failed');
                        }
                      },
                      context: context,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: isTablet ? 400 : double.infinity,
                      margin: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.divider)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialIconButton(
                          icon: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          //TODO
                          onPressed: () => print('Google login'),
                        ),
                        const SizedBox(width: 20),
                        _buildSocialIconButton(
                          icon: const Icon(
                            Icons.facebook,
                            color: Colors.blue,
                            size: 28,
                          ),
                          //TODO
                          onPressed: () => print('Facebook login'),
                        ),
                        // const SizedBox(width: 20),
                        // _buildSocialIconButton(
                        //   icon: const Icon(
                        //     Icons.apple,
                        //     color: Colors.black,
                        //     size: 28,
                        //   ),
                        //   //TODO
                        //   onPressed: () => print('Apple login'),
                        // ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Non ha un account? ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: _navigateToRegister,
                            child: const Text(
                              'Registrati',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSocialIconButton({
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(30),
        color: AppColors.background,
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(onPressed: onPressed, icon: icon),
    );
  }

  Widget _buildRegisterScreen() {

    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _navigateToOnboarding,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;
          final isTablet = screenWidth > 600;
          final horizontalPadding = isTablet ? (screenWidth - 400) / 2 : 20.0;

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Crea Il Tuo Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: isTablet ? 400 : double.infinity,
                      child: const Text(
                        'Please fill in your details to create your account and enjoy our services.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    _buildInputField(
                      label: 'Username',
                      controller: _usernameController,
                      icon: Icons.person_outline,
                      context: context,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    _buildInputField(
                      label: 'Name',
                      controller: _nameController,
                      icon: Icons.person_outline,
                      context: context,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    _buildInputField(
                      label: 'Surname',
                      controller: _surnameController,
                      icon: Icons.person_outline,
                      context: context,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    _buildInputField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      isEmail: true,
                      context: context,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    //TODO: Add password input field with validation
                    _buildInputField(
                      label: 'Password',
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      isPassword: true,
                      context: context,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    //TODO: Add city input field with city research functionality
                    _buildInputField(
                      label: 'City',
                      controller: _cityController,
                      icon: Icons.location_city_outlined,
                      context: context,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    _buildInputField(
                      label: 'Description',
                      controller: _descriptionController,
                      icon: Icons.description_outlined,
                      context: context,
                    ),

                    _buildPrimaryButton(
                      text: 'Sign Up',
                      onPressed: () {
                        setState(() {
                          // Simulate successful login and navigate to main page
                          // TODO: Replace this with your actual navigation logic
                          // Navigator.of(context).pushReplacement(
                          //   MaterialPageRoute(
                          //     builder: (context) => TravelExplorerScreen(isGuest: false),
                          //   ),
                          // );
                          authService.register(
                            _usernameController.text,
                            _passwordController.text,
                            _nameController.text,
                            _surnameController.text,
                            _emailController.text,
                            _descriptionController.text,
                            _cityController.text,
                          );
                        });
                      },
                      context: context,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: isTablet ? 400 : double.infinity,
                      margin: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.divider)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialIconButton(
                          icon: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          //TODO: Add Google register logic
                          onPressed: () => print('Google register'),
                        ),
                        const SizedBox(width: 20),
                        _buildSocialIconButton(
                          icon: const Icon(
                            Icons.facebook,
                            color: Colors.blue,
                            size: 28,
                          ),
                          //TODO: Add Facebook register logic
                          onPressed: () => print('Facebook register'),
                        ),
                        // const SizedBox(width: 20),
                        // _buildSocialIconButton(
                        //   icon: const Icon(
                        //     Icons.apple,
                        //     color: Colors.black,
                        //     size: 28,
                        //   ),
                        //   //TODO: Add Apple register logic
                        //   onPressed: () => print('Apple register'),
                        // ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hai già un account? ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: _navigateToLogin,
                            child: const Text(
                              'Accedi',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (currentState) {
      case AuthState.onboarding:
        return _buildOnboardingScreen();
      case AuthState.login:
        return _buildLoginScreen();
      case AuthState.register:
        return _buildRegisterScreen();
    }
  }
}
