import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'models/app_colors.dart';
import 'main.dart'; // Importiamo main per accedere a AuthFlowScreen

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  void _selectServerAndProceed(BuildContext context, String ip) {
    // 1. Imposta il server
    // context.setLocale(locale);

    // 2. Naviga alla schermata di Auth/Onboarding
    // Usiamo pushReplacement per non permettere di tornare indietro alla selezione lingua
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthChecker()),
    );
  }

  // Copiato lo stile del pulsante da main.dart per coerenza totale
  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    required BuildContext context,
    bool isOutlined = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: screenWidth > 600 ? 400 : double.infinity,
      height: 50,
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? (screenWidth - 400) / 2 : 20,
        vertical:
            8, // Ridotto leggermente il margine verticale per raggrupparli
      ),
      child:
          isOutlined
              ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  backgroundColor: AppColors.background,
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              : ElevatedButton(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Stesso sfondo di main.dart
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- SEZIONE TESTO (Simile a onboarding_title) ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Logo o Icona (Opzionale, se vuoi)
                          // Icon(Icons.travel_explore, size: 80, color: AppColors.primary),
                          // SizedBox(height: 20),
                          Text(
                            "XRTOURGUIDE", // O usa una chiave di traduzione se preferisci
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 80 : 20,
                            ),
                            child: Text(
                              "server_selection_description".tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.1), // Spazio centrale
                    // --- SEZIONE PULSANTI ---
                    _buildPrimaryButton(
                      text: 'Comunità Montana del Bussento',
                      context: context,
                      onPressed:
                          () => _selectServerAndProceed(
                            context,
                            "",
                          ),
                    ),

                    _buildPrimaryButton(
                      text: 'Unisa',
                      context: context,
                      isOutlined: true, // Stile alternativo ma coerente
                      onPressed:
                          () => _selectServerAndProceed(
                            context,
                            "",
                          ),
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
}
