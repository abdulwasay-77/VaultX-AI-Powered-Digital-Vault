import 'package:flutter/material.dart';
import '../models/models.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final PasswordStrengthResponse strength;

  const PasswordStrengthMeter({super.key, required this.strength});

  Color _getColor() {
    switch (strength.color) {
      case 'darkgreen':
        return const Color(0xFF00C853);
      case 'green':
        return const Color(0xFF22C55E);
      case 'yellow':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _getScoreLabel() {
    if (strength.score >= 90) return 'Very Strong';
    if (strength.score >= 70) return 'Strong';
    if (strength.score >= 40) return 'Moderate';
    return 'Weak';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strength.score / 100,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    color: color,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${strength.score}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _getScoreLabel(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (strength.feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 8),
            ...strength.feedback.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 12, color: Color(0xFF8B949E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8B949E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
