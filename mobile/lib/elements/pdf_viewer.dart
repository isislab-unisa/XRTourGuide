// lib/pdf_viewer_widget.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/app_colors.dart';

// ONLY IMPORT THIS FILE FOR THE DOWNLOAD SERVICE!
// This single import brings in both the 'DownloadService' interface
// and the 'getDownloadServiceForPlatform()' function.
import '../services/download_service_locator.dart';
// Note: We don't need 'download_service.dart' specifically here anymore
// because 'download_service_locator.dart' already exports it.

class PdfViewerWidget extends StatefulWidget {
  final String pdfUrl;
  final bool isLocalFile;

  const PdfViewerWidget({Key? key, required this.pdfUrl, this.isLocalFile = false}) : super(key: key);

  @override
  _PdfViewerWidgetState createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  bool _isDownloading = false;
  String? _downloadMessage;
  late DownloadService _downloadService; // Declare using the interface type

  @override
  void initState() {
    super.initState();
    // Get the platform-specific service instance using the locator function.
    // The compiler now correctly resolves getDownloadServiceForPlatform()
    // based on the conditional export in download_service_locator.dart.
    _downloadService = getDownloadServiceForPlatform();
  }

  Future<void> _initiateDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadMessage = null;
    });

    final fileName =
        widget.pdfUrl.split('/').last.split('?').first; // Extract filename

    // Call the platform-specific download method via the interface
    await _downloadService.downloadFile(widget.pdfUrl, fileName, _showSnackBar);

    setState(() {
      _isDownloading = false;
    });
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Document Viewer',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (_isDownloading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.download),
                  color: AppColors.textPrimary,
                  onPressed: _initiateDownload,
                  tooltip: 'Download PDF',
                ),
            ],
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: widget.isLocalFile 
              ? SfPdfViewer.file(
                  File(widget.pdfUrl),
                  canShowHyperlinkDialog: false,
                  canShowScrollHead: false,
                )
              : SfPdfViewer.network(
                  widget.pdfUrl,
                  canShowHyperlinkDialog: false,
                  canShowScrollHead: false,
                ),
          ),
        ),
        if (_downloadMessage != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _downloadMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
          ),
      ],
    );
  }
}
