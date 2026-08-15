// lib/widgets/sidebar_menu.dart
import 'package:flutter/material.dart';
import 'sidebar_toggle.dart';

class SidebarMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final VoidCallback onToggleSidebar;
  final String username;
  final bool isExpanded;

  const SidebarMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
    required this.onToggleSidebar,
    required this.username,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return _CollapsedSidebar(
        selectedIndex: selectedIndex,
        onItemSelected: onItemSelected,
        onLogout: onLogout,
        onToggleSidebar: onToggleSidebar,
      );
    }

    return Container(
      width: 240,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E2340),
            Color(0xFF0C1E36),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: const Color(0xFF1E4A7A).withOpacity(0.45),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top toggle row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                SidebarToggleIcon(
                  onTap: onToggleSidebar,
                  isSidebarExpanded: isExpanded,
                ),
                const Spacer(),
              ],
            ),
          ),

          const Spacer(flex: 1),

          // User avatar + info
          Center(
            child: Column(
              children: [
                // Avatar with glow ring
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E75B6), Color(0xFF1A4D7A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E75B6).withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🔐', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF22C55E).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Vault Active',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF22C55E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 1),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF1E4A7A).withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Nav items
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            index: 0,
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _SidebarItem(
            icon: Icons.vpn_key_rounded,
            label: 'Passwords',
            index: 1,
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          _SidebarItem(
            icon: Icons.folder_rounded,
            label: 'Documents',
            index: 2,
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
          _SidebarItem(
            icon: Icons.note_rounded,
            label: 'Notes',
            index: 3,
            isSelected: selectedIndex == 3,
            onTap: () => onItemSelected(3),
          ),
          _SidebarItem(
            icon: Icons.assessment_rounded,
            label: 'Risk Dashboard',
            index: 4,
            isSelected: selectedIndex == 4,
            onTap: () => onItemSelected(4),
          ),
          _SidebarItem(
            icon: Icons.backup_rounded,
            label: 'Backup',
            index: 5,
            isSelected: selectedIndex == 5,
            onTap: () => onItemSelected(5),
          ),
          _SidebarItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            index: 6,
            isSelected: selectedIndex == 6,
            onTap: () => onItemSelected(6),
          ),

          const SizedBox(height: 10),

          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF1E4A7A).withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          _SidebarItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            index: -2,
            isSelected: false,
            isLogout: true,
            onTap: onLogout,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Single animated sidebar nav item
class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool isSelected;
  final bool isLogout;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.isSelected,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem>
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
    _scale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _activeColor =>
      widget.isLogout ? const Color(0xFFEF4444) : const Color(0xFF2E75B6);
  Color get _glowColor =>
      widget.isLogout ? const Color(0xFFEF4444) : const Color(0xFF58A6FF);

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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: widget.isSelected
                    ? LinearGradient(
                        colors: [
                          _activeColor.withOpacity(0.18),
                          _activeColor.withOpacity(0.06),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : (_hovering
                        ? LinearGradient(
                            colors: [
                              _activeColor.withOpacity(0.10),
                              Colors.transparent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null),
                borderRadius: BorderRadius.circular(10),
                border: widget.isSelected
                    ? Border.all(
                        color: _activeColor.withOpacity(0.4),
                        width: 1.1,
                      )
                    : (_hovering
                        ? Border.all(
                            color: _activeColor.withOpacity(0.18),
                            width: 1.0,
                          )
                        : null),
                boxShadow: (widget.isSelected || _hovering)
                    ? [
                        BoxShadow(
                          color: _glowColor.withOpacity(0.15 * _glow.value),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Icon with glow on selected/hover
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: (widget.isSelected || _hovering)
                          ? LinearGradient(
                              colors: [
                                _activeColor.withOpacity(0.25),
                                _activeColor.withOpacity(0.08),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: (widget.isSelected || _hovering)
                          ? _activeColor
                          : const Color(0xFF5A7A9A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: (widget.isSelected || _hovering)
                            ? (widget.isLogout
                                ? const Color(0xFFEF4444)
                                : Colors.white)
                            : const Color(0xFF6E8FAB),
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Active indicator dot
                  if (widget.isSelected)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _activeColor.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
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

// ─── Collapsed sidebar ────────────────────────────────────────────────────────
class _CollapsedSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final VoidCallback onToggleSidebar;

  const _CollapsedSidebar({
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0E2340),
            Color(0xFF0C1E36),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: const Color(0xFF1E4A7A).withOpacity(0.45),
            width: 1.2,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          SidebarToggleIcon(
            onTap: onToggleSidebar,
            isSidebarExpanded: false,
          ),
          const SizedBox(height: 20),
          _CollapsedIcon(
              icon: Icons.dashboard_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onItemSelected(0)),
          _CollapsedIcon(
              icon: Icons.vpn_key_rounded,
              isSelected: selectedIndex == 1,
              onTap: () => onItemSelected(1)),
          _CollapsedIcon(
              icon: Icons.folder_rounded,
              isSelected: selectedIndex == 2,
              onTap: () => onItemSelected(2)),
          _CollapsedIcon(
              icon: Icons.note_rounded,
              isSelected: selectedIndex == 3,
              onTap: () => onItemSelected(3)),
          _CollapsedIcon(
              icon: Icons.assessment_rounded,
              isSelected: selectedIndex == 4,
              onTap: () => onItemSelected(4)),
          _CollapsedIcon(
              icon: Icons.backup_rounded,
              isSelected: selectedIndex == 5,
              onTap: () => onItemSelected(5)),
          _CollapsedIcon(
              icon: Icons.person_rounded,
              isSelected: selectedIndex == 6,
              onTap: () => onItemSelected(6)),
          const Spacer(),
          _CollapsedIcon(
              icon: Icons.logout_rounded,
              isSelected: false,
              onTap: onLogout,
              isLogout: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CollapsedIcon extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLogout;

  const _CollapsedIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  State<_CollapsedIcon> createState() => _CollapsedIconState();
}

class _CollapsedIconState extends State<_CollapsedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color => widget.isLogout
      ? const Color(0xFFEF4444)
      : (widget.isSelected ? const Color(0xFF58A6FF) : const Color(0xFF5A7A9A));

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
              margin: const EdgeInsets.symmetric(vertical: 4),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? const Color(0xFF2E75B6).withOpacity(0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: widget.isSelected
                    ? Border.all(
                        color: const Color(0xFF2E75B6).withOpacity(0.4))
                    : null,
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2E75B6).withOpacity(0.25),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
              child: Icon(widget.icon, size: 20, color: _color),
            ),
          ),
        ),
      ),
    );
  }
}
