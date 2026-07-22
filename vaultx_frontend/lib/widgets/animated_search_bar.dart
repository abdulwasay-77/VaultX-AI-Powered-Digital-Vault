// lib/widgets/animated_search_bar.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSearch;
  final Function(String) onSuggestionSelected;

  const AnimatedSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSearch,
    required this.onSuggestionSelected,
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _colorController;
  Timer? _debounceTimer;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  // Full rainbow cycle: green → yellow → orange → red → violet → blue → cyan → green
  static const List<Color> _rainbowCycle = [
    Color(0xFF00FF88), // green
    Color(0xFF88FF00), // yellow-green
    Color(0xFFFFFF00), // yellow
    Color(0xFFFFAA00), // orange
    Color(0xFFFF4400), // red-orange
    Color(0xFFFF0088), // pink-red
    Color(0xFFAA00FF), // violet
    Color(0xFF4400FF), // indigo
    Color(0xFF0088FF), // blue
    Color(0xFF00CCFF), // cyan
    Color(0xFF00FFCC), // teal
    Color(0xFF00FF88), // back to green (seamless loop)
  ];

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // one full rainbow cycle
    )..repeat();
    // Rebuild when focus changes
    widget.focusNode.addListener(() => setState(() {}));
  }

  /// Interpolate smoothly between the rainbow stops based on animation value t ∈ [0,1]
  Color _rainbowAt(double t) {
    final count = _rainbowCycle.length - 1; // last == first for seamless
    final scaled = t * count;
    final index = scaled.floor().clamp(0, count - 1);
    final frac = scaled - index;
    return Color.lerp(_rainbowCycle[index], _rainbowCycle[index + 1], frac)!;
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(value);
      _loadSuggestions(value);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.isEmpty || query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _showSuggestions = query.isNotEmpty && query.length >= 2);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.focusNode.removeListener(() {});
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _colorController,
          builder: (context, child) {
            final t = _colorController.value;
            final primaryColor = _rainbowAt(t);
            // Ahead color for gradient sweep on border
            final secondaryColor = _rainbowAt((t + 0.25) % 1.0);

            final bool focused = widget.focusNode.hasFocus;

            return Transform.scale(
              scale: focused ? 1.015 : 1.0,
              child: Stack(
                children: [
                  // Outer spinning rainbow glow ring (always visible but faint when unfocused)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RainbowRingPainter(
                        t: t,
                        colors: _rainbowCycle,
                        opacity: focused ? 1.0 : 0.18,
                        glowRadius: focused ? 18.0 : 6.0,
                        borderRadius: 16,
                      ),
                    ),
                  ),
                  // The actual text field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      // Multi-layer glow shadow
                      boxShadow: focused
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.45),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: secondaryColor.withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: 6,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.08),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search your vault...',
                        hintStyle: const TextStyle(color: Color(0xFF5A7A9A)),
                        prefixIcon: Icon(
                          Icons.search,
                          color:
                              focused ? primaryColor : const Color(0xFF2E75B6),
                          size: 22,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: primaryColor.withOpacity(0.8),
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: primaryColor.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2.2,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF07111C),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0E2340),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF1E4A7A).withOpacity(0.4)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion,
                      style: const TextStyle(color: Color(0xFF58A6FF))),
                  backgroundColor: const Color(0xFF2E75B6).withOpacity(0.1),
                  onPressed: () {
                    widget.controller.text = suggestion;
                    widget.onSearch(suggestion);
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void updateSuggestions(List<String> suggestions) {
    setState(() {
      _suggestions = suggestions;
    });
  }
}

/// Paints a spinning conic-gradient-like rainbow ring around the search bar.
class _RainbowRingPainter extends CustomPainter {
  final double t; // 0..1 animation progress
  final List<Color> colors;
  final double opacity;
  final double glowRadius;
  final double borderRadius;

  _RainbowRingPainter({
    required this.t,
    required this.colors,
    required this.opacity,
    required this.glowRadius,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(borderRadius));

    // Build sweep gradient rotated by current animation angle
    final sweepAngle = t * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + 2 * math.pi,
        colors: [
          ...colors.map((c) => c.withOpacity(opacity)),
        ],
        stops: List.generate(
            colors.length, (i) => i / (colors.length - 1).toDouble()),
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);

    // Soft outer glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowRadius
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.5)
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + 2 * math.pi,
        colors: [
          ...colors.map((c) => c.withOpacity(opacity * 0.35)),
        ],
        stops: List.generate(
            colors.length, (i) => i / (colors.length - 1).toDouble()),
      ).createShader(rect);

    canvas.drawRRect(rrect, glowPaint);
  }

  @override
  bool shouldRepaint(_RainbowRingPainter old) =>
      old.t != t || old.opacity != opacity;
}
