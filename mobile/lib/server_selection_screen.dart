import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/app_colors.dart';
import 'main.dart'; // Importiamo main per accedere a AuthFlowScreen
import 'services/api_service.dart';
import 'services/auth_service.dart';


class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {

  bool _isLoading = true;
  List<dynamic> _servers = [];
  String? _errorMessage;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ref.read(apiServiceProvider);
    _fetchServers();
  }

  Future<void> _fetchServers() async {
    try {
      final response = await _apiService.getServersList();
      print("Servers response: ${response.data}");
      if (response.statusCode == 200) {
        setState(() {
          _servers = response.data; // Supponendo che la risposta sia una lista di server
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Errore nel caricamento dei server.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore di rete: $e';
        _isLoading = false;
      });
    }
  }

  void _selectServerAndProceed(BuildContext context, String ip) {
    // 1. Imposta il server
    print("Selected server IP: $ip");
    _apiService.updateBaseUrl(ip);

    // 2. Naviga alla schermata di Auth/Onboarding
    // Usiamo pushReplacement per non permettere di tornare indietro alla selezione
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
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                              ElevatedButton(
                                onPressed: _fetchServers,
                                child: const Text('Riprova'),
                              )
                            ],
                          )
                        )
                      else 
                        ..._servers.map((server) {
                          final name = server['name'] ?? 'Unknown Server';
                          final domain = server['domain'] ?? '';
                          return _buildPrimaryButton(
                            text: name,
                            context: context,
                            isOutlined: false,
                            onPressed: () => _selectServerAndProceed(
                              context,
                              domain,
                            ),
                          );
                        }).toList(),

                    // if (_servers.isEmpty && _errorMessage == null)
                    //   Padding(
                    //     padding: const EdgeInsets.all(16.0),
                    //     child: Column(
                    //       children: const [
                    //         SizedBox(height: 16),
                    //         Text('No servers available.'),
                    //       ],
                    //     ),
                    //   ),
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
