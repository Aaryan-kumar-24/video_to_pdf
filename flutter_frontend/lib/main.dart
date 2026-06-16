import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'file_helper.dart';
import 'pdf_editor_screen.dart';

String getApiBaseUrl() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      return 'http://localhost:8000';
    }
    return origin;
  }
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
  } catch (_) {}
  return 'http://localhost:8000';
}

void main() {
  runApp(const NeuralNoteGenApp());
}

class NeuralNoteGenApp extends StatelessWidget {
  const NeuralNoteGenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes bhejo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isDragging = false;
  bool _isProcessing = false;
  
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  
  String? _pdfUrl;
  String? _error;

  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result != null) {
        _validateAndSetFile(result.files.first);
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick file: $e');
    }
  }

  Future<void> _recordVideo() async {
    setState(() => _error = null);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        final bytes = await video.readAsBytes();
        final size = bytes.length;
        _validateAndSetFile(PlatformFile(
          name: video.name,
          size: size,
          bytes: bytes,
          path: kIsWeb ? null : video.path,
        ));
      }
    } catch (e) {
      setState(() => _error = 'Failed to record video: $e');
    }
  }

  void _validateAndSetFile(PlatformFile file) {
    setState(() => _error = null);
    
    // We can check extension or mime type
    final mimeType = lookupMimeType(file.name) ?? '';
    if (mimeType.startsWith('video/') || file.name.toLowerCase().endsWith('.mp4') || file.name.toLowerCase().endsWith('.webm') || file.name.toLowerCase().endsWith('.ogg')) {
      setState(() {
        _selectedFile = file;
        _fileBytes = file.bytes;
        _pdfUrl = null;
      });
    } else {
      setState(() => _error = 'Please select a valid video file.');
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _fileBytes = null;
      _pdfUrl = null;
      _error = null;
    });
  }

  Future<void> _handleConvert() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final baseUrl = getApiBaseUrl();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/convert'),
      );

      // If bytes are available (web or withData: true), use fromBytes
      if (_fileBytes != null) {
        final mimeType = lookupMimeType(_selectedFile!.name) ?? 'application/octet-stream';
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _fileBytes!,
          filename: _selectedFile!.name,
          contentType: MediaType.parse(mimeType),
        ));
      } else if (_selectedFile!.path != null) {
        // Fallback to path for desktop if bytes not loaded
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          _selectedFile!.path!,
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Conversion failed. Please try again.');
      }

      final Map<String, dynamic> data = json.decode(response.body);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfEditorScreen(
              sessionId: data['session_id'],
              pdfUrl: data['pdf_url'],
              initialPages: List<Map<String, dynamic>>.from(data['pages']),
              apiBaseUrl: baseUrl,
            ),
          ),
        ).then((result) {
          if (result != null && result is Map) {
            setState(() {
              _pdfUrl = result['pdf_url'];
            });
          } else {
            setState(() {
              _pdfUrl = data['pdf_url'];
            });
          }
        });
      }
    } catch (err) {
      setState(() {
        _error = err.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handlePreview() async {
    if (_pdfUrl != null) {
      handlePreview(_pdfUrl!, 'converted_notes.pdf');
    }
  }

  Future<void> _handleDownload() async {
    if (_pdfUrl != null) {
      final filename = getFilenameFromUrl(_pdfUrl!);
      handleDownload(_pdfUrl!, filename);
    }
  }

  Future<void> _handleShare() async {
    if (_pdfUrl != null) {
      final filename = getFilenameFromUrl(_pdfUrl!);
      handleShare(_pdfUrl!, filename);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 Bytes';
    const suffixes = ['Bytes', 'KB', 'MB', 'GB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Scaffold(
      body: Stack(
        children: [
          // Animated Orbs Background
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (50 * _orbController.value),
                    left: -100 + (50 * _orbController.value),
                    child: _buildOrb(const Color(0xFF8B5CF6), isMobile ? 250 : 400),
                  ),
                  Positioned(
                    bottom: -150 - (30 * _orbController.value),
                    right: -100 + (80 * _orbController.value),
                    child: _buildOrb(const Color(0xFF3B82F6), isMobile ? 300 : 500),
                  ),
                ],
              );
            },
          ),
          
          // Main Content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16.0 : (isTablet ? 24.0 : 32.0)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: DropTarget(
                    onDragDone: (detail) {
                      setState(() => _isDragging = false);
                      if (detail.files.isNotEmpty) {
                        // Desktop drop gives XFile, we convert to PlatformFile mock for consistency
                        final file = detail.files.first;
                        file.readAsBytes().then((bytes) {
                          _validateAndSetFile(PlatformFile(
                            name: file.name,
                            size: bytes.length,
                            path: file.path,
                            bytes: bytes,
                          ));
                        });
                      }
                    },
                    onDragEntered: (detail) => setState(() => _isDragging = true),
                    onDragExited: (detail) => setState(() => _isDragging = false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(20, 20, 25, 0.6),
                        borderRadius: BorderRadius.circular(isMobile ? 24 : 32),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black87,
                            blurRadius: 60,
                            spreadRadius: -12,
                            offset: Offset(0, 30),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isMobile ? 24 : 32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 24.0 : (isTablet ? 36.0 : 48.0)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHeader(),
                                if (_error != null) ...[
                                  SizedBox(height: isMobile ? 18 : 24),
                                  _buildError(),
                                ],
                                SizedBox(height: isMobile ? 24 : 32),
                                _buildDynamicContent(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.5),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeader() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFA5B4FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'Notes bhejo',
            style: TextStyle(
              fontSize: isMobile ? 28 : 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Extract unique frames from videos and compile them into a PDF',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 13.5 : 16.8,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(220, 38, 38, 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromRGBO(220, 38, 38, 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, color: const Color(0xFFFCA5A5), size: isMobile ? 18 : 20),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: const Color(0xFFFCA5A5), fontSize: isMobile ? 13 : 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicContent() {
    if (_pdfUrl != null) {
      return _buildSuccessState();
    } else if (_isProcessing) {
      return _buildProcessingState();
    } else if (_selectedFile != null) {
      return _buildFileInfoState();
    } else {
      return _buildUploadState();
    }
  }

  Widget _buildUploadState() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Column(
      children: [
        GestureDetector(
          onTap: _pickFile,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 36 : 56,
                horizontal: isMobile ? 20 : 32,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isDragging 
                      ? const Color(0xFF8B5CF6) 
                      : Colors.white.withOpacity(0.15),
                  width: 2,
                  style: BorderStyle.solid,
                ),
                boxShadow: _isDragging
                    ? [
                        const BoxShadow(
                          color: Color.fromRGBO(139, 92, 246, 0.3),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        )
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Container(
                    width: isMobile ? 48 : 56,
                    height: isMobile ? 48 : 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: Icon(LucideIcons.uploadCloud, color: Colors.white, size: isMobile ? 24 : 28),
                  ),
                  SizedBox(height: isMobile ? 14 : 16),
                  Text(
                    'Click to upload or drag and drop',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 15 : 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MP4, WebM, or Ogg (max 100MB)',
                    style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: isMobile ? 12 : 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                label: 'Record from Camera',
                icon: LucideIcons.camera,
                onPressed: _recordVideo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileInfoState() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(139, 92, 246, 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.fileVideo,
                  color: const Color(0xFF8B5CF6),
                  size: isMobile ? 22 : 28,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFile!.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(_selectedFile!.size),
                      style: TextStyle(
                        color: const Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w500,
                        fontSize: isMobile ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.x, color: const Color(0xFF9CA3AF), size: isMobile ? 20 : 24),
                onPressed: _clearFile,
                hoverColor: Colors.red.withOpacity(0.8),
                highlightColor: Colors.red,
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 18 : 24),
        _buildPrimaryButton(
          label: 'Convert to PDF',
          onPressed: _handleConvert,
        ),
      ],
    );
  }

  Widget _buildProcessingState() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 24 : 40),
      child: Column(
        children: [
          SizedBox(
            width: isMobile ? 60 : 80,
            height: isMobile ? 60 : 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: isMobile ? 60 : 80,
                  height: isMobile ? 60 : 80,
                  child: CircularProgressIndicator(
                    strokeWidth: isMobile ? 2.5 : 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  ),
                ),
                Container(
                  width: isMobile ? 14 : 20,
                  height: isMobile ? 14 : 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF3B82F6),
                        blurRadius: 20,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          Text(
            'Processing Video',
            style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Extracting frames and generating PDF...',
            style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: isMobile ? 12 : 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
      child: Column(
        children: [
          Icon(
            LucideIcons.checkCircle,
            color: const Color(0xFF10B981),
            size: isMobile ? 56 : 72,
            shadows: const [
              Shadow(
                color: Color.fromRGBO(16, 185, 129, 0.4),
                blurRadius: 20,
              )
            ],
          ),
          SizedBox(height: isMobile ? 18 : 24),
          Text(
            'Conversion Complete!',
            style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your document is ready for preview and download.',
            style: TextStyle(color: const Color(0xFF9CA3AF), fontSize: isMobile ? 12 : 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 24 : 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final previewBtn = _buildPrimaryButton(
                label: 'Preview PDF',
                icon: LucideIcons.eye,
                onPressed: _handlePreview,
              );
              final downloadBtn = _buildPrimaryButton(
                label: 'Download',
                icon: LucideIcons.download,
                onPressed: _handleDownload,
              );
              final shareBtn = _buildPrimaryButton(
                label: 'Share',
                icon: LucideIcons.share2,
                onPressed: _handleShare,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    previewBtn,
                    const SizedBox(height: 12),
                    downloadBtn,
                    const SizedBox(height: 12),
                    shareBtn,
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(child: previewBtn),
                    const SizedBox(width: 12),
                    Expanded(child: downloadBtn),
                    const SizedBox(width: 12),
                    Expanded(child: shareBtn),
                  ],
                );
              }
            },
          ),
          SizedBox(height: isMobile ? 12 : 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _clearFile,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 18),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Convert Another Video',
                style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onPressed, IconData? icon}) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            blurRadius: 15,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: isMobile ? 16 : 20),
                  SizedBox(width: isMobile ? 6 : 8),
                ],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 14 : 16.8,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSecondaryButton({required String label, required IconData icon, required VoidCallback onPressed}) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: isMobile ? 18 : 20),
      label: Text(
        label,
        style: TextStyle(
          fontSize: isMobile ? 14 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 18),
        side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.08),
      ),
    );
  }
}
