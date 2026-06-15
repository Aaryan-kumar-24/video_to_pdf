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
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'file_helper.dart';

void main() {
  runApp(const NeuralNoteGenApp());
}

class NeuralNoteGenApp extends StatelessWidget {
  const NeuralNoteGenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes Generator',
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
  
  Uint8List? _pdfBytes;
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

  void _validateAndSetFile(PlatformFile file) {
    setState(() => _error = null);
    
    // We can check extension or mime type
    final mimeType = lookupMimeType(file.name) ?? '';
    if (mimeType.startsWith('video/') || file.name.toLowerCase().endsWith('.mp4') || file.name.toLowerCase().endsWith('.webm') || file.name.toLowerCase().endsWith('.ogg')) {
      setState(() {
        _selectedFile = file;
        _fileBytes = file.bytes;
        _pdfBytes = null;
      });
    } else {
      setState(() => _error = 'Please select a valid video file.');
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _fileBytes = null;
      _pdfBytes = null;
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
var request = http.MultipartRequest(
  'POST',
  Uri.parse('https://pdf-generator-32u0.onrender.com/api/convert'),
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

      setState(() {
        _pdfBytes = response.bodyBytes;
      });
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
    if (_pdfBytes != null) {
      handlePreview(_pdfBytes!, 'converted_notes.pdf');
    }
  }

  Future<void> _handleDownload() async {
    if (_pdfBytes != null) {
       handleDownload(_pdfBytes!, 'converted_notes.pdf');
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
                    child: _buildOrb(const Color(0xFF8B5CF6), 400),
                  ),
                  Positioned(
                    bottom: -150 - (30 * _orbController.value),
                    right: -100 + (80 * _orbController.value),
                    child: _buildOrb(const Color(0xFF3B82F6), 500),
                  ),
                ],
              );
            },
          ),
          
          // Main Content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
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
                        borderRadius: BorderRadius.circular(32),
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
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Padding(
                            padding: const EdgeInsets.all(48.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHeader(),
                                if (_error != null) ...[
                                  const SizedBox(height: 24),
                                  _buildError(),
                                ],
                                const SizedBox(height: 32),
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
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFA5B4FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Notes Generator',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Extract unique frames from videos and compile them into a PDF',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16.8,
            fontWeight: FontWeight.w300,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(220, 38, 38, 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color.fromRGBO(220, 38, 38, 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: Color(0xFFFCA5A5), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicContent() {
    if (_pdfBytes != null) {
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
    return GestureDetector(
      onTap: _pickFile,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 32),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(LucideIcons.uploadCloud, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Click to upload or drag and drop',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'MP4, WebM, or Ogg (max 100MB)',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfoState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(139, 92, 246, 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.fileVideo, color: Color(0xFF8B5CF6), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFile!.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(_selectedFile!.size),
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, color: Color(0xFF9CA3AF)),
                onPressed: _clearFile,
                hoverColor: Colors.red.withOpacity(0.8),
                highlightColor: Colors.red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Convert to PDF',
          onPressed: _handleConvert,
        ),
      ],
    );
  }

  Widget _buildProcessingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
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
          const SizedBox(height: 32),
          const Text(
            'Processing Video',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Extracting frames and generating PDF...',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(
            LucideIcons.checkCircle,
            color: Color(0xFF10B981),
            size: 72,
            shadows: [
              Shadow(
                color: Color.fromRGBO(16, 185, 129, 0.4),
                blurRadius: 20,
              )
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Conversion Complete!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your document is ready for preview and download.',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildPrimaryButton(
                  label: 'Preview PDF',
                  icon: LucideIcons.eye,
                  onPressed: _handlePreview,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPrimaryButton(
                  label: 'Download',
                  icon: LucideIcons.download,
                  onPressed: _handleDownload,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _clearFile,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Convert Another Video',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onPressed, IconData? icon}) {
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
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.8,
                    fontWeight: FontWeight.w600,
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
