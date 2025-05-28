import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter/material.dart'; // For md.Element
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// class PdfMarkdownBuilder extends MarkdownElementBuilder {
//   PdfMarkdownBuilder() : super(textStyle: const TextStyle());

//   @override
//   bool get isBlock => true;
//   @override
//   List<String> get matchTypes => const <String>['pdf']; // Matches <pdf> tag

//   @override
//   Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
//     final String? src = element.attributes['src'];
//     final String? heightStr = element.attributes['height'];
//     final double height =
//         double.tryParse(heightStr ?? '500') ?? 500.0; // Default height

//     if (src == null || src.isEmpty) {
//       return const Text(
//         'PDF source not specified',
//         style: TextStyle(color: Colors.red),
//       );
//     }

//     return SizedBox(
//       height: height,
//       child:
//           src.startsWith('http')
//               ? SfPdfViewer.network(src)
//               : SfPdfViewer.asset(
//                 src,
//               ), // Or SfPdfViewer.file for absolute file paths
//     );
//   }
// }
