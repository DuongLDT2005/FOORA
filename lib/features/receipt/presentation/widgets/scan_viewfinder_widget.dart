import 'package:flutter/material.dart';

/// Interactive Viewfinder cutout with laser scanning beam and corner brackets.
/// Matches Stitch UI screen `Quét hóa đơn`
class ScanViewfinderWidget extends StatelessWidget {
  final Widget? bottomChild;

  const ScanViewfinderWidget({super.key, this.bottomChild});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final topSafe = MediaQuery.of(context).padding.top;
        final bottomSafe = MediaQuery.of(context).padding.bottom;

        // Kéo dài khung quét chiếm gần như toàn bộ màn hình
        final boxWidth = constraints.maxWidth * 0.92;
        // Bắt đầu từ dưới top controls (topSafe + 56) đến gần mép dưới (bottomSafe + 16)
        final availableHeight =
            constraints.maxHeight - (topSafe + 60) - (bottomSafe + 20);
        final boxHeight = availableHeight.clamp(
          200.0,
          constraints.maxHeight * 0.86,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            // Darkened outer mask around viewfinder
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.50),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    top: topSafe + 56,
                    left: (constraints.maxWidth - boxWidth) / 2,
                    child: Container(
                      width: boxWidth,
                      height: boxHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Viewfinder frame container with corner brackets
            Positioned(
              top: topSafe + 56,
              left: (constraints.maxWidth - boxWidth) / 2,
              child: SizedBox(
                width: boxWidth,
                height: boxHeight,
                child: Stack(
                  children: [
                    // Corner accents
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _buildCorner(isTop: true, isLeft: true),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildCorner(isTop: true, isLeft: false),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _buildCorner(isTop: false, isLeft: true),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildCorner(isTop: false, isLeft: false),
                    ),

                    // Instruction Pill Badge at the top inside viewfinder
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.center_focus_strong,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Căn chỉnh toàn bộ hóa đơn vào khung',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom child (e.g. shutter button) positioned inside the frame
                    if (bottomChild != null)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(child: bottomChild!),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    const size = 28.0;
    const thickness = 3.5;
    const radius = Radius.circular(16);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Colors.white, width: thickness)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.white, width: thickness)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Colors.white, width: thickness)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.white, width: thickness)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? radius : Radius.zero,
          topRight: isTop && !isLeft ? radius : Radius.zero,
          bottomLeft: !isTop && isLeft ? radius : Radius.zero,
          bottomRight: !isTop && !isLeft ? radius : Radius.zero,
        ),
      ),
    );
  }
}
