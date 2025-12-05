import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:xr_tour_guide/services/auth_service.dart';
import '../services/api_service.dart';

class ZlibImage extends ConsumerStatefulWidget {
  final String? url;
  final String? filePath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const ZlibImage({
    Key? key,
    this.url,
    this.filePath,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
  }) : assert(url != null || filePath != null, 'Devi fornire url o filePath'),
       super(key: key);

  @override
  ConsumerState<ZlibImage> createState() => _ZlibImageState();
}

class _ZlibImageState extends ConsumerState<ZlibImage> {
  Uint8List? _imageData;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ZlibImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.filePath != widget.filePath) {
      _loadImage();
    }
  }

  // Helper per verificare se i byte sembrano un'immagine valida
  // Questo previene il crash nativo di Android ImageDecoder
  bool _isValidImageHeader(List<int> bytes) {
    if (bytes.length < 4) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47)
      return true;
    // JPG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38)
      return true;
    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    // WebP: RIFF ... WEBP
    if (bytes.length > 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50)
      return true;

    return false;
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<int> rawBytes;

      if (widget.filePath != null) {
        // Logica Offline
        final file = File(widget.filePath!);
        if (await file.exists()) {
          rawBytes = await file.readAsBytes();
        } else {
          throw Exception("File locale non trovato: ${widget.filePath}");
        }
      } else {
        // Logica Online
        final dio = ref.read(apiServiceProvider).dio;
        final response = await dio.get<List<int>>(
          widget.url!,
          options: Options(responseType: ResponseType.bytes),
        );
        rawBytes = response.data ?? [];
      }

      if (rawBytes.isNotEmpty) {
        List<int> imageBytes;

        try {
          // Tentativo 1: ZLib
          imageBytes = ZLibDecoder().decodeBytes(rawBytes);
        } catch (e) {
          try {
            // Tentativo 2: GZip (a volte confuso con ZLib)
            imageBytes = GZipDecoder().decodeBytes(rawBytes);
          } catch (e2) {
            // Fallback: assumiamo che non sia compresso
            imageBytes = rawBytes;
          }
        }

        // Validazione finale: è un'immagine?
        // Se i dati non sono validi, lanciamo un'eccezione gestita invece di far crashare l'engine grafico
        if (!_isValidImageHeader(imageBytes)) {
          if (_isValidImageHeader(rawBytes)) {
            // Magari la decompressione ha fallito ma il file originale era buono
            imageBytes = rawBytes;
          } else {
            throw Exception(
              "Dati non riconosciuti come immagine valida (Header sconosciuto)",
            );
          }
        }

        if (mounted) {
          setState(() {
            _imageData = Uint8List.fromList(imageBytes);
            _loading = false;
          });
        }
      } else {
        throw Exception("Dati immagine vuoti");
      }
    } catch (e) {
      print("Errore caricamento immagine Zlib: $e");
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _imageData == null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(
          context,
          _error ?? Exception("Load failed"),
          StackTrace.current,
        );
      }
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
    return Image.memory(
      _imageData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: widget.errorBuilder,
      gaplessPlayback: true,
    );
  }
}
