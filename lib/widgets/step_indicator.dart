import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A3C6E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Step circles + connectors
          Row(
            children: List.generate(totalSteps * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final stepIndex = (i ~/ 2) + 1;
                final isCompleted = stepIndex < currentStep;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? Colors.amber
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                );
              } else {
                final step = i ~/ 2 + 1;
                final isActive = step == currentStep;
                final isCompleted = step < currentStep;
                return _StepCircle(
                  step: step,
                  isActive: isActive,
                  isCompleted: isCompleted,
                );
              }
            }),
          ),
          const SizedBox(height: 8),
          // Step label
          Text(
            'Step $currentStep of $totalSteps: ${stepTitles[currentStep - 1]}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int step;
  final bool isActive;
  final bool isCompleted;

  const _StepCircle({
    required this.step,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 36 : 28,
      height: isActive ? 36 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? Colors.amber
            : isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.2),
        border: isActive
            ? Border.all(color: Colors.amber, width: 3)
            : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, size: 16, color: Color(0xFF1A3C6E))
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: isActive ? 14 : 12,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? const Color(0xFF1A3C6E)
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
      ),
    );
  }
}
