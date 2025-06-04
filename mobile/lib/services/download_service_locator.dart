// lib/download_service_locator.dart

// Export the abstract interface so types can be used
export 'download_service.dart';

// Conditionally export the `getDownloadServiceForPlatform` function from the correct file.
// This is the compile-time magic:
// - If `dart:html` is available (web build), it exports the function from `download_service_web_impl.dart`.
// - Otherwise (mobile build), it exports the function from `download_service_mobile_impl.dart`.
// The compiler will only ever see one of these `getDownloadServiceForPlatform` implementations.
export 'package:xr_tour_guide/services/download_service_mobile_impl.dart'
    if (dart.library.html) 'package:xr_tour_guide/download_service_web_impl.dart'
    show getDownloadServiceForPlatform;

// IMPORTANT: No other code in this file should reference MobileDownloadService or WebDownloadService directly.
// Only the conditional export should decide which 'getDownloadServiceForPlatform' implementation is visible.