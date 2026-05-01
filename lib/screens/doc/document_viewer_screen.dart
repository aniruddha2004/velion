import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pdfx/pdfx.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/doc_document.dart';

/// Document viewer screen that handles images, PDFs, and other file types
/// Uses a defensive approach to ensure the viewer stays open until user dismisses it
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
    // Check if file exists
    final file = File(document.filePath);
    final fileExists = file.existsSync();

    if (!fileExists) {
      return _buildFileNotFound(context);
    }

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

  Widget _buildFileNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(document.name, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 64),
            const SizedBox(height: 16),
            const Text(
              'File not found',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'The file may have been moved or deleted',
              style: TextStyle(color: const Color(0xFF5A5A6A), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image viewer with PhotoView - wrapped in StatefulWidget for better control
class _ImageViewer extends StatefulWidget {
  final DocDocument document;

  const _ImageViewer({required this.document});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer>
    with SingleTickerProviderStateMixin {
  bool _hasError = false;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Handle any cleanup if needed
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.5),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.document.name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        body: _hasError ? _buildErrorWidget() : _buildPhotoView(),
      ),
    );
  }

  Widget _buildPhotoView() {
    return PhotoView(
      imageProvider: FileImage(File(widget.document.filePath)),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      enableRotation: false,
      gaplessPlayback: true,
      loadingBuilder: (context, event) {
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('PhotoView error: $error');
        _safeSetState(() => _hasError = true);
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load image',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.document.filePath,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// PDF viewer with pdfx - properly manages controller lifecycle
class _PdfViewer extends StatefulWidget {
  final DocDocument document;

  const _PdfViewer({required this.document});

  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  void _initializePdf() {
    try {
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openFile(widget.document.filePath),
      );
    } catch (e) {
      debugPrint('PDF initialization error: $e');
      _safeSetState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pdfController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Cleanup handled in dispose
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16181F),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.document.name,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            if (_pdfController != null)
              PdfViewPinch(
                controller: _pdfController!,
                onDocumentLoaded: (document) {
                  debugPrint('PDF loaded: ${document.pagesCount} pages');
                  _safeSetState(() => _isLoading = false);
                },
                onDocumentError: (error) {
                  debugPrint('PDF error: $error');
                  _safeSetState(() {
                    _errorMessage = error.toString();
                    _isLoading = false;
                  });
                },
              ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.document.name, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load PDF',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFF5A5A6A), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// External file viewer for non-supported file types
class _ExternalFileViewer extends StatelessWidget {
  final DocDocument document;
  final VoidCallback onOpen;

  const _ExternalFileViewer({
    required this.document,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {},
      child: Scaffold(
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
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
