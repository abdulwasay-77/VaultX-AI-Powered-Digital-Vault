import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// NOTES SCREEN — Premium VaultX UI Enhancement
// Design: Dark glassmorphism, animated particles, gradient cards, hover fx
// ═══════════════════════════════════════════════════════════════════════════

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TickerProviderStateMixin {
  List<NoteListItem> _notes = [];
  List<String> _folders = [];
  String? _selectedFolder;
  Note? _currentNote;
  int? _selectedNoteId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCreating = false;

  final TextEditingController _titleController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _editorFocusNode = FocusNode();

  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;

  late AnimationController _fabAnimationController;
  bool _isNoteOpen = false;

  // Entrance animation
  late AnimationController _entranceCtrl;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  // Particle background
  late AnimationController _particleCtrl;

  // Toolbar hover states
  final Map<String, bool> _toolbarHover = {};

  @override
  void initState() {
    super.initState();
    _initQuillController();
    _loadData();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  void _initQuillController() {
    _quillController = quill.QuillController(
      document: quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillController.addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    if (!_hasUnsavedChanges && _currentNote != null) {
      setState(() => _hasUnsavedChanges = true);
      _startAutoSaveTimer();
    }
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 10), () {
      if (_hasUnsavedChanges && _currentNote != null) _autoSave();
    });
  }

  Future<void> _autoSave() async {
    if (_currentNote == null || !_hasUnsavedChanges) return;
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await apiService.updateNote(
        _currentNote!.id,
        title: newTitle,
        content: jsonEncode(_quillController.document.toDelta().toJson()),
      );
      _hasUnsavedChanges = false;
      setState(() {
        if (_currentNote != null) {
          _currentNote = Note(
            id: _currentNote!.id,
            title: newTitle,
            content: _currentNote!.content,
            folder: _currentNote!.folder,
            updatedAt: DateTime.now(),
            createdAt: _currentNote!.createdAt,
          );
        }
        _isSaving = false;
      });
      await _loadNotes();
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadNotes(), _loadFolders()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await apiService.getNotes(folder: _selectedFolder);
      if (mounted) setState(() => _notes = notes);
    } catch (e) {
      if (mounted) setState(() => _notes = []);
    }
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await apiService.getFolders();
      if (mounted) setState(() => _folders = folders);
    } catch (e) {
      if (mounted) setState(() => _folders = []);
    }
  }

  Future<void> _createNewNote() async {
    setState(() => _isCreating = true);
    try {
      final emptyDoc = quill.Document();
      final newNote = await apiService.createNote(
        'Untitled Note',
        jsonEncode(emptyDoc.toDelta().toJson()),
        folder: _selectedFolder,
      );
      await _loadNotes();
      await _loadNote(newNote.id);
      if (mounted) {
        _showToast('New note created', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to create note: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _loadNote(int id) async {
    if (_hasUnsavedChanges && _currentNote != null) await _autoSave();
    try {
      final note = await apiService.getNote(id);
      if (mounted) {
        setState(() {
          _currentNote = note;
          _selectedNoteId = id;
          _titleController.text = note.title;
          _hasUnsavedChanges = false;
          _isNoteOpen = true;
        });
        _fabAnimationController.forward();
        try {
          final decoded = jsonDecode(note.content);
          if (decoded is List) {
            _quillController.document = quill.Document.fromJson(decoded);
          } else if (decoded is Map && decoded.containsKey('ops')) {
            _quillController.document =
                quill.Document.fromJson(decoded['ops'] as List);
          } else {
            _quillController.document = quill.Document();
          }
        } catch (e) {
          final doc = quill.Document();
          if (note.content.isNotEmpty && note.content != 'null') {
            doc.insert(0, note.content);
          }
          _quillController.document = doc;
        }
        _quillController.updateSelection(
          const TextSelection.collapsed(offset: 0),
          quill.ChangeSource.local,
        );
      }
    } catch (e) {
      if (mounted) _showToast('Failed to load note: $e', isSuccess: false);
    }
  }

  void _closeNote() async {
    if (_hasUnsavedChanges && _currentNote != null) await _autoSave();
    setState(() {
      _currentNote = null;
      _selectedNoteId = null;
      _titleController.clear();
      _quillController.clear();
      _hasUnsavedChanges = false;
      _isNoteOpen = false;
    });
    _fabAnimationController.reverse();
  }

  Future<void> _saveCurrentNote() async {
    if (_currentNote == null) return;
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) {
      _showToast('Title cannot be empty', isSuccess: false);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await apiService.updateNote(
        _currentNote!.id,
        title: newTitle,
        content: jsonEncode(_quillController.document.toDelta().toJson()),
      );
      _hasUnsavedChanges = false;
      await _loadNotes();
      setState(() {
        _currentNote = Note(
          id: _currentNote!.id,
          title: newTitle,
          content: _currentNote!.content,
          folder: _currentNote!.folder,
          updatedAt: DateTime.now(),
          createdAt: _currentNote!.createdAt,
        );
        _isSaving = false;
      });
      _showToast('Note saved', isSuccess: true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showToast('Failed to save: $e', isSuccess: false);
    }
  }

  Future<void> _deleteCurrentNote() async {
    if (_currentNote == null) return;
    final confirmed = await _showPremiumConfirmDialog(
      title: 'Delete Note',
      message:
          'Are you sure you want to delete "${_currentNote!.title}"?\nThis action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true) {
      try {
        await apiService.deleteNote(_currentNote!.id);
        await _loadNotes();
        await _loadFolders();
        setState(() {
          _currentNote = null;
          _selectedNoteId = null;
          _titleController.clear();
          _quillController.clear();
          _hasUnsavedChanges = false;
          _isNoteOpen = false;
        });
        _fabAnimationController.reverse();
        _showToast('Note deleted', isSuccess: false);
      } catch (e) {
        _showToast('Failed to delete: $e', isSuccess: false);
      }
    }
  }

  Future<void> _moveNoteToFolder(String folder) async {
    if (_currentNote == null) return;
    try {
      await apiService.moveNoteToFolder(_currentNote!.id, folder);
      await _loadNotes();
      await _loadFolders();
      setState(() {
        _currentNote = Note(
          id: _currentNote!.id,
          title: _currentNote!.title,
          content: _currentNote!.content,
          folder: folder.isEmpty ? null : folder,
          updatedAt: DateTime.now(),
          createdAt: _currentNote!.createdAt,
        );
      });
    } catch (e) {
      _showToast('Failed to move note: $e', isSuccess: false);
    }
  }

  Future<void> _createNewFolder() async {
    final controller = TextEditingController();
    final folderName = await _showPremiumInputDialog(
      title: 'New Folder',
      hint: 'Folder name...',
      icon: Icons.folder_outlined,
      controller: controller,
      confirmLabel: 'Create',
    );
    if (folderName != null && folderName.isNotEmpty) {
      try {
        await apiService.createFolder(folderName);
        await _loadFolders();
        _showToast('Folder "$folderName" created', isSuccess: true);
      } catch (e) {
        _showToast('Failed to create folder: $e', isSuccess: false);
      }
    }
  }

  Future<void> _deleteFolderDialog(String folder) async {
    final confirmed = await _showPremiumConfirmDialog(
      title: 'Delete Folder',
      message:
          'Delete the folder "$folder"?\nNotes inside will be moved to All Notes.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed == true) {
      try {
        // Move all notes to uncategorized and then reload
        for (final note in _notes.where((n) => n.folder == folder)) {
          await apiService.moveNoteToFolder(note.id, '');
        }
        await _loadFolders();
        await _loadNotes();
        if (_selectedFolder == folder) {
          setState(() => _selectedFolder = null);
        }
        _showToast('Folder deleted', isSuccess: false);
      } catch (e) {
        _showToast('Failed to delete folder: $e', isSuccess: false);
      }
    }
  }

  void _showToast(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool?> _showPremiumConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
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
                color: const Color(0xFF2E75B6).withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDestructive
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF2E75B6))
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDestructive
                            ? Icons.delete_outline
                            : Icons.info_outline,
                        color: isDestructive
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF58A6FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context, false),
                      color: const Color(0xFF5A7A9A),
                      filled: false,
                    ),
                    const SizedBox(width: 10),
                    _DialogButton(
                      label: confirmLabel,
                      onTap: () => Navigator.pop(context, true),
                      color: isDestructive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF2E75B6),
                      filled: true,
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

  Future<String?> _showPremiumInputDialog({
    required String title,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String confirmLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
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
                color: const Color(0xFF2E75B6).withOpacity(0.2),
                blurRadius: 40,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E75B6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(icon, color: const Color(0xFF58A6FF), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: const Color(0xFF58A6FF),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF2E75B6), width: 1.5),
                    ),
                  ),
                  onSubmitted: (v) => Navigator.pop(context, v.trim()),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context, null),
                      color: const Color(0xFF5A7A9A),
                      filled: false,
                    ),
                    const SizedBox(width: 10),
                    _DialogButton(
                      label: confirmLabel,
                      onTap: () =>
                          Navigator.pop(context, controller.text.trim()),
                      color: const Color(0xFF2E75B6),
                      filled: true,
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

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _quillController.dispose();
    _titleFocusNode.dispose();
    _editorFocusNode.dispose();
    _fabAnimationController.dispose();
    _entranceCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  void _applyFormat(quill.Attribute attribute) {
    _quillController.formatSelection(attribute);
  }

  void _clearFormatting() {
    final selection = _quillController.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    for (final attr in [
      quill.Attribute.bold,
      quill.Attribute.italic,
      quill.Attribute.underline,
      quill.Attribute.strikeThrough,
    ]) {
      _quillController.formatSelection(quill.Attribute.clone(attr, null));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D18),
      body: Stack(
        children: [
          // Particle background
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              painter: _NotesParticlePainter(_particleCtrl.value),
              size: Size.infinite,
            ),
          ),
          // Main content
          _isLoading
              ? _buildLoadingState()
              : FadeTransition(
                  opacity: _entranceFade,
                  child: SlideTransition(
                    position: _entranceSlide,
                    child: Row(
                      children: [
                        _buildFoldersPanel(),
                        Expanded(
                          child: Column(
                            children: [
                              _buildTopBar(),
                              Expanded(
                                child: _isNoteOpen
                                    ? _buildSplitView()
                                    : _buildNotesGrid(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimationController,
        builder: (context, child) {
          final offsetY = _isNoteOpen ? -140.0 : 0.0;
          return Transform.translate(
            offset: Offset(0, offsetY),
            child: _PremiumFAB(
              isLoading: _isCreating,
              onPressed: _isCreating ? null : _createNewNote,
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF58A6FF).withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Vault Notes...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0E2340).withOpacity(0.9),
            const Color(0xFF040D18).withOpacity(0.0),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sticky_note_2_outlined,
                    size: 14, color: Color(0xFF58A6FF)),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF2E75B6), Color(0xFF58A6FF)],
                  ).createShader(r),
                  child: const Text(
                    'SECURE NOTES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (_selectedFolder != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2E75B6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_outlined,
                      size: 12, color: Color(0xFF58A6FF)),
                  const SizedBox(width: 6),
                  Text(
                    _selectedFolder!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF58A6FF),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const Spacer(),
          // Stats
          _buildStatChip(Icons.note_alt_outlined, '${_notes.length}', 'notes',
              const Color(0xFF58A6FF)),
          const SizedBox(width: 12),
          _buildStatChip(Icons.folder_outlined, '${_folders.length}', 'folders',
              const Color(0xFF22C55E)),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FOLDERS PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFoldersPanel() {
    final allNotesCount = _notes.length;
    final folderCounts = <String, int>{};
    for (var note in _notes) {
      if (note.folder != null && note.folder!.isNotEmpty) {
        folderCounts[note.folder!] = (folderCounts[note.folder!] ?? 0) + 1;
      }
    }

    return Container(
      width: 230,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E2340), Color(0xFF0C1E36)],
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E75B6), Color(0xFF1A4A78)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.folder_special_outlined,
                      size: 15, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text(
                  'FOLDERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5A7A9A),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildFolderTile(
                  icon: Icons.all_inbox_outlined,
                  name: 'All Notes',
                  count: allNotesCount,
                  isSelected: _selectedFolder == null,
                  onTap: () {
                    setState(() => _selectedFolder = null);
                    _loadNotes();
                  },
                ),
                if (_folders.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'MY FOLDERS',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.25),
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._folders.map((folder) => _buildFolderTile(
                        icon: Icons.folder_outlined,
                        name: folder,
                        count: folderCounts[folder] ?? 0,
                        isSelected: _selectedFolder == folder,
                        onTap: () {
                          setState(() => _selectedFolder = folder);
                          _loadNotes();
                        },
                        onDelete: () => _deleteFolderDialog(folder),
                      )),
                ],
              ],
            ),
          ),
          // New folder button
          Padding(
            padding: const EdgeInsets.all(14),
            child: _NewFolderButton(onPressed: _createNewFolder),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile({
    required IconData icon,
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return _FolderTile(
      icon: icon,
      name: name,
      count: count,
      isSelected: isSelected,
      onTap: onTap,
      onDelete: onDelete,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTES GRID (when no note open)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNotesGrid() {
    if (_notes.isEmpty) {
      return _buildEmptyState();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  _selectedFolder == null ? 'All Notes' : _selectedFolder!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E75B6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_notes.length}',
                    style: const TextStyle(
                      color: Color(0xFF58A6FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 170,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return _NoteCard(
                  note: note,
                  isSelected: _selectedNoteId == note.id,
                  onTap: () => _loadNote(note.id),
                  index: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2E75B6).withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.note_add_outlined,
              size: 48,
              color: Color(0xFF2E75B6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notes yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first encrypted note',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPLIT VIEW (notes strip + editor)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSplitView() {
    return Column(
      children: [
        _buildNotesStrip(),
        Expanded(child: _buildEditor()),
      ],
    );
  }

  Widget _buildNotesStrip() {
    return Container(
      height: 134,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: _notes.isEmpty
          ? Center(
              child: Text(
                'No notes in this folder',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 12),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return _NoteStripCard(
                  note: note,
                  isSelected: _selectedNoteId == note.id,
                  onTap: () => _loadNote(note.id),
                );
              },
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDITOR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEditor() {
    if (_currentNote == null) return const SizedBox.shrink();

    final dropdownItems = <String>['Uncategorized'];
    for (final folder in _folders) {
      if (folder.isNotEmpty && folder != 'Uncategorized') {
        dropdownItems.add(folder);
      }
    }
    String currentFolderValue = _currentNote?.folder ?? 'Uncategorized';
    if (currentFolderValue.isEmpty) currentFolderValue = 'Uncategorized';
    if (!dropdownItems.contains(currentFolderValue)) {
      currentFolderValue = 'Uncategorized';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2340), Color(0xFF112B4E), Color(0xFF0C1E36)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E75B6).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          _buildEditorTitleBar(),
          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.07)),
          // Toolbar
          _buildEditorToolbar(),
          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.07)),
          // Editor body
          Expanded(child: _buildEditorBody()),
          // Footer
          Container(height: 1, color: Colors.white.withOpacity(0.07)),
          _buildEditorFooter(currentFolderValue, dropdownItems),
        ],
      ),
    );
  }

  Widget _buildEditorTitleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              cursorColor: const Color(0xFF58A6FF),
              decoration: InputDecoration(
                hintText: 'Note Title...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                if (!_hasUnsavedChanges && _currentNote != null) {
                  setState(() => _hasUnsavedChanges = true);
                  _startAutoSaveTimer();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          // Encrypted badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF22C55E).withOpacity(0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 11, color: Color(0xFF22C55E)),
                SizedBox(width: 5),
                Text(
                  'Encrypted',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Save status
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSaving
                ? const SizedBox(
                    key: ValueKey('saving'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF2E75B6)),
                  )
                : _hasUnsavedChanges
                    ? const Tooltip(
                        key: ValueKey('unsaved'),
                        message: 'Unsaved changes',
                        child: Icon(Icons.circle,
                            size: 8, color: Color(0xFFF59E0B)),
                      )
                    : const Tooltip(
                        key: ValueKey('saved'),
                        message: 'All changes saved',
                        child: Icon(Icons.check_circle_outline,
                            size: 14, color: Color(0xFF22C55E)),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            onTap: () => _applyFormat(quill.Attribute.bold),
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            onTap: () => _applyFormat(quill.Attribute.italic),
          ),
          _ToolbarButton(
            icon: Icons.format_underline,
            tooltip: 'Underline',
            onTap: () => _applyFormat(quill.Attribute.underline),
          ),
          _ToolbarButton(
            icon: Icons.format_strikethrough,
            tooltip: 'Strikethrough',
            onTap: () => _applyFormat(quill.Attribute.strikeThrough),
          ),
          _toolbarDivider(),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'Bullet List',
            onTap: () => _applyFormat(quill.Attribute.ul),
          ),
          _ToolbarButton(
            icon: Icons.format_list_numbered,
            tooltip: 'Numbered List',
            onTap: () => _applyFormat(quill.Attribute.ol),
          ),
          _toolbarDivider(),
          _ToolbarButton(
            icon: Icons.format_quote_outlined,
            tooltip: 'Quote',
            onTap: () => _applyFormat(quill.Attribute.blockQuote),
          ),
          _ToolbarButton(
            icon: Icons.code_outlined,
            tooltip: 'Code Block',
            onTap: () => _applyFormat(quill.Attribute.codeBlock),
          ),
          _toolbarDivider(),
          _ToolbarButton(
            icon: Icons.format_clear,
            tooltip: 'Clear Formatting',
            onTap: _clearFormatting,
          ),
          const Spacer(),
          // Save status text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _isSaving
                ? Text(
                    'Saving...',
                    key: const ValueKey('s1'),
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.4)),
                  )
                : _hasUnsavedChanges
                    ? const Text(
                        '● Unsaved',
                        key: ValueKey('s2'),
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                      )
                    : const Text(
                        '✓ Saved',
                        key: ValueKey('s3'),
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF22C55E)),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarDivider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildEditorBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF020810).withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.65,
            fontFamily: 'monospace',
          ),
          child: quill.QuillEditor(
            controller: _quillController,
            focusNode: _editorFocusNode,
            scrollController: ScrollController(),
            config: const quill.QuillEditorConfig(
              autoFocus: false,
              expands: true,
              padding: EdgeInsets.all(20),
              placeholder: 'Start writing your encrypted note...',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorFooter(
      String currentFolderValue, List<String> dropdownItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          // Folder dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_outlined,
                    size: 13, color: Color(0xFF5A7A9A)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: currentFolderValue,
                  dropdownColor: const Color(0xFF0E2340),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withOpacity(0.3), size: 16),
                  onChanged: (String? newFolder) {
                    if (newFolder != null) {
                      if (newFolder == 'Uncategorized') {
                        _moveNoteToFolder('');
                      } else {
                        _moveNoteToFolder(newFolder);
                      }
                    }
                  },
                  items: dropdownItems.map((folder) {
                    return DropdownMenuItem<String>(
                      value: folder,
                      child: Text(
                        folder == 'Uncategorized'
                            ? '  Uncategorized'
                            : '  $folder',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Spacer(),
          _FooterButton(
            icon: Icons.save_outlined,
            label: 'Save',
            color: const Color(0xFF2E75B6),
            onTap: _saveCurrentNote,
          ),
          const SizedBox(width: 8),
          _FooterButton(
            icon: Icons.close_rounded,
            label: 'Close',
            color: const Color(0xFF5A7A9A),
            onTap: _closeNote,
          ),
          const SizedBox(width: 8),
          _FooterButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFEF4444),
            onTap: _deleteCurrentNote,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PARTICLE PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _NotesParticlePainter extends CustomPainter {
  final double progress;
  static final List<_Particle> _particles = List.generate(
    14,
    (i) => _Particle(
      x: (i * 137.508 % 100) / 100,
      y: (i * 73.412 % 100) / 100,
      radius: 1.2 + (i % 4) * 0.6,
      speed: 0.003 + (i % 5) * 0.002,
      phase: i * 0.45,
    ),
  );

  _NotesParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF020810),
          Color(0xFF05111E),
          Color(0xFF081928),
          Color(0xFF040D18),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (final p in _particles) {
      final t = (progress + p.phase) % 1.0;
      final x = (p.x + math.sin(t * math.pi * 2) * 0.05) * size.width;
      final y =
          (p.y + math.cos(t * math.pi * 2 * p.speed * 20) * 0.08) * size.height;

      final paint = Paint()
        ..color = const Color(0xFF2E75B6)
            .withOpacity(0.15 + math.sin(t * math.pi * 2) * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_NotesParticlePainter old) => old.progress != progress;
}

class _Particle {
  final double x, y, radius, speed, phase;
  const _Particle(
      {required this.x,
      required this.y,
      required this.radius,
      required this.speed,
      required this.phase});
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTE CARD (grid view)
// ═══════════════════════════════════════════════════════════════════════════

class _NoteCard extends StatefulWidget {
  final NoteListItem note;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  const _NoteCard({
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  late Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _hoverAnim = CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  // Accent colors cycling for variety
  static const List<Color> _accentColors = [
    Color(0xFF2E75B6),
    Color(0xFF8B5CF6),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentColors[widget.index % _accentColors.length];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverCtrl.forward(),
      onExit: (_) => _hoverCtrl.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hoverAnim,
          builder: (context, child) {
            final scale = 1.0 + _hoverAnim.value * 0.02;
            final glowOpacity = _hoverAnim.value * 0.3;
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isSelected
                        ? [
                            accentColor.withOpacity(0.25),
                            const Color(0xFF0E2340),
                          ]
                        : [
                            const Color(0xFF0E2340),
                            const Color(0xFF0C1E36),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isSelected
                        ? accentColor.withOpacity(0.6)
                        : Colors.white
                            .withOpacity(0.07 + _hoverAnim.value * 0.1),
                    width: widget.isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(glowOpacity),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(Icons.note_outlined,
                          size: 15, color: accentColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.note.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.lock_outline,
                        size: 11, color: Colors.white.withOpacity(0.2)),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.note.getFormattedUpdatedAt(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.note.folder != null &&
                    widget.note.folder!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: accentColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_outlined,
                            size: 9, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          widget.note.folder!,
                          style: TextStyle(fontSize: 9, color: accentColor),
                        ),
                      ],
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

// ═══════════════════════════════════════════════════════════════════════════
// NOTE STRIP CARD (horizontal strip when editor is open)
// ═══════════════════════════════════════════════════════════════════════════

class _NoteStripCard extends StatefulWidget {
  final NoteListItem note;
  final bool isSelected;
  final VoidCallback onTap;

  const _NoteStripCard({
    required this.note,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NoteStripCard> createState() => _NoteStripCardState();
}

class _NoteStripCardState extends State<_NoteStripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) => Transform.scale(
            scale: 1.0 + _anim.value * 0.02,
            child: Container(
              width: 190,
              margin: const EdgeInsets.only(right: 10, bottom: 10, top: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isSelected
                      ? [
                          const Color(0xFF2E75B6).withOpacity(0.3),
                          const Color(0xFF0C1E36),
                        ]
                      : [
                          const Color(0xFF0E2340),
                          const Color(0xFF081928),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isSelected
                      ? const Color(0xFF2E75B6).withOpacity(0.6)
                      : Colors.white.withOpacity(0.06 + _anim.value * 0.08),
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E75B6).withOpacity(0.2),
                          blurRadius: 14,
                        ),
                      ]
                    : [],
              ),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note_outlined,
                        size: 13, color: Color(0xFF2E75B6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.note.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.note.getFormattedUpdatedAt(),
                  style: TextStyle(
                      fontSize: 9, color: Colors.white.withOpacity(0.3)),
                ),
                if (widget.note.folder != null &&
                    widget.note.folder!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_outlined,
                          size: 9, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 3),
                      Text(
                        widget.note.folder!,
                        style: TextStyle(
                            fontSize: 9, color: Colors.white.withOpacity(0.3)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOLDER TILE
// ═══════════════════════════════════════════════════════════════════════════

class _FolderTile extends StatefulWidget {
  final IconData icon;
  final String name;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FolderTile({
    required this.icon,
    required this.name,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
        _ctrl.forward();
        setState(() => _hovering = true);
      },
      onExit: (_) {
        _ctrl.reverse();
        setState(() => _hovering = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFF2E75B6).withOpacity(0.15)
                  : Colors.white.withOpacity(_anim.value * 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: widget.isSelected
                      ? const Color(0xFF2E75B6)
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.isSelected
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFF5A7A9A),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      color: widget.isSelected
                          ? Colors.white
                          : const Color(0xFF8B949E),
                      fontWeight: widget.isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.count > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? const Color(0xFF2E75B6).withOpacity(0.25)
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isSelected
                            ? const Color(0xFF58A6FF)
                            : const Color(0xFF8B949E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (widget.onDelete != null && _hovering) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOOLBAR BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
            animation: _anim,
            builder: (ctx, child) => Container(
              width: 30,
              height: 28,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_anim.value * 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                widget.icon,
                size: 16,
                color: Color.lerp(
                  const Color(0xFF5A7A9A),
                  const Color(0xFF58A6FF),
                  _anim.value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOOTER BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _FooterButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 140));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) => Transform.scale(
            scale: 1.0 + _anim.value * 0.05,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.08 + _anim.value * 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.color.withOpacity(0.2 + _anim.value * 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(_anim.value * 0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 14, color: widget.color),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIALOG BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.color,
    required this.filled,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, _) => Transform.scale(
            scale: 1.0 + _anim.value * 0.03,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: widget.filled
                    ? widget.color.withOpacity(0.85 + _anim.value * 0.15)
                    : widget.color.withOpacity(_anim.value * 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: widget.color.withOpacity(0.4 + _anim.value * 0.3)),
                boxShadow: widget.filled
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(_anim.value * 0.4),
                          blurRadius: 14,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.filled
                      ? Colors.white
                      : widget.color.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEW FOLDER BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _NewFolderButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _NewFolderButton({required this.onPressed});

  @override
  State<_NewFolderButton> createState() => _NewFolderButtonState();
}

class _NewFolderButtonState extends State<_NewFolderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) => Transform.scale(
            scale: 1.0 + _anim.value * 0.03,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF2E75B6)
                    .withOpacity(0.08 + _anim.value * 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF2E75B6)
                      .withOpacity(0.3 + _anim.value * 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF2E75B6).withOpacity(_anim.value * 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.create_new_folder_outlined,
                      size: 15, color: Color(0xFF2E75B6)),
                  SizedBox(width: 8),
                  Text(
                    'New Folder',
                    style: TextStyle(
                      color: Color(0xFF2E75B6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM FAB
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumFAB extends StatefulWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PremiumFAB({required this.isLoading, required this.onPressed});

  @override
  State<_PremiumFAB> createState() => _PremiumFABState();
}

class _PremiumFABState extends State<_PremiumFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) => Transform.scale(
            scale: 1.0 + _anim.value * 0.06,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      const Color(0xFF2E75B6),
                      const Color(0xFF58A6FF),
                      _anim.value,
                    )!,
                    const Color(0xFF1A4A78),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E75B6)
                        .withOpacity(0.3 + _anim.value * 0.3),
                    blurRadius: 20 + _anim.value * 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: widget.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_rounded,
                      color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
