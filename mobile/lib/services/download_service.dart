// lib/download_service.dart
import 'package:flutter/material.dart';

abstract class DownloadService {
  Future<void> downloadFile(
    String url,
    String fileName,
    Function(String, Color) showSnackBar,
  );
}
