import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════
// PARTICLE PAINTER
// ═══════════════════════════════════════════════════════════════
class _DocParticlePainter extends CustomPainter {
  final double progress;
  final List<_ParticleData> particles;
  _DocParticlePainter(this.progress, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = (p.x + p.vx * progress * 12) % 1.0;
      final y = (p.y + p.vy * progress * 12) % 1.0;
      final opacity = (0.08 + p.opacity * 0.18) *
          (0.7 + 0.3 * sin(progress * 2 * pi + p.phase));
      final paint = Paint()
        ..color = const Color(0xFF2E75B6).withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DocParticlePainter old) => old.progress != progress;
}

class _ParticleData {
  final double x, y, vx, vy, radius, opacity, phase;
  const _ParticleData(
      this.x, this.y, this.vx, this.vy, this.radius, this.opacity, this.phase);
}

// ═══════════════════════════════════════════════════════════════
// DOCUMENT SCREEN
// ═══════════════════════════════════════════════════════════════
class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});
  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen>
    with TickerProviderStateMixin {
  List<Document> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _selectedCategoryFilter;

  late AnimationController _particleController;
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  late List<_ParticleData> _particles;

  static final _rng = Random();

  final List<String> _categories = [
    'All',
    'IDs',
    'Certificates',
    'Contracts',
    'Finance',
    'Other'
  ];
  final List<String> _uploadCategories = [
    'IDs',
    'Certificates',
    'Contracts',
    'Finance',
    'Other'
  ];

  @override
  void initState() {
    super.initState();

    // Generate particles
    _particles = List.generate(
      12,
      (_) => _ParticleData(
        _rng.nextDouble(),
        _rng.nextDouble(),
        (_rng.nextDouble() - 0.5) * 0.004,
        (_rng.nextDouble() - 0.5) * 0.004,
        1.2 + _rng.nextDouble() * 2.5,
        _rng.nextDouble(),
        _rng.nextDouble() * 2 * pi,
      ),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();
    _loadDocuments();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final docs = await apiService.getDocuments();
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to load documents: $e', isError: true);
      }
    }
  }

  List<Document> get _filteredDocuments {
    if (_selectedCategoryFilter == null || _selectedCategoryFilter == 'All') {
      return _documents;
    }
    return _documents
        .where((doc) => doc.category == _selectedCategoryFilter)
        .toList();
  }

  // ── Upload ──────────────────────────────────────────────────
  Future<void> _uploadDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;
    final fileSize = result.files.single.size;

    if (fileSize > 500 * 1024 * 1024) {
      _showSnackBar('File too large. Maximum size is 500 MB.', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final sensitivity = await apiService.analyzeFileSensitivity(fileName);
      if (sensitivity.requiresConfirmation) {
        setState(() => _isUploading = false);
        final confirmed = await _showHighSensitivityDialog(
          fileName: fileName,
          reason: sensitivity.reason,
        );
        if (!confirmed) return;
        setState(() => _isUploading = true);
      }

      setState(() => _isUploading = false);
      final category = await _showCategoryDialog();
      if (category == null) return;
      setState(() => _isUploading = true);

      final uploadResult = await apiService.uploadDocument(
        filePath: file.path,
        category: category,
      );

      // Delete original file after upload
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      setState(() => _isUploading = false);
      _showSnackBar(
          '${uploadResult.message} (Original file deleted from your PC)');
      setState(() => _selectedCategoryFilter = null);
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadDocuments();
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      _showSnackBar('Upload failed: $e', isError: true);
    }
  }

  // ── Preview ──────────────────────────────────────────────────
  Future<void> _previewDocument(Document doc) async {
    // FIX: treat 'image' fileType properly, also support jpeg/png/gif/webp
    final isImage = doc.fileType == 'image' ||
        doc.fileType == 'jpg' ||
        doc.fileType == 'jpeg' ||
        doc.fileType == 'png' ||
        doc.fileType == 'gif' ||
        doc.fileType == 'webp';
    final isPdf = doc.fileType == 'pdf';

    if (isImage && doc.fileSize < 50 * 1024 * 1024) {
      await _showImagePreview(doc);
    } else if (isPdf && doc.fileSize < 100 * 1024 * 1024) {
      await _showPdfPreview(doc);
    } else {
      _showSnackBar(
        'Preview not available for this file type or size. Use Download instead.',
      );
    }
  }

  Future<void> _showImagePreview(Document doc) async {
    // Show loading first
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildLoadingDialog('Loading image preview...'),
    );

    try {
      final imageBytes = await apiService.previewDocument(doc.id);
      if (!mounted) return;
      Navigator.pop(context); // close loader

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF2E75B6).withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E75B6).withOpacity(0.25),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Failed to load image',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _IconHoverButton(
                  icon: Icons.close,
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Failed to preview image: $e', isError: true);
    }
  }

  Future<void> _showPdfPreview(Document doc) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildLoadingDialog('Opening PDF...'),
    );

    try {
      final pdfBytes = await apiService.previewDocument(doc.id);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/preview_${doc.id}.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      if (!mounted) return;
      Navigator.pop(context); // close loader

      await OpenFile.open(tempFile.path);

      // Cleanup after 30s
      Future.delayed(const Duration(seconds: 30), () {
        try {
          if (tempFile.existsSync()) tempFile.deleteSync();
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Failed to preview PDF: $e', isError: true);
    }
  }

  // ── Download ─────────────────────────────────────────────────
  Future<void> _downloadDocument(Document doc) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildLoadingDialog('Decrypting ${doc.fileName}...'),
    );

    try {
      final decryptedBytes = await apiService.previewDocument(doc.id);
      if (!mounted) return;
      Navigator.pop(context);

      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Document',
        fileName: doc.fileName,
      );
      if (savePath == null) return;

      final file = File(savePath);
      await file.writeAsBytes(decryptedBytes);
      _showSnackBar('File saved to: $savePath');

      if (!mounted) return;
      final shouldOpen = await _showDownloadCompleteDialog(savePath);
      if (shouldOpen == true) {
        await OpenFile.open(savePath);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showSnackBar('Download failed: $e', isError: true);
    }
  }

  // ── Delete ───────────────────────────────────────────────────
  Future<void> _deleteDocument(Document doc) async {
    final confirmed = await _showDeleteDialog(doc);
    if (confirmed == true) {
      try {
        await apiService.deleteDocument(doc.id);
        _showSnackBar('Document deleted from vault');
        await _loadDocuments();
      } catch (e) {
        _showSnackBar('Failed to delete: $e', isError: true);
      }
    }
  }

  // ── Dialogs ──────────────────────────────────────────────────
  Widget _buildLoadingDialog(String message) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E75B6).withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF2E75B6),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showHighSensitivityDialog({
    required String fileName,
    required String reason,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E2340),
                    Color(0xFF112B4E),
                    Color(0xFF0C1E36)
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFEF4444).withOpacity(0.25),
                                const Color(0xFFEF4444).withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFEF4444), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'High Sensitivity File',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Proceed with caution',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // File name
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file,
                              size: 14, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Reason
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.25)),
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to upload this file to the vault?',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: _DialogButton(
                            label: 'Cancel',
                            isOutlined: true,
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DialogButton(
                            label: 'Upload Anyway',
                            isError: true,
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<String?> _showCategoryDialog() async {
    String? selectedCategory = _uploadCategories.first;
    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E2340),
                  Color(0xFF112B4E),
                  Color(0xFF0C1E36)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6).withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2E75B6).withOpacity(0.25),
                              const Color(0xFF2E75B6).withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2E75B6).withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.folder_special,
                            color: Color(0xFF2E75B6), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Radio list
                  ..._uploadCategories.map((category) {
                    final isSelected = selectedCategory == category;
                    return GestureDetector(
                      onTap: () => setLocalState(() {
                        selectedCategory = category;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2E75B6).withOpacity(0.15)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2E75B6).withOpacity(0.5)
                                : Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2E75B6)
                                      : Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF2E75B6),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              category,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.6),
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogButton(
                          label: 'Cancel',
                          isOutlined: true,
                          onPressed: () => Navigator.pop(context, null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DialogButton(
                          label: 'Confirm',
                          onPressed: () =>
                              Navigator.pop(context, selectedCategory),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(Document doc) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFFEF4444).withOpacity(0.25),
                      const Color(0xFFEF4444).withOpacity(0.08),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.25),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.delete_forever,
                      color: Color(0xFFEF4444), size: 24),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Document',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                // File name chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(doc.getFileIcon(),
                          size: 13,
                          color: const Color(0xFFEF4444).withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          doc.fileName,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This will permanently delete the file from the vault. This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        isOutlined: true,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: 'Delete',
                        isError: true,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDownloadCompleteDialog(String savePath) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF22C55E).withOpacity(0.25),
                      const Color(0xFF22C55E).withOpacity(0.08),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF22C55E).withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: Color(0xFF22C55E), size: 24),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Download Complete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Text(
                    savePath,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Close',
                        isOutlined: true,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        label: 'Open File',
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getSensitivityColor(String sensitivity) {
    switch (sensitivity) {
      case 'High':
        return const Color(0xFFEF4444);
      case 'Medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF22C55E);
    }
  }

  String _getSensitivityLabel(String sensitivity) {
    switch (sensitivity) {
      case 'High':
        return 'High';
      case 'Medium':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  IconData _getSensitivityIcon(String sensitivity) {
    switch (sensitivity) {
      case 'High':
        return Icons.warning_amber;
      case 'Medium':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D18),
      body: Stack(
        children: [
          // Particle background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: _DocParticlePainter(
                  _particleController.value,
                  _particles,
                ),
              ),
            ),
          ),

          // Main content
          FadeTransition(
            opacity: _entranceFade,
            child: SlideTransition(
              position: _entranceSlide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar ──────────────────────────────────
                  _buildTopBar(),

                  // ── Category filter ──────────────────────────
                  _buildCategoryFilter(),

                  // ── Document list ────────────────────────────
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _PremiumFAB(
        isUploading: _isUploading,
        onPressed: _isUploading ? null : _uploadDocument,
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Row(
        children: [
          // Breadcrumb pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2E75B6).withOpacity(0.15),
                  const Color(0xFF2E75B6).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border:
                  Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF2E75B6), Color(0xFF58A6FF)],
                  ).createShader(bounds),
                  child: const Icon(Icons.folder_copy,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
                  ).createShader(bounds),
                  child: const Text(
                    'DOCUMENTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Count badge
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2E75B6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF2E75B6).withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 12, color: Color(0xFF58A6FF)),
                  const SizedBox(width: 5),
                  Text(
                    '${_documents.length} stored',
                    style: const TextStyle(
                      color: Color(0xFF58A6FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategoryFilter == category ||
                (_selectedCategoryFilter == null && category == 'All');
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: category,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedCategoryFilter = (isSelected && category != 'All')
                        ? null
                        : (category == 'All' ? null : category);
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2E75B6),
          strokeWidth: 2.5,
        ),
      );
    }

    if (_filteredDocuments.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: _filteredDocuments.length,
      itemBuilder: (context, index) {
        final doc = _filteredDocuments[index];
        return _DocumentCard(
          document: doc,
          onTap: () => _previewDocument(doc),
          onDownload: () => _downloadDocument(doc),
          onDelete: () => _deleteDocument(doc),
          getSensitivityColor: _getSensitivityColor,
          getSensitivityLabel: _getSensitivityLabel,
          getSensitivityIcon: _getSensitivityIcon,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glow circle
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF1A4D7A), Color(0xFF0E2340)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6).withOpacity(0.35),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
              border:
                  Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
            ),
            child: const Icon(Icons.folder_open,
                size: 42, color: Color(0xFF58A6FF)),
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
            ).createShader(bounds),
            child: const Text(
              'No Documents Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload encrypted files to your vault',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '⚠  Original files are deleted from your PC after upload',
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFFEF4444).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 28),
          _PremiumGradientButton(
            label: 'Upload First Document',
            icon: Icons.upload,
            onPressed: _uploadDocument,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY CHIP
// ═══════════════════════════════════════════════════════════════
class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.isSelected, required this.onTap});
  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)])
                : null,
            color: widget.isSelected
                ? null
                : _hovering
                    ? Colors.white.withOpacity(0.07)
                    : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF2E75B6)
                  : _hovering
                      ? const Color(0xFF2E75B6).withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E75B6).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DOCUMENT CARD
// ═══════════════════════════════════════════════════════════════
class _DocumentCard extends StatefulWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final Color Function(String) getSensitivityColor;
  final String Function(String) getSensitivityLabel;
  final IconData Function(String) getSensitivityIcon;

  const _DocumentCard({
    required this.document,
    required this.onTap,
    required this.onDownload,
    required this.onDelete,
    required this.getSensitivityColor,
    required this.getSensitivityLabel,
    required this.getSensitivityIcon,
  });

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 1.018)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final sensitivityColor = widget.getSensitivityColor(doc.sensitivityScore);
    final canPreview = doc.fileType == 'image' ||
        doc.fileType == 'jpg' ||
        doc.fileType == 'jpeg' ||
        doc.fileType == 'png' ||
        doc.fileType == 'gif' ||
        doc.fileType == 'webp' ||
        doc.fileType == 'pdf';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovering = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Transform.scale(
          scale: _scale.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _hovering ? const Color(0xFF112B4E) : const Color(0xFF0E2340),
                  const Color(0xFF112B4E),
                  const Color(0xFF0C1E36),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovering
                    ? const Color(0xFF2E75B6).withOpacity(0.5)
                    : const Color(0xFF1E4A7A).withOpacity(0.35),
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2E75B6)
                            .withOpacity(0.28 * _glow.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ── File icon badge ──────────────────────────
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2E75B6).withOpacity(0.28),
                          const Color(0xFF2E75B6).withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2E75B6).withOpacity(0.3),
                      ),
                      boxShadow: _hovering
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2E75B6).withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      doc.getFileIcon(),
                      size: 26,
                      color: const Color(0xFF58A6FF),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── File info ────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(doc.uploadedAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // File size
                            _Badge(
                              label: doc.getFormattedFileSize(),
                              color: Colors.white.withOpacity(0.5),
                              bgColor: Colors.white.withOpacity(0.06),
                            ),
                            // Category
                            _Badge(
                              label: doc.category,
                              color: const Color(0xFF58A6FF),
                              bgColor:
                                  const Color(0xFF2E75B6).withOpacity(0.12),
                              borderColor:
                                  const Color(0xFF2E75B6).withOpacity(0.3),
                            ),
                            // Sensitivity
                            _Badge(
                              label: widget
                                  .getSensitivityLabel(doc.sensitivityScore),
                              color: sensitivityColor,
                              bgColor: sensitivityColor.withOpacity(0.12),
                              borderColor: sensitivityColor.withOpacity(0.3),
                              icon: widget
                                  .getSensitivityIcon(doc.sensitivityScore),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Action buttons ───────────────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canPreview)
                        _IconHoverButton(
                          icon: Icons.remove_red_eye_outlined,
                          color: const Color(0xFF58A6FF),
                          tooltip: 'Preview',
                          onPressed: widget.onTap,
                        ),
                      _IconHoverButton(
                        icon: Icons.download_outlined,
                        color: const Color(0xFF58A6FF),
                        tooltip: 'Download',
                        onPressed: widget.onDownload,
                      ),
                      _IconHoverButton(
                        icon: Icons.delete_outline,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete',
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ═══════════════════════════════════════════════════════════════
// BADGE
// ═══════════════════════════════════════════════════════════════
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final Color? borderColor;
  final IconData? icon;
  const _Badge({
    required this.label,
    required this.color,
    required this.bgColor,
    this.borderColor,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ICON HOVER BUTTON
// ═══════════════════════════════════════════════════════════════
class _IconHoverButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;
  const _IconHoverButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });
  @override
  State<_IconHoverButton> createState() => _IconHoverButtonState();
}

class _IconHoverButtonState extends State<_IconHoverButton> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color:
                _hovering ? widget.color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedScale(
            scale: _hovering ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 130),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
    return widget.tooltip != null
        ? Tooltip(message: widget.tooltip!, child: btn)
        : btn;
  }
}

// ═══════════════════════════════════════════════════════════════
// DIALOG BUTTON
// ═══════════════════════════════════════════════════════════════
class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isError;
  final bool isOutlined;
  const _DialogButton({
    required this.label,
    required this.onPressed,
    this.isError = false,
    this.isOutlined = false,
  });
  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.isError ? const Color(0xFFEF4444) : const Color(0xFF2E75B6);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _hovering ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 40,
            decoration: BoxDecoration(
              gradient: widget.isOutlined
                  ? null
                  : LinearGradient(
                      colors: widget.isError
                          ? [
                              _hovering
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFEF4444),
                              const Color(0xFFDC2626),
                            ]
                          : [
                              _hovering
                                  ? const Color(0xFF3A88CC)
                                  : const Color(0xFF2E75B6),
                              const Color(0xFF1A4D7A),
                            ],
                    ),
              color: widget.isOutlined
                  ? _hovering
                      ? Colors.white.withOpacity(0.06)
                      : Colors.transparent
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: widget.isOutlined
                  ? Border.all(color: Colors.white.withOpacity(0.2))
                  : null,
              boxShadow: !widget.isOutlined && _hovering
                  ? [
                      BoxShadow(
                        color: baseColor.withOpacity(0.4),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.isOutlined
                      ? Colors.white.withOpacity(0.7)
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM GRADIENT BUTTON (empty state CTA)
// ═══════════════════════════════════════════════════════════════
class _PremiumGradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PremiumGradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  @override
  State<_PremiumGradientButton> createState() => _PremiumGradientButtonState();
}

class _PremiumGradientButtonState extends State<_PremiumGradientButton> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _hovering ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hovering
                    ? [const Color(0xFF3A88CC), const Color(0xFF2E75B6)]
                    : [const Color(0xFF2E75B6), const Color(0xFF1A4D7A)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6)
                      .withOpacity(_hovering ? 0.5 : 0.25),
                  blurRadius: _hovering ? 20 : 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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

// ═══════════════════════════════════════════════════════════════
// PREMIUM FAB
// ═══════════════════════════════════════════════════════════════
class _PremiumFAB extends StatefulWidget {
  final bool isUploading;
  final VoidCallback? onPressed;
  const _PremiumFAB({required this.isUploading, required this.onPressed});
  @override
  State<_PremiumFAB> createState() => _PremiumFABState();
}

class _PremiumFABState extends State<_PremiumFAB> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _hovering && widget.onPressed != null ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _hovering
                    ? [const Color(0xFF2277CC), const Color(0xFF58A6FF)]
                    : [const Color(0xFF1A5FA8), const Color(0xFF2E75B6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6)
                      .withOpacity(_hovering ? 0.55 : 0.3),
                  blurRadius: _hovering ? 24 : 14,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: widget.isUploading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : const Icon(Icons.upload, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
