import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'pdf_actions_screen.dart';

class EditablePage {
  final int originalPageNumber;
  final String imageUrl;

  EditablePage({
    required this.originalPageNumber,
    required this.imageUrl,
  });

  factory EditablePage.fromJson(Map<String, dynamic> json) {
    return EditablePage(
      originalPageNumber: json['page_number'] as int,
      imageUrl: json['image_url'] as String,
    );
  }
}

class PdfEditorScreen extends StatefulWidget {
  final String sessionId;
  final String pdfUrl;
  final List<Map<String, dynamic>> initialPages;
  final String apiBaseUrl;

  const PdfEditorScreen({
    super.key,
    required this.sessionId,
    required this.pdfUrl,
    required this.initialPages,
    required this.apiBaseUrl,
  });

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  late List<EditablePage> _pages;
  late String _currentPdfUrl;
  late int _originalPageCount;
  bool _isDirty = false;
  bool _isLoading = false;
  String _loadingText = '';
  bool _isEdited = false;

  // Undo stack: stores (deleted page, index it was at)
  final List<({EditablePage page, int index})> _deletedPagesStack = [];

  @override
  void initState() {
    super.initState();
    _pages = widget.initialPages.map((p) => EditablePage.fromJson(p)).toList();
    _originalPageCount = _pages.length;
    _currentPdfUrl = widget.pdfUrl;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle,
              color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF34D399),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? const Color(0xFFFCA5A5) : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError 
            ? const Color.fromRGBO(220, 38, 38, 0.95)
            : const Color.fromRGBO(20, 20, 25, 0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError 
                ? const Color.fromRGBO(220, 38, 38, 0.3) 
                : Colors.white.withOpacity(0.08),
          ),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) {
      _showSnackBar(
        "Cannot delete page. At least one page is required in the PDF.",
        isError: true,
      );
      return;
    }
    final deletedPage = _pages[index];
    setState(() {
      _pages.removeAt(index);
      _deletedPagesStack.add((page: deletedPage, index: index));
      _isDirty = true;
      _isEdited = true;
    });
  }

  void _undoLastDelete() {
    if (_deletedPagesStack.isEmpty) return;
    final last = _deletedPagesStack.removeLast();
    setState(() {
      // Re-insert at the original index, clamped to current list bounds
      final insertAt = last.index.clamp(0, _pages.length);
      _pages.insert(insertAt, last.page);
      // If all deletions are undone, mark as clean
      if (_deletedPagesStack.isEmpty) {
        _isDirty = false;
        _isEdited = false;
      }
    });
  }

  Future<bool> _regeneratePdfIfNeeded() async {
    if (!_isDirty) return true;

    setState(() {
      _isLoading = true;
      _loadingText = 'Regenerating PDF...';
    });

    try {
      final List<int> remainingPages = _pages.map((p) => p.originalPageNumber).toList();
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/regenerate-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': widget.sessionId,
          'remaining_pages': remainingPages,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final Map<String, dynamic> errJson = json.decode(response.body);
        throw Exception(errJson['error'] ?? 'Server failed to regenerate PDF.');
      }

      final Map<String, dynamic> data = json.decode(response.body);
      setState(() {
        _currentPdfUrl = data['edited_pdf_url'];
        _isDirty = false;
      });
      return true;
    } catch (e) {
      _showSnackBar("PDF Regeneration failed: ${e.toString().replaceFirst('Exception: ', '')}", isError: true);
      return false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _zoomPageImage(int displayIndex, EditablePage page) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F0F12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Page $displayIndex Preview",
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.network(
                      page.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          color: Colors.black26,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.alertOctagon, color: Colors.redAccent, size: 48),
                              SizedBox(height: 8),
                              Text("Failed to load image"),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDoneEditing() async {
    final success = await _regeneratePdfIfNeeded();
    if (success && mounted) {
      final removedCount = _originalPageCount - _pages.length;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => PdfActionsScreen(
            pdfUrl: _currentPdfUrl,
            totalPages: _pages.length,
            removedPages: removedCount,
            wasEdited: _isEdited,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_isDirty) {
      final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF101015),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text('Unsaved Changes', style: TextStyle(color: Colors.white)),
          content: const Text('You have removed pages. Do you want to save these edits before leaving?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, false);
                await _handleDoneEditing();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save & Done'),
            ),
          ],
        ),
      );
      return shouldPop ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: AppBar(
          backgroundColor: const Color(0xFF050505),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          title: Text(
            'PDF Editor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: isMobile ? 18 : 22,
            ),
          ),
          centerTitle: false,
          actions: [
            if (_deletedPagesStack.isNotEmpty)
              IconButton(
                onPressed: _isLoading ? null : _undoLastDelete,
                tooltip: 'Undo last delete',
                icon: const Icon(LucideIcons.undo2, color: Color(0xFFFBBF24), size: 20),
              ),
            TextButton.icon(
              onPressed: _isLoading ? null : _handleDoneEditing,
              icon: Icon(
                LucideIcons.checkCircle,
                color: _isLoading ? Colors.white38 : const Color(0xFF34D399),
                size: 20,
              ),
              label: Text(
                'Done',
                style: TextStyle(
                  color: _isLoading ? Colors.white38 : const Color(0xFF34D399),
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            // Background Glows
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: isMobile ? 250 : 350,
                height: isMobile ? 250 : 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // Main Screen Content
            Column(
              children: [
                // Top Section (Details Card)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12.0 : 24.0,
                    vertical: isMobile ? 10.0 : 16.0,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(20, 20, 25, 0.6),
                      borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(139, 92, 246, 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            LucideIcons.fileText,
                            color: const Color(0xFF8B5CF6),
                            size: isMobile ? 20 : 28,
                          ),
                        ),
                        SizedBox(width: isMobile ? 10 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Converted Notes PDF',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total Pages: ${_pages.length}',
                                style: TextStyle(
                                  color: const Color(0xFF9CA3AF),
                                  fontSize: isMobile ? 12 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 12,
                            vertical: isMobile ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isDirty 
                                ? const Color.fromRGBO(245, 158, 11, 0.15) 
                                : const Color.fromRGBO(16, 185, 129, 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isDirty 
                                  ? const Color.fromRGBO(245, 158, 11, 0.3) 
                                  : const Color.fromRGBO(16, 185, 129, 0.3),
                            ),
                          ),
                          child: Text(
                            _isDirty ? 'Unsaved Changes' : 'Saved & Compiled',
                            style: TextStyle(
                              color: _isDirty ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                              fontSize: isMobile ? 10 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid Content Section
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 24,
                      0,
                      isMobile ? 12 : 24,
                      isMobile ? 12 : 24,
                    ),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isMobile ? 180 : 240,
                      crossAxisSpacing: isMobile ? 10 : 20,
                      mainAxisSpacing: isMobile ? 10 : 20,
                      childAspectRatio: isMobile ? 0.60 : 0.68,
                    ),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final displayIndex = index + 1;
                      final page = _pages[index];

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(15, 15, 20, 0.7),
                          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Page Header Tab
                              Padding(
                                padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
                                child: Text(
                                  'Page $displayIndex',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                              // Image Preview Area
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _zoomPageImage(displayIndex, page),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                                        child: Image.network(
                                          page.imageUrl,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(
                                              child: Icon(LucideIcons.alertTriangle, color: Colors.orangeAccent),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Delete Button Area
                              Padding(
                                padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
                                child: ElevatedButton.icon(
                                  onPressed: () => _deletePage(index),
                                  icon: Icon(LucideIcons.trash2, size: isMobile ? 11 : 14, color: Colors.white),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Delete Page',
                                      style: TextStyle(
                                        fontSize: isMobile ? 10 : 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.9),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),


              ],
            ),

            // Loading Overlay State
            if (_isLoading)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101015),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _loadingText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
