import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import 'explainer_bottom_sheet.dart';

class HeroProgressCard extends StatelessWidget {
  final int steps;
  final int goal;
  final VoidCallback onAdjustGoal;

  const HeroProgressCard({
    super.key,
    required this.steps,
    required this.goal,
    required this.onAdjustGoal,
  });

  void _showExplainer(BuildContext context) {
    ExplainerBottomSheet.show(
      context,
      title: 'Step Syncing',
      headerIcon: Icons.sync,
      primaryColor: const Color(0xFF26D0CE), // Cyan
      items: const [
        ExplainerItem(
          title: 'Secure Background Sync',
          description: 'Steps are synced securely from your phone\'s native health app.',
          icon: Icons.security,
        ),
        ExplainerItem(
          title: 'Instant Refresh',
          description: 'Syncing happens automatically in the background, but you can always pull down on the dashboard to force an instant refresh.',
          icon: Icons.refresh,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (steps / goal).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      height: 190, // Significantly reduced from 360
      margin: const EdgeInsets.symmetric(horizontal: 4), // Tiny margin for shadow
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2980), // Deep Royal Blue
            Color(0xFF26D0CE), // Cyan/Teal
          ],
        ),
        borderRadius: BorderRadius.circular(24), // Smoother corners
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26D0CE).withAlpha(102),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF1A2980).withAlpha(102),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background circle
          // Decorative background circle - Glassmorphism Blob
          Positioned(
            top: -60, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withAlpha(13),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ]
              ),
            ),
          ),
          Positioned(
            bottom: -40, right: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // 1. Progress Ring (Left Side)
                SizedBox(
                  width: 140, height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return CustomPaint(
                            size: const Size(140, 140),
                            painter: ArcProgressPainter(
                              progress: value,
                              backgroundColor: Colors.white.withAlpha(26),
                              color: const Color(0xFF00E5FF),
                              strokeWidth: 12, // Slightly thinner ring
                            ),
                          );
                        },
                      ),
                      
                      // Icon inside ring instead of full stats
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_walk, color: Colors.white, size: 36),
                          Text(
                            '$percentage%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                
                const SizedBox(width: 24),
                
                // 2. Stats Column (Right Side)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Steps Count
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: steps),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            NumberFormat('#,###').format(value),
                            style: const TextStyle(
                              fontSize: 36, // Smaller than 48, but still bold
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          );
                        },
                      ),
                      Row(
                        children: [
                          const Text(
                            'steps today',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _showExplainer(context),
                            child: const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Goal & Adjust Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Goal',
                                  style: TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                Text(
                                  NumberFormat('#,###').format(goal),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Compact Adjust Button
                          Semantics(
                            label: 'Adjust Daily Goal',
                            button: true,
                            child: Material(
                              color: Colors.white.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: onAdjustGoal,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Keeping the helper class for compilation safety in isolated edits
class NumberFormat {
  final String pattern;
  NumberFormat(this.pattern);
  String format(int number) {
     return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}

class ArcProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color color;
  final double strokeWidth;

  ArcProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Draw full circle for background
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw Progress Arc (Starts from top -90deg)
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Tween is 0..1. Map to 0..2*pi
    // We want a full ring or just the arc? 
    // The previous design was a partial arc (270 deg). 
    // Compact Horizontal designs often look good with full circular progress.
    // I will switch to a top-start full circle progress for cleaner look.
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at top
      2 * math.pi * progress, // Full circle range
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.backgroundColor != backgroundColor;
  }
}
