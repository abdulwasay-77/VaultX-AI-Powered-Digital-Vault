// lib/screens/backup_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'dashboard_screen.dart';

// ═══════════════════════════════════════════════════════════
//  BACKUP SCREEN — Premium VaultX UI (fully enhanced)
// ═══════════════════════════════════════════════════════════

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with TickerProviderStateMixin {
  List<BackupHistoryItem> _backupHistory = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isRestoring = false;
  String? _errorMessage;

  // Particle background
  late AnimationController _particleController;
  // Entrance animation
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;
  // Pulse glow on action cards
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceFade = CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _loadBackupHistory();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Data Methods ───────────────────────────────────────────

  Future<void> _loadBackupHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await apiService.getBackupHistory();
      setState(() {
        _backupHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDashboard() async {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);
    try {
      final result = await apiService.exportBackup();
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName:
            'vaultx_backup_${DateTime.now().toIso8601String().split('T')[0]}.vaultx',
      );
      if (savePath != null) {
        final sourceFile = File(result.filePath);
        await sourceFile.copy(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup saved to: $savePath'),
              backgroundColor: const Color(0xFF22C55E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      await _loadBackupHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _restoreBackup() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      dialogTitle: 'Select Backup File',
      allowedExtensions: ['vaultx'],
    );
    if (result == null) return;

    final backupFile = File(result.files.single.path!);
    final fileName = result.files.single.name;
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _PremiumDialog(
        title: 'Restore Backup',
        titleIcon: Icons.restore_rounded,
        titleIconColor: const Color(0xFF58A6FF),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E75B6).withOpacity(0.08),
                    const Color(0xFF58A6FF).withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2E75B6).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_rounded,
                      color: Color(0xFF58A6FF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                          color: Color(0xFF58A6FF), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PremiumTextField(
              controller: passwordController,
              label: 'Master Password',
              hint: 'Enter your master password',
              obscure: true,
              icon: Icons.lock_rounded,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.merge_type_rounded,
                      color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Smart Merge: Existing data will be preserved. Only missing items will be restored.',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _DialogButton(
            label: 'Cancel',
            onTap: () => Navigator.pop(context, false),
            color: const Color(0xFF5A7A9A),
          ),
          _DialogButton(
            label: 'Restore',
            onTap: () => Navigator.pop(context, true),
            color: const Color(0xFF2E75B6),
            filled: true,
            icon: Icons.restore_rounded,
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LoadingDialog(message: 'Restoring vault...'),
    );

    try {
      final restoreResult = await apiService.restoreBackup(
        backupFilePath: backupFile.path,
        masterPassword: passwordController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        await showDialog(
          context: context,
          builder: (context) => _PremiumDialog(
            title: 'Restore Complete',
            titleIcon: Icons.check_circle_rounded,
            titleIconColor: const Color(0xFF22C55E),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smart merge completed:',
                    style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 12),
                _buildRestoreStat('Passwords restored',
                    restoreResult.restored['passwords'] ?? 0),
                _buildRestoreStat('Passwords updated',
                    restoreResult.restored['passwords_updated'] ?? 0),
                _buildRestoreStat('Documents restored',
                    restoreResult.restored['documents'] ?? 0),
                _buildRestoreStat('Documents updated',
                    restoreResult.restored['documents_updated'] ?? 0),
                _buildRestoreStat(
                    'Notes restored', restoreResult.restored['notes'] ?? 0),
                _buildRestoreStat('Notes updated',
                    restoreResult.restored['notes_updated'] ?? 0),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF22C55E).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          color: Color(0xFF22C55E), size: 14),
                      SizedBox(width: 6),
                      Text('Your existing data has been preserved.',
                          style: TextStyle(
                              color: Color(0xFF22C55E), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              _DialogButton(
                label: 'Done',
                onTap: () async {
                  Navigator.pop(context);
                  await _refreshDashboard();
                },
                color: const Color(0xFF2E75B6),
                filled: true,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  Widget _buildRestoreStat(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 11, color: Color(0xFF22C55E)),
          ),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Color(0xFFB0C4D8), fontSize: 13)),
          Text('$count',
              style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _downloadBackup(BackupHistoryItem backup) async {
    String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: backup.backupFilePath.split('\\').last,
    );
    if (savePath == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LoadingDialog(message: 'Downloading backup...'),
    );

    try {
      await apiService.downloadBackupFile(backup.id, savePath);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to: $savePath'),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteBackup(BackupHistoryItem backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _PremiumDialog(
        title: 'Delete Backup',
        titleIcon: Icons.delete_rounded,
        titleIconColor: const Color(0xFFEF4444),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_rounded,
                      color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      backup.backupFilePath.split('\\').last,
                      style: const TextStyle(
                          color: Color(0xFFEF4444), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'This action cannot be undone. The backup record will be permanently removed.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
            ),
          ],
        ),
        actions: [
          _DialogButton(
            label: 'Cancel',
            onTap: () => Navigator.pop(context, false),
            color: const Color(0xFF5A7A9A),
          ),
          _DialogButton(
            label: 'Delete',
            onTap: () => Navigator.pop(context, true),
            color: const Color(0xFFEF4444),
            filled: true,
            icon: Icons.delete_rounded,
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await apiService.deleteBackupRecord(backup.id);
        await _loadBackupHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup deleted'),
              backgroundColor: Color(0xFF22C55E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D18),
      body: Stack(
        children: [
          // Particle background
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              painter: _BackupParticlePainter(_particleController.value),
              child: const SizedBox.expand(),
            ),
          ),
          // Main content with entrance animation
          FadeTransition(
            opacity: _entranceFade,
            child: SlideTransition(
              position: _entranceSlide,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                            child: Column(
                              children: [
                                _buildStatsRow(),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildExportCard()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildRestoreCard()),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildHistorySection(),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          // Breadcrumb pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0E2340).withOpacity(0.9),
                  const Color(0xFF112B4E).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E75B6).withOpacity(0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6).withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF2E75B6), Color(0xFF58A6FF)],
                  ).createShader(r),
                  child: const Icon(Icons.backup_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
                  ).createShader(r),
                  child: const Text(
                    'BACKUP & RESTORE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Refresh button
          _HoverButton(
            onTap: _loadBackupHistory,
            tooltip: 'Refresh',
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0E2340).withOpacity(0.9),
                    const Color(0xFF112B4E).withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF58A6FF), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ───────────────────────────────────────────────

  Widget _buildStatsRow() {
    final total = _backupHistory.length;
    final latestDate =
        total > 0 ? _backupHistory.first.getFormattedDate() : 'No backups yet';
    final totalSize = _backupHistory.fold<int>(0, (sum, b) => sum + b.fileSize);
    final sizeLabel = totalSize > 0
        ? '${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB'
        : '0 MB';

    return Row(
      children: [
        _StatChip(
          icon: Icons.history_rounded,
          label: 'Total Backups',
          value: '$total',
          color: const Color(0xFF2E75B6),
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.access_time_rounded,
          label: 'Latest Backup',
          value: latestDate,
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: Icons.storage_rounded,
          label: 'Total Size',
          value: sizeLabel,
          color: const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  // ── Export Card ─────────────────────────────────────────────

  Widget _buildExportCard() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF2E75B6)
                .withOpacity(0.25 + 0.15 * _pulseAnim.value),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  const Color(0xFF2E75B6).withOpacity(0.08 * _pulseAnim.value),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Column(
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
                      const Color(0xFF2E75B6).withOpacity(0.25),
                      const Color(0xFF58A6FF).withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2E75B6).withOpacity(0.4)),
                ),
                child: const Icon(Icons.cloud_upload_rounded,
                    color: Color(0xFF58A6FF), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
                    ).createShader(r),
                    child: const Text(
                      'EXPORT VAULT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Text(
                    'Create encrypted backup',
                    style: TextStyle(color: Color(0xFF5A7A9A), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          const Text(
            'Create a complete encrypted backup of all your vault data — passwords, documents, and notes.',
            style:
                TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: const Color(0xFF22C55E).withOpacity(0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF22C55E), size: 12),
                SizedBox(width: 5),
                Text(
                  'AES-256 Encrypted · .vaultx format',
                  style: TextStyle(color: Color(0xFF22C55E), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Export button
          _PremiumGradientButton(
            label: _isExporting ? 'Exporting...' : 'Export Now',
            icon: _isExporting ? null : Icons.cloud_upload_rounded,
            loading: _isExporting,
            onTap: _isExporting ? null : _exportBackup,
            color: const Color(0xFF2E75B6),
          ),
        ],
      ),
    );
  }

  // ── Restore Card ────────────────────────────────────────────

  Widget _buildRestoreCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.04),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
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
                      const Color(0xFFF59E0B).withOpacity(0.2),
                      const Color(0xFFF59E0B).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.35)),
                ),
                child: const Icon(Icons.restore_rounded,
                    color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ).createShader(r),
                    child: const Text(
                      'RESTORE VAULT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Text(
                    'Recover from backup file',
                    style: TextStyle(color: Color(0xFF5A7A9A), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          const Text(
            'Restore your vault from a .vaultx backup file. Uses smart merge to protect your current data.',
            style:
                TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          // Smart merge badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2E75B6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: const Color(0xFF2E75B6).withOpacity(0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.merge_type_rounded,
                    color: Color(0xFF58A6FF), size: 12),
                SizedBox(width: 5),
                Text(
                  'Smart Merge · Existing data preserved',
                  style: TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Restore button
          _PremiumOutlinedButton(
            label: _isRestoring ? 'Restoring...' : 'Select Backup File',
            icon: _isRestoring ? null : Icons.folder_open_rounded,
            loading: _isRestoring,
            onTap: _isRestoring ? null : _restoreBackup,
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  // ── History Section ─────────────────────────────────────────

  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E75B6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2E75B6).withOpacity(0.3)),
                ),
                child: const Icon(Icons.history_rounded,
                    color: Color(0xFF58A6FF), size: 16),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF58A6FF), Color(0xFF2E75B6)],
                ).createShader(r),
                child: const Text(
                  'BACKUP HISTORY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              // Count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E75B6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF2E75B6).withOpacity(0.3)),
                ),
                child: Text(
                  '${_backupHistory.length} records',
                  style: const TextStyle(
                    color: Color(0xFF58A6FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Gradient divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 16, top: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2E75B6).withOpacity(0.0),
                  const Color(0xFF2E75B6).withOpacity(0.35),
                  const Color(0xFF58A6FF).withOpacity(0.2),
                  const Color(0xFF2E75B6).withOpacity(0.0),
                ],
              ),
            ),
          ),
          // Content
          if (_backupHistory.isEmpty)
            _buildEmptyHistory()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backupHistory.length,
              separatorBuilder: (_, __) => Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.white.withOpacity(0.04),
              ),
              itemBuilder: (context, index) {
                return _BackupHistoryCard(
                  backup: _backupHistory[index],
                  onDownload: () => _downloadBackup(_backupHistory[index]),
                  onDelete: () => _deleteBackup(_backupHistory[index]),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E75B6).withOpacity(0.15),
                    const Color(0xFF2E75B6).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF2E75B6).withOpacity(0.25)),
              ),
              child: const Icon(Icons.backup_rounded,
                  color: Color(0xFF2E75B6), size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Backups Found',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create your first backup using Export above.',
              style: TextStyle(color: Color(0xFF5A7A9A), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xFF2E75B6),
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading backup history...',
            style: TextStyle(color: Color(0xFF5A7A9A), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  BACKUP HISTORY CARD
// ═══════════════════════════════════════════════════════════

class _BackupHistoryCard extends StatefulWidget {
  final BackupHistoryItem backup;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _BackupHistoryCard({
    required this.backup,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  State<_BackupHistoryCard> createState() => _BackupHistoryCardState();
}

class _BackupHistoryCardState extends State<_BackupHistoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnim;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.015).animate(
        CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.backup.backupFilePath.split('\\').last;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hovering = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovering
                ? const Color(0xFF2E75B6).withOpacity(0.07)
                : const Color(0xFF0E2340).withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovering
                  ? const Color(0xFF2E75B6).withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E75B6).withOpacity(0.12),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2E75B6).withOpacity(0.2),
                      const Color(0xFF58A6FF).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF2E75B6).withOpacity(0.3)),
                ),
                child: const Icon(Icons.backup_rounded,
                    color: Color(0xFF58A6FF), size: 20),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: Color(0xFF5A7A9A)),
                        const SizedBox(width: 4),
                        Text(
                          widget.backup.getFormattedDate(),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF5A7A9A)),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.storage_rounded,
                            size: 11, color: Color(0xFF5A7A9A)),
                        const SizedBox(width: 4),
                        Text(
                          widget.backup.getFormattedFileSize(),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF5A7A9A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              _IconActionButton(
                icon: Icons.download_rounded,
                color: const Color(0xFF2E75B6),
                tooltip: 'Download',
                onTap: widget.onDownload,
              ),
              const SizedBox(width: 4),
              _IconActionButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFEF4444),
                tooltip: 'Delete',
                onTap: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  STAT CHIP
// ═══════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0E2340).withOpacity(0.9),
              const Color(0xFF0C1E36).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style:
                        const TextStyle(color: Color(0xFF5A7A9A), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PREMIUM BUTTONS
// ═══════════════════════════════════════════════════════════

class _PremiumGradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;
  final Color color;

  const _PremiumGradientButton({
    required this.label,
    required this.color,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  State<_PremiumGradientButton> createState() => _PremiumGradientButtonState();
}

class _PremiumGradientButtonState extends State<_PremiumGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => widget.onTap != null ? _ctrl.forward() : null,
      onExit: (_) => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.onTap != null
                    ? [widget.color, widget.color.withOpacity(0.7)]
                    : [Colors.grey.shade700, Colors.grey.shade800],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: widget.onTap != null
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, color: Colors.white, size: 16),
                if (!widget.loading && widget.icon != null)
                  const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

class _PremiumOutlinedButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;
  final Color color;

  const _PremiumOutlinedButton({
    required this.label,
    required this.color,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  State<_PremiumOutlinedButton> createState() => _PremiumOutlinedButtonState();
}

class _PremiumOutlinedButtonState extends State<_PremiumOutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hovering = true);
        if (widget.onTap != null) _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _hovering
                  ? widget.color.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: _hovering ? widget.color : widget.color.withOpacity(0.5),
              ),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: widget.color),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, color: widget.color, size: 16),
                if (!widget.loading && widget.icon != null)
                  const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

// ═══════════════════════════════════════════════════════════
//  ICON ACTION BUTTON (for history card)
// ═══════════════════════════════════════════════════════════

class _IconActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.color.withOpacity(0.25)),
              ),
              child: Icon(widget.icon, color: widget.color, size: 16),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HOVER BUTTON
// ═══════════════════════════════════════════════════════════

class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  const _HoverButton({
    required this.child,
    required this.onTap,
    this.tooltip = '',
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _ctrl.forward(),
        onExit: (_) => _ctrl.reverse(),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _scale,
            builder: (_, child) =>
                Transform.scale(scale: _scale.value, child: child!),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PREMIUM DIALOG
// ═══════════════════════════════════════════════════════════

class _PremiumDialog extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final Color titleIconColor;
  final Widget content;
  final List<Widget> actions;

  const _PremiumDialog({
    required this.title,
    required this.titleIcon,
    required this.titleIconColor,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: titleIconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: titleIconColor.withOpacity(0.3)),
                  ),
                  child: Icon(titleIcon, color: titleIconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            content,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children:
                  actions.expand((w) => [w, const SizedBox(width: 8)]).toList()
                    ..removeLast(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DIALOG BUTTON
// ═══════════════════════════════════════════════════════════

class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;
  final IconData? icon;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.color,
    this.filled = false,
    this.icon,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 1.04)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: widget.filled
                  ? LinearGradient(
                      colors: [widget.color, widget.color.withOpacity(0.75)])
                  : null,
              color: widget.filled
                  ? null
                  : (_hovering
                      ? widget.color.withOpacity(0.08)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering || widget.filled
                    ? widget.color
                    : widget.color.withOpacity(0.4),
              ),
              boxShadow: _hovering && widget.filled
                  ? [
                      BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon,
                      color: widget.filled ? Colors.white : widget.color,
                      size: 14),
                  const SizedBox(width: 5),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.filled ? Colors.white : widget.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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

// ═══════════════════════════════════════════════════════════
//  PREMIUM TEXT FIELD
// ═══════════════════════════════════════════════════════════

class _PremiumTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final IconData icon;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  @override
  State<_PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<_PremiumTextField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.obscure && !_visible,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: const TextStyle(color: Color(0xFF5A7A9A)),
        hintStyle: const TextStyle(color: Color(0xFF30363D)),
        prefixIcon: Icon(widget.icon, color: const Color(0xFF2E75B6), size: 18),
        suffixIcon: widget.obscure
            ? GestureDetector(
                onTap: () => setState(() => _visible = !_visible),
                child: Icon(
                  _visible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: const Color(0xFF5A7A9A),
                  size: 18,
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF020810).withOpacity(0.6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2E75B6), width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LOADING DIALOG
// ═══════════════════════════════════════════════════════════

class _LoadingDialog extends StatelessWidget {
  final String message;
  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: Color(0xFF2E75B6),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PARTICLE PAINTER
// ═══════════════════════════════════════════════════════════

class _BackupParticlePainter extends CustomPainter {
  final double progress;
  static const int _count = 12;

  _BackupParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (int i = 0; i < _count; i++) {
      final seed = i / _count;
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.4;
      final amplitude = 20.0 + rng.nextDouble() * 30.0;
      final phase = rng.nextDouble() * 2 * math.pi;

      final x =
          baseX + amplitude * math.cos(2 * math.pi * progress * speed + phase);
      final y = baseY +
          amplitude *
              0.5 *
              math.sin(2 * math.pi * progress * speed + phase + seed);

      final opacity = 0.04 + 0.06 * math.sin(2 * math.pi * progress + seed * 3);
      final radius = 1.0 + rng.nextDouble() * 2.0;

      final paint = Paint()
        ..color = const Color(0xFF2E75B6).withOpacity(opacity.clamp(0, 1))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BackupParticlePainter old) => old.progress != progress;
}
