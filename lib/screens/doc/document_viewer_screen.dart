import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pdfx/pdfx.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/doc_document.dart';

class DocumentViewerScreen extends StatelessWidget {
  final DocDocument document;

  const DocumentViewerScreen({
    super.key,
    required this.document,
  });

  bool get _isImage {
    final ext = document.fileExtension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool get _isPdf {
    return document.fileExtension.toLowerCase() == 'pdf';
  }

  Future<void> _openExternally(BuildContext context) async {
    final result = await OpenFilex.open(document.filePath);
    if (result.message != 'done' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      return _ImageViewer(document: document);
    }

    if (_isPdf) {
      return _PdfViewer(document: document);
    }

    return _ExternalFileViewer(
      document: document,
      onOpen: () => _openExternally(context),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final DocDocument document;

  const _ImageViewer({required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          document.name,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PhotoView(
        imageProvider: FileImage(File(document.filePath)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 48),
              SizedBox(height: 16),
              Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfViewer extends StatefulWidget {
  final DocDocument document;

  const _PdfViewer({required this.document});

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  late final PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.document.filePath),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.document.name,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PdfViewPinch(
        controller: _pdfController,
      ),
    );
  }
}

class _ExternalFileViewer extends StatelessWidget {
  final DocDocument document;
  final VoidCallback onOpen;

  const _ExternalFileViewer({
    required this.document,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          document.name,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2029),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                document.icon,
                size: 80,
                color: const Color(0xFF4ECDC4),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              document.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${document.displaySize} • ${document.fileExtension.toUpperCase()}',
              style: const TextStyle(
                color: Color(0xFF5A5A6A),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open with External App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
