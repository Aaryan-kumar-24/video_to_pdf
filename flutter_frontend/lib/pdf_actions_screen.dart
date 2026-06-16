import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'file_helper.dart';

class PdfActionsScreen extends StatefulWidget {
  final String pdfUrl;
  final int totalPages;
  final int removedPages;
  final bool wasEdited;

  const PdfActionsScreen({
    super.key,
    required this.pdfUrl,
    required this.totalPages,
    required this.removedPages,
    required this.wasEdited,
  });

  @override
  State<PdfActionsScreen> createState() => _PdfActionsScreenState();
}

class _PdfActionsScreenState extends State<PdfActionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _orbController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _linkCopied = false;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scaleAnimation =
        CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _handlePreview() {
    handlePreview(widget.pdfUrl, 'converted_notes.pdf');
  }

  void _handleDownload() {
    handleDownload(widget.pdfUrl, 'converted_notes.pdf');
  }

  void _showShareSheet() {
    if (kIsWeb) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _ShareBottomSheet(pdfUrl: widget.pdfUrl),
      );
    } else {
      handleShare(widget.pdfUrl, 'converted_notes.pdf');
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: Stack(
          children: [
            // Animated Background Orbs
            AnimatedBuilder(
              animation: _orbController,
              builder: (_, __) => Stack(
                children: [
                  Positioned(
                    top: -80 + (60 * _orbController.value),
                    left: -80 + (40 * _orbController.value),
                    child: _orb(const Color(0xFF8B5CF6), isMobile ? 240 : 380),
                  ),
                  Positioned(
                    bottom: -120 - (40 * _orbController.value),
                    right: -80 + (60 * _orbController.value),
                    child: _orb(const Color(0xFF3B82F6), isMobile ? 300 : 450),
                  ),
                  Positioned(
                    top: size.height * 0.45,
                    left: -60 + (30 * _orbController.value),
                    child: _orb(const Color(0xFF10B981), isMobile ? 140 : 200),
                  ),
                ],
              ),
            ),

            // Main Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 40,
                    vertical: isMobile ? 24 : 32,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Success Badge
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: _successBadge(),
                          ),
                          SizedBox(height: isMobile ? 20 : 28),

                          // Title
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [Colors.white, Color(0xFFA5B4FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              'PDF Ready!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isMobile ? 28 : 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.wasEdited
                                ? 'Your edited PDF is compiled and ready to use.'
                                : 'Your PDF has been compiled and is ready to use.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 16,
                              fontWeight: FontWeight.w300,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),

                          SizedBox(height: isMobile ? 20 : 28),

                          // Stats Card
                          _glassCard(
                            child: Row(
                              children: [
                                _stat(
                                  icon: LucideIcons.fileText,
                                  label: 'Total Pages',
                                  value: '${widget.totalPages}',
                                  color: const Color(0xFF8B5CF6),
                                ),
                                _statDivider(),
                                _stat(
                                  icon: LucideIcons.checkCircle,
                                  label: 'Status',
                                  value: widget.wasEdited ? 'Edited' : 'Original',
                                  color: const Color(0xFF10B981),
                                ),
                                if (widget.wasEdited) ...[
                                  _statDivider(),
                                  _stat(
                                    icon: LucideIcons.trash2,
                                    label: 'Removed',
                                    value: '${widget.removedPages} pages',
                                    color: const Color(0xFFEF4444),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: isMobile ? 18 : 24),

                          // Actions Card
                          _glassCard(
                            padding: EdgeInsets.all(isMobile ? 16 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACTIONS',
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF6B7280),
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                SizedBox(height: isMobile ? 12 : 16),
                                isMobile
                                    ? Column(
                                        children: [
                                          _actionTile(
                                            icon: LucideIcons.eye,
                                            title: 'Preview PDF',
                                            subtitle: 'Open in your browser',
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                            ),
                                            onTap: _handlePreview,
                                          ),
                                          const SizedBox(height: 12),
                                          _actionTile(
                                            icon: LucideIcons.download,
                                            title: 'Download PDF',
                                            subtitle: 'Save to your device',
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                            ),
                                            onTap: _handleDownload,
                                          ),
                                          const SizedBox(height: 12),
                                          _actionTile(
                                            icon: LucideIcons.share2,
                                            title: 'Share PDF',
                                            subtitle: 'WhatsApp, Telegram & more',
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                                            ),
                                            onTap: _showShareSheet,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: _actionTile(
                                              icon: LucideIcons.eye,
                                              title: 'Preview',
                                              subtitle: 'Open in browser',
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                              ),
                                              onTap: _handlePreview,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _actionTile(
                                              icon: LucideIcons.download,
                                              title: 'Download',
                                              subtitle: 'Save to device',
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                              ),
                                              onTap: _handleDownload,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _actionTile(
                                              icon: LucideIcons.share2,
                                              title: 'Share',
                                              subtitle: 'More options',
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
                                              ),
                                              onTap: _showShareSheet,
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),

                          SizedBox(height: isMobile ? 16 : 20),

                          // Convert Another Button
                          SizedBox(
                            width: double.infinity,
                            child: _outlinedBtn(
                              label: 'Convert Another Video',
                              icon: LucideIcons.refreshCw,
                              onTap: _goHome,
                            ),
                          ),
                        ],
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

  // ─── Widget Helpers ──────────────────────────────────────────────────────────

  Widget _orb(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.45),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
          child: Container(color: Colors.transparent),
        ),
      );

  Widget _successBadge() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final double size = isMobile ? 80 : 100;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.45),
            blurRadius: isMobile ? 30 : 40,
            spreadRadius: isMobile ? 3 : 4,
          ),
        ],
      ),
      child: Icon(LucideIcons.checkCircle, color: Colors.white, size: isMobile ? 38 : 48),
    );
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    return ClipRRect(
      borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding ?? EdgeInsets.all(isMobile ? 12 : 20),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(20, 20, 28, 0.65),
            borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isMobile ? 16 : 20),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 13 : 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 9 : 11,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    return Container(
      width: 1,
      height: isMobile ? 40 : 60,
      color: Colors.white.withOpacity(0.07),
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isMobile
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, color: Colors.white70, size: 16),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _outlinedBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF9CA3AF), size: isMobile ? 16 : 18),
              SizedBox(width: isMobile ? 8 : 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ShareBottomSheet extends StatefulWidget {
  final String pdfUrl;
  const _ShareBottomSheet({required this.pdfUrl});

  @override
  State<_ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<_ShareBottomSheet> {
  bool _copied = false;

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.pdfUrl));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  String get _encodedUrl => Uri.encodeComponent(widget.pdfUrl);
  String get _shareText => Uri.encodeComponent('Check out this PDF I created from a video!');

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(12, 12, 18, 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            16,
            isMobile ? 16 : 24,
            isMobile ? 24 : 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: isMobile ? 12 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(6, 182, 212, 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.share2,
                      color: const Color(0xFF06B6D4),
                      size: isMobile ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share PDF',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Choose where to share',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: isMobile ? 18 : 24),

              // Share options grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                crossAxisSpacing: isMobile ? 8 : 12,
                mainAxisSpacing: isMobile ? 12 : 16,
                childAspectRatio: isMobile ? 0.82 : 0.85,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _shareOption(
                    label: 'WhatsApp',
                    icon: LucideIcons.messageCircle,
                    color: const Color(0xFF25D366),
                    onTap: () => _openUrl(
                        'https://wa.me/?text=$_shareText%20$_encodedUrl'),
                  ),
                  _shareOption(
                    label: 'Telegram',
                    icon: LucideIcons.send,
                    color: const Color(0xFF2AABEE),
                    onTap: () => _openUrl(
                        'https://t.me/share/url?url=$_encodedUrl&text=$_shareText'),
                  ),
                  _shareOption(
                    label: 'Email',
                    icon: LucideIcons.mail,
                    color: const Color(0xFFEA4335),
                    onTap: () => _openUrl(
                        'mailto:?subject=PDF%20Document&body=$_shareText%20$_encodedUrl'),
                  ),
                  _shareOption(
                    label: 'Twitter / X',
                    icon: LucideIcons.twitter,
                    color: const Color(0xFF1DA1F2),
                    onTap: () => _openUrl(
                        'https://twitter.com/intent/tweet?text=$_shareText&url=$_encodedUrl'),
                  ),
                  _shareOption(
                    label: 'LinkedIn',
                    icon: LucideIcons.linkedin,
                    color: const Color(0xFF0A66C2),
                    onTap: () => _openUrl(
                        'https://www.linkedin.com/sharing/share-offsite/?url=$_encodedUrl'),
                  ),
                  _shareOption(
                    label: 'Reddit',
                    icon: LucideIcons.messageSquare,
                    color: const Color(0xFFFF4500),
                    onTap: () => _openUrl(
                        'https://www.reddit.com/submit?url=$_encodedUrl&title=$_shareText'),
                  ),
                  _shareOption(
                    label: 'Facebook',
                    icon: LucideIcons.facebook,
                    color: const Color(0xFF1877F2),
                    onTap: () => _openUrl(
                        'https://www.facebook.com/sharer/sharer.php?u=$_encodedUrl'),
                  ),
                  _shareOption(
                    label: _copied ? 'Copied!' : 'Copy Link',
                    icon: _copied ? LucideIcons.checkCircle : LucideIcons.link,
                    color: _copied
                        ? const Color(0xFF10B981)
                        : const Color(0xFF8B5CF6),
                    onTap: _copyLink,
                  ),
                ],
              ),

              SizedBox(height: isMobile ? 16 : 20),

              // URL preview box
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.link2,
                      color: const Color(0xFF6B7280),
                      size: isMobile ? 14 : 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.pdfUrl,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: const Color(0xFF9CA3AF),
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _copyLink,
                      child: Text(
                        _copied ? 'Copied!' : 'Copy',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: _copied
                              ? const Color(0xFF10B981)
                              : const Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isMobile ? 48 : 56,
              height: isMobile ? 48 : 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: isMobile ? 20 : 24),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  color: const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
