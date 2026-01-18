import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RecognitionState {
  final double progress;
  final String status;
  RecognitionState(this.progress, this.status);
}

class RecognitionController extends ValueNotifier<RecognitionState> {
  RecognitionController() : super(RecognitionState(0.0, '准备中...'));

  Timer? _simulationTimer;
  final Random _random = Random();
  double _currentProcessingProgress = 0.4;

  void setUploadProgress(double p) {
    _cancelSimulation();
    // Upload phase maps to 0.0 -> 0.4
    // p is 0.0 to 1.0 from Dio
    final scaled = p * 0.4;
    // Don't go backwards if we already started processing
    if (scaled < value.progress && value.progress > 0.4) return;
    
    value = RecognitionState(
      scaled,
      '正在上传图片... ${(p * 100).toInt()}%',
    );
  }

  void startProcessing() {
    _cancelSimulation();
    _currentProcessingProgress = 0.4;
    value = RecognitionState(0.4, 'AI 正在识别内容...');

    // Simulate processing: 0.4 -> 0.95 over time
    // Use a random walk approach
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (_currentProcessingProgress >= 0.95) return;

      // Random speed factor
      // Base speed decreases as we get closer to 0.95 (Zeno's paradox)
      final remaining = 0.95 - _currentProcessingProgress;
      final noise = 0.02 + _random.nextDouble() * 0.05; 
      final step = remaining * noise;

      _currentProcessingProgress += step;
      if (_currentProcessingProgress > 0.95) _currentProcessingProgress = 0.95;

      String text = 'AI 正在识别内容...';
      if (_currentProcessingProgress > 0.6) text = '正在分析数据...';
      if (_currentProcessingProgress > 0.8) text = '正在整理结果...';

      value = RecognitionState(_currentProcessingProgress, text);
    });
  }

  void complete() {
    _cancelSimulation();
    value = RecognitionState(1.0, '处理完成');
  }

  void reset() {
    _cancelSimulation();
    value = RecognitionState(0.0, '准备中...');
  }

  void _cancelSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    _cancelSimulation();
    super.dispose();
  }
}

class RecognitionLoading extends StatefulWidget {
  final RecognitionController controller;
  
  const RecognitionLoading({
    super.key,
    required this.controller,
  });

  @override
  State<RecognitionLoading> createState() => _RecognitionLoadingState();
}

class _RecognitionLoadingState extends State<RecognitionLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ValueListenableBuilder<RecognitionState>(
            valueListenable: widget.controller,
            builder: (context, state, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bouncing animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -8 * sin(_controller.value * pi)),
                        child: Transform.scale(
                          scale: 1.0 + 0.1 * sin(_controller.value * pi),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFE8F3FF), Color(0xFFF0F8FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 40,
                        color: Color(0xFF0052D9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: state.progress,
                      minHeight: 12,
                      backgroundColor: const Color(0xFFF2F3F5),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFF0052D9)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Text and Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.status,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4B5B76),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(state.progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0052D9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
