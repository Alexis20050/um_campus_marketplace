import 'package:flutter/material.dart';

/// Pulsing placeholder matching the layout of `ProductCard`.
class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]!;
    final highlight = isDark ? const Color(0xFF3A3A3A) : Colors.grey[200]!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Pulse(
              base: base,
              highlight: highlight,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pulse(
                    base: base,
                    highlight: highlight,
                    child: _bar(base, width: double.infinity, height: 16),
                  ),
                  const SizedBox(height: 10),
                  _Pulse(
                    base: base,
                    highlight: highlight,
                    child: _bar(base, width: 120, height: 14),
                  ),
                  const SizedBox(height: 10),
                  _Pulse(
                    base: base,
                    highlight: highlight,
                    child: _bar(base, width: 180, height: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Wraps its child in a looping opacity pulse to create the shimmer feel.
class _Pulse extends StatefulWidget {
  final Widget child;
  final Color base;
  final Color highlight;

  const _Pulse({
    required this.child,
    required this.base,
    required this.highlight,
  });

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
