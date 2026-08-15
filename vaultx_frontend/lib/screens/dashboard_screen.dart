// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/sidebar_menu.dart';
import '../widgets/animated_search_bar.dart';
import '_vault_shared.dart';
import 'password_screen.dart';
import 'document_screen.dart';
import 'notes_screen.dart';
import 'risk_dashboard_screen.dart';
import 'backup_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final bool isFirstTime;
  const DashboardScreen({super.key, this.isFirstTime = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  // Data lists — all three are now loaded and tracked
  List<PasswordEntry> _passwords = [];
  List<Document> _documents = [];
  List<NoteListItem> _notes = [];

  String _username = '';
  bool _isFullScreen = false;
  bool _showExitHint = false;
  final FocusNode _keyboardFocusNode = FocusNode();

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  SearchResponse? _searchResponse;
  bool _isSearching = false;
  String? _searchError;
  Timer? _searchDebounce;

  // Particle animation for background
  late AnimationController _particleController;

  // Entrance animation
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  // Sub-screens
  late PasswordScreen _passwordScreen;
  late DocumentScreen _documentScreen;
  late NotesScreen _notesScreen;
  late RiskDashboardScreen _riskDashboardScreen;
  late BackupScreen _backupScreen;
  late ProfileScreen _profileScreen;

  final List<Map<String, dynamic>> _tabHeadings = [
    {'icon': Icons.dashboard_rounded, 'title': 'Dashboard'},
    {'icon': Icons.vpn_key_rounded, 'title': 'Passwords'},
    {'icon': Icons.folder_rounded, 'title': 'Documents'},
    {'icon': Icons.note_rounded, 'title': 'Notes'},
    {'icon': Icons.assessment_rounded, 'title': 'Risk Dashboard'},
    {'icon': Icons.backup_rounded, 'title': 'Backup'},
    {'icon': Icons.person_rounded, 'title': 'Profile'},
  ];

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _entranceFade = CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic));

    _entranceController.forward();

    _loadUserData();
    _loadAllData(); // ← loads passwords, documents, and notes together
    _initializeScreens();
    _searchController.addListener(_onSearchInputChanged);

    // Enter true fullscreen on dashboard launch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await windowManager.setFullScreen(true);
      if (mounted) setState(() => _isFullScreen = true);
      _keyboardFocusNode.requestFocus();
    });
  }

  void _initializeScreens() {
    _passwordScreen =
        PasswordScreen(passwords: _passwords, onRefresh: _loadPasswords);
    _documentScreen = const DocumentScreen();
    _notesScreen = const NotesScreen();
    _riskDashboardScreen = const RiskDashboardScreen();
    _backupScreen = const BackupScreen();
    _profileScreen = const ProfileScreen();
  }

  void _loadUserData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _username = auth.username ?? 'User';
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  /// Loads all three data types in parallel on first entry so the stat cards
  /// all populate at the same time without sequential waiting.
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadPasswords(),
      _loadDocuments(),
      _loadNotes(),
    ]);
  }

  Future<void> _loadPasswords() async {
    if (!mounted) return;
    try {
      final passwords = await apiService.getPasswords();
      if (mounted) {
        setState(() {
          _passwords = passwords;
          // Rebuild the password sub-screen so it also sees the fresh list
          _passwordScreen =
              PasswordScreen(passwords: _passwords, onRefresh: _loadPasswords);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    try {
      final documents = await apiService.getDocuments();
      if (mounted) {
        setState(() => _documents = documents);
      }
    } catch (_) {}
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    try {
      final notes = await apiService.getNotes();
      if (mounted) {
        setState(() => _notes = notes);
      }
    } catch (_) {}
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  void _onSearchInputChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 300), () => _performSearch());
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResponse = null;
        _isSearching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final response = await apiService.search(query);
      if (mounted) {
        setState(() {
          _searchResponse = response;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  void _onSearchResultTap(SearchResultItem result) {
    int targetIndex;
    switch (result.type) {
      case 'password':
        targetIndex = 1;
        break;
      case 'document':
        targetIndex = 2;
        break;
      case 'note':
        targetIndex = 3;
        break;
      default:
        targetIndex = 0;
    }
    setState(() {
      _selectedIndex = targetIndex;
      _searchController.clear();
      _searchResponse = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigated to ${result.type} section'),
        backgroundColor: const Color(0xFF2E75B6),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _logout() async {
    if (_isFullScreen) {
      await windowManager.setFullScreen(false);
    }
    await shrinkToLoginWindow();
    if (!mounted) return;
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onSidebarItemSelected(int index) {
    if (index >= 0) {
      setState(() {
        _selectedIndex = index;
        if (index != 0) {
          _searchController.clear();
          _searchResponse = null;
        }
      });
    }
  }

  void _toggleSidebar() =>
      setState(() => _isSidebarExpanded = !_isSidebarExpanded);

  Future<void> _exitFullScreen() async {
    await windowManager.setFullScreen(false);
    await expandToFullWindow();
    if (mounted) setState(() => _isFullScreen = false);
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _isFullScreen) {
      _exitFullScreen();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _particleController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF020810),
        body: Stack(
          children: [
            // Outer background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020810),
                    Color(0xFF05111E),
                    Color(0xFF081928),
                    Color(0xFF040D18),
                  ],
                  stops: [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),

            // Drifting particles background
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: VaultParticlePainter(_particleController.value),
                size: Size.infinite,
              ),
            ),

            // Main layout
            FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: Row(
                  children: [
                    // Sidebar
                    SidebarMenu(
                      selectedIndex: _selectedIndex,
                      onItemSelected: _onSidebarItemSelected,
                      onLogout: _logout,
                      onToggleSidebar: _toggleSidebar,
                      username: _username,
                      isExpanded: _isSidebarExpanded,
                    ),

                    // Main content area
                    Expanded(
                      child: Column(
                        children: [
                          // Top bar
                          _buildTopBar(),

                          // Content
                          Expanded(
                            child: _selectedIndex == 0
                                ? _buildDashboardHome()
                                : _buildContentView(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Escape hint — top-right corner, fades in on mouse hover
            if (_isFullScreen)
              Positioned(
                top: 12,
                right: 14,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _showExitHint = true),
                  onExit: (_) => setState(() => _showExitHint = false),
                  child: AnimatedOpacity(
                    opacity: _showExitHint ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _ExitFullScreenButton(onPressed: _exitFullScreen),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A1929).withOpacity(0.85),
            const Color(0xFF05111E).withOpacity(0.7),
          ],
        ),
        border: Border(
          bottom: BorderSide(
              color: const Color(0xFF1E4A7A).withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          // VaultX brand wordmark
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFCAE8FF), Color(0xFF58A6FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              '🔐 VAULTX',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.5,
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Tab heading (not for dashboard home)
          if (_selectedIndex != 0) ...[
            Container(
              width: 1,
              height: 28,
              color: const Color(0xFF1E4A7A).withOpacity(0.4),
            ),
            const SizedBox(width: 20),
            _buildTabBreadcrumb(),
          ],

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTabBreadcrumb() {
    final heading = _tabHeadings[_selectedIndex];
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2E75B6).withOpacity(0.25),
                const Color(0xFF2E75B6).withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2E75B6).withOpacity(0.3)),
          ),
          child: Icon(heading['icon'] as IconData,
              color: const Color(0xFF58A6FF), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          heading['title'] as String,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DASHBOARD HOME (tab 0)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner
          _WelcomeBanner(
            username: _username,
            isFirstTime: widget.isFirstTime,
          ),
          const SizedBox(height: 28),

          // Quick stats row — all three counts now live
          _buildStatsRow(),
          const SizedBox(height: 28),

          // Search bar
          AnimatedSearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onSearch: (q) => _performSearch(),
            onSuggestionSelected: (s) {
              _searchController.text = s;
              _performSearch();
            },
          ),
          const SizedBox(height: 28),

          // Search results / empty state
          _buildSearchBody(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          icon: Icons.vpn_key_rounded,
          label: 'Passwords',
          value: '${_passwords.length}',
          color: const Color(0xFF2E75B6),
          glowColor: const Color(0xFF58A6FF),
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.folder_rounded,
          label: 'Documents',
          value: '${_documents.length}', // ← was hardcoded '—'
          color: const Color(0xFFF59E0B),
          glowColor: const Color(0xFFFCD34D),
          onTap: () => setState(() => _selectedIndex = 2),
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.note_rounded,
          label: 'Notes',
          value: '${_notes.length}', // ← was hardcoded '—'
          color: const Color(0xFF8B5CF6),
          glowColor: const Color(0xFFA78BFA),
          onTap: () => setState(() => _selectedIndex = 3),
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.shield_rounded,
          label: 'Security Score',
          value: 'A+',
          color: const Color(0xFF22C55E),
          glowColor: const Color(0xFF4ADE80),
          onTap: () => setState(() => _selectedIndex = 4),
        ),
      ],
    );
  }

  Widget _buildSearchBody() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            color: Color(0xFF2E75B6),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(_searchError!,
                style: const TextStyle(color: Color(0xFF8B949E))),
          ],
        ),
      );
    }

    if (_searchResponse != null && _searchResponse!.total > 0) {
      return _buildSearchResults();
    }

    if (_searchResponse != null && _searchResponse!.total == 0) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try searching with different keywords',
      );
    }

    return _buildEmptyState(
      icon: Icons.manage_search_rounded,
      title: 'Search your vault',
      subtitle: 'Find passwords, documents and notes instantly',
    );
  }

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E75B6).withOpacity(0.15),
                    const Color(0xFF2E75B6).withOpacity(0.04),
                  ],
                ),
                shape: BoxShape.circle,
                border:
                    Border.all(color: const Color(0xFF2E75B6).withOpacity(0.2)),
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF4A7A9B)),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF8B9EAE),
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(color: Color(0xFF5A7A9A), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SEARCH RESULTS
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSearchResults() {
    final response = _searchResponse!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Query info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0E2340).withOpacity(0.8),
                const Color(0xFF0C1E36).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E4A7A).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 16, color: Color(0xFF58A6FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Results for "${response.query}"',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E75B6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${response.tookMs.toStringAsFixed(0)}ms',
                  style:
                      const TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
                ),
              ),
            ],
          ),
        ),

        if (response.expandedQuery.length > 1) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Text('Also searching:',
                  style: TextStyle(color: Color(0xFF6E8FAB), fontSize: 11)),
              ...response.expandedQuery
                  .where((q) => q != response.query)
                  .map((q) => Chip(
                        label: Text(q,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF58A6FF))),
                        backgroundColor:
                            const Color(0xFF2E75B6).withOpacity(0.1),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )),
            ],
          ),
        ],

        const SizedBox(height: 22),

        if (response.hasPasswords) ...[
          _buildResultSection(
            title: 'PASSWORDS',
            icon: Icons.vpn_key_rounded,
            count: response.passwords.length,
            accentColor: const Color(0xFF2E75B6),
            children:
                response.passwords.map((r) => _buildResultCard(r)).toList(),
          ),
          const SizedBox(height: 22),
        ],
        if (response.hasDocuments) ...[
          _buildResultSection(
            title: 'DOCUMENTS',
            icon: Icons.folder_rounded,
            count: response.documents.length,
            accentColor: const Color(0xFFF59E0B),
            children:
                response.documents.map((r) => _buildResultCard(r)).toList(),
          ),
          const SizedBox(height: 22),
        ],
        if (response.hasNotes) ...[
          _buildResultSection(
            title: 'NOTES',
            icon: Icons.note_rounded,
            count: response.notes.length,
            accentColor: const Color(0xFF8B5CF6),
            children: response.notes.map((r) => _buildResultCard(r)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildResultSection({
    required String title,
    required IconData icon,
    required int count,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: accentColor),
            ),
            const SizedBox(width: 8),
            Text(
              '$title  ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildResultCard(SearchResultItem result) {
    final color = result.getRelevanceColor();
    return _HoverResultCard(
      result: result,
      accentColor: color,
      onTap: () => _onSearchResultTap(result),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NON-DASHBOARD CONTENT VIEW
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildContentView() {
    switch (_selectedIndex) {
      case 1:
        return _passwordScreen;
      case 2:
        return _documentScreen;
      case 3:
        return _notesScreen;
      case 4:
        return _riskDashboardScreen;
      case 5:
        return _backupScreen;
      case 6:
        return _profileScreen;
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Welcome Banner ──────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  final String username;
  final bool isFirstTime;
  const _WelcomeBanner({
    required this.username,
    this.isFirstTime = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E2340),
            Color(0xFF112B4E),
            Color(0xFF0C1E36),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF1E4A7A).withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF1A3A6A).withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Shield icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E75B6).withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child:
                const Center(child: Text('🔐', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFCAE8FF), Color(0xFF58A6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    isFirstTime ? 'Welcome, $username!' : 'Welcome back, $username!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isFirstTime
                      ? 'Your new encrypted vault has been created and is ready.'
                      : 'Your encrypted vault is secured and ready.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5A7A9A)),
                ),
              ],
            ),
          ),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF22C55E).withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Encrypted',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────
class _StatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color glowColor;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween<double>(begin: 1.0, end: 1.04)
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
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _ctrl.forward(),
        onExit: (_) => _ctrl.reverse(),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0E2340),
                      Color(0xFF112B4E),
                      Color(0xFF0C1E36),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.color.withOpacity(0.25 + 0.35 * _glow.value),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.18 * _glow.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withOpacity(0.25),
                            widget.color.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, size: 20, color: widget.color),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6E8FAB)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hover Result Card ────────────────────────────────────────────────────────
class _HoverResultCard extends StatefulWidget {
  final SearchResultItem result;
  final Color accentColor;
  final VoidCallback onTap;

  const _HoverResultCard({
    required this.result,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_HoverResultCard> createState() => _HoverResultCardState();
}

class _HoverResultCardState extends State<_HoverResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
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
    final result = widget.result;
    final color = widget.accentColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0E2340).withOpacity(0.9),
                  const Color(0xFF0C1E36).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.12 + 0.3 * _glow.value),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.12 * _glow.value),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child:
                        Text(result.icon, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (result.tag != null)
                            _infoChip(Icons.label_outline, result.tag!,
                                const Color(0xFF8B949E)),
                          if (result.folder != null)
                            _infoChip(Icons.folder_outlined, result.folder!,
                                const Color(0xFF8B5CF6)),
                          if (result.category != null)
                            _infoChip(Icons.category_outlined, result.category!,
                                const Color(0xFFF59E0B)),
                          if (result.sensitivity != null)
                            _infoChip(
                              Icons.warning_amber_outlined,
                              result.sensitivity!,
                              result.sensitivity == 'High'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF22C55E),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${result.relevanceScore.toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
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

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}

// ─── Exit Fullscreen Button ───────────────────────────────────────────────────
class _ExitFullScreenButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _ExitFullScreenButton({required this.onPressed});

  @override
  State<_ExitFullScreenButton> createState() => _ExitFullScreenButtonState();
}

class _ExitFullScreenButtonState extends State<_ExitFullScreenButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 1.1)
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
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0E2340).withOpacity(0.92),
                    const Color(0xFF0C1E36).withOpacity(0.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1E4A7A)
                      .withOpacity(0.4 + 0.4 * (_scale.value - 1.0) / 0.1),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E75B6)
                        .withOpacity(0.20 * (_scale.value - 1.0) / 0.1),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fullscreen_exit_rounded,
                    size: 16,
                    color: _scale.value > 1.0
                        ? const Color(0xFF58A6FF)
                        : const Color(0xFF5A7A9A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Exit Fullscreen  (Esc)',
                    style: TextStyle(
                      fontSize: 11,
                      color: _scale.value > 1.0
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFF5A7A9A),
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
