import 'package:flutter/material.dart';

class ComparisonResultWidget extends StatefulWidget {
  final Map<String, dynamic> result;

  const ComparisonResultWidget({super.key, required this.result});

  @override
  State<ComparisonResultWidget> createState() => _ComparisonResultWidgetState();
}

class _ComparisonResultWidgetState extends State<ComparisonResultWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _progressController.forward();
    if (widget.result['match'] == true) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMatch = widget.result['match'] as bool;
    final double similarity = widget.result['similarity'] as double;
    final double distance = widget.result['distance'] as double;
    final double confidence = widget.result['confidence'] as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMatch ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatch ? Colors.green.shade200 : Colors.red.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMatch ? Colors.green : Colors.red).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Match status header
          ScaleTransition(
            scale: _pulseAnimation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMatch ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMatch ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isMatch ? 'FACE MATCH' : 'NO MATCH',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        isMatch ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Confidence meter
          _buildConfidenceMeter(confidence, isMatch),

          const SizedBox(height: 24),

          // Detailed metrics
          _buildMetricsGrid(similarity, distance, confidence),

          const SizedBox(height: 16),

          // Interpretation
          _buildInterpretation(isMatch, confidence),
        ],
      ),
    );
  }

  Widget _buildConfidenceMeter(double confidence, bool isMatch) {
    return Column(
      children: [
        Text(
          'Confidence Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),

        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    value: confidence * _progressAnimation.value,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMatch ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                final displayValue = confidence * _progressAnimation.value;
                return Text(
                  '${(displayValue * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        isMatch ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(
    double similarity,
    double distance,
    double confidence,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            'Detailed Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildMetricItem(
                'Similarity',
                similarity,
                Icons.tune,
                Colors.blue,
                isPercentage: true,
              ),
              const SizedBox(width: 16),
              _buildMetricItem(
                'Distance',
                distance,
                Icons.straighten,
                Colors.orange,
                decimals: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    double value,
    IconData icon,
    Color color, {
    bool isPercentage = false,
    int decimals = 2,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isPercentage
                  ? '${(value * 100).toStringAsFixed(1)}%'
                  : value.toStringAsFixed(decimals),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterpretation(bool isMatch, double confidence) {
    String message;
    IconData icon;
    Color color;

    if (isMatch) {
      if (confidence > 0.8) {
        message =
            'High confidence match. These faces likely belong to the same person.';
        icon = Icons.verified;
        color = Colors.green.shade600;
      } else {
        message =
            'Moderate confidence match. Faces are similar but verification recommended.';
        icon = Icons.info;
        color = Colors.amber.shade600;
      }
    } else {
      if (confidence < 0.3) {
        message =
            'Very low similarity. These faces belong to different people.';
        icon = Icons.block;
        color = Colors.red.shade600;
      } else {
        message =
            'Below threshold. Faces may have some similarities but are not the same person.';
        icon = Icons.warning;
        color = Colors.orange.shade600;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
