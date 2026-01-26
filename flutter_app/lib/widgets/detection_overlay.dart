import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../models/detection.dart';

/// Overlay widget to display detection bounding boxes
class DetectionOverlay extends StatelessWidget {
  final List<Detection> detections;
  final List<RiskAssessment> risks;
  final Size previewSize;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.risks,
    required this.previewSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / previewSize.width;
        final scaleY = constraints.maxHeight / previewSize.height;

        return Stack(
          children: risks.map((risk) {
            final bbox = risk.detection.boundingBox;
            
            return Positioned(
              left: bbox.left * scaleX,
              top: bbox.top * scaleY,
              width: bbox.width * scaleX,
              height: bbox.height * scaleY,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _getRiskColor(risk.level),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getRiskColor(risk.level),
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      '${risk.detection.className} ${(risk.detection.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Color _getRiskColor(RiskLevel level) {
    return switch (level) {
      RiskLevel.critical => Colors.red,
      RiskLevel.high => Colors.orange,
      RiskLevel.medium => Colors.amber,
      RiskLevel.low => Colors.green,
      RiskLevel.safe => Colors.blue,
    };
  }
}
