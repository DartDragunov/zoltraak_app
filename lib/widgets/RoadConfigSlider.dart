import 'package:flutter/material.dart';

class WaveformSlider extends StatelessWidget {
  final String label, hint, display;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;

  const WaveformSlider({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(color: color, fontSize: 12, height: 1.2)),
              if (hint.isNotEmpty)
                Text(hint,
                    style: const TextStyle(
                        color: Colors.white30, fontSize: 9, height: 1.1)),
            ],
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color.withOpacity(0.75),
              inactiveTrackColor: Colors.white12,
              thumbColor: color,
              overlayColor: color.withOpacity(0.12),
              trackHeight: 2,
            ),
            child:
                Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(display,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ),
      ],
    );
  }
}
