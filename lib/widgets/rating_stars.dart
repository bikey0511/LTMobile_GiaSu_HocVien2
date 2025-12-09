import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final int count;
  final Color color;

  const RatingStars({super.key, required this.rating, this.count = 0, this.color = const Color(0xFFFFC107)});

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < full) return Icon(Icons.star, color: color, size: 16);
          if (i == full && half) return Icon(Icons.star_half, color: color, size: 16);
          return Icon(Icons.star_border, color: color, size: 16);
        }),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Text('($count)', style: Theme.of(context).textTheme.bodySmall),
        ]
      ],
    );
  }
}

