import 'package:flutter/material.dart';

class SlideToConfirm extends StatefulWidget {
  final VoidCallback onConfirm;

  const SlideToConfirm({super.key, required this.onConfirm});

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dragPosition = 0;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final buttonWidth = 60.0;
    final maxDrag = screenWidth - buttonWidth - 8;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              _confirmed
                  ? "Delivered!"
                  : "Slide to mark as delivered",
              style: TextStyle(
                color: Colors.white.withOpacity(_dragPosition / maxDrag > 0.5 ? 0.3 : 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            left: _dragPosition + 4,
            top: 4,
            child: GestureDetector(
              onHorizontalDragUpdate: _confirmed
                  ? null
                  : (details) {
                      setState(() {
                        _dragPosition += details.delta.dx;
                        if (_dragPosition < 0) _dragPosition = 0;
                        if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                      });
                    },
              onHorizontalDragEnd: _confirmed
                  ? null
                  : (details) {
                      if (_dragPosition > maxDrag * 0.8) {
                        setState(() {
                          _dragPosition = maxDrag;
                          _confirmed = true;
                        });
                        Future.delayed(const Duration(milliseconds: 300), () {
                          widget.onConfirm();
                        });
                      } else {
                        setState(() {
                          _dragPosition = 0;
                        });
                      }
                    },
              child: Container(
                width: buttonWidth,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _confirmed ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: Colors.red.shade700,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}