import 'package:flutter/material.dart';

extension ColorExtensions on Color {
  Color withValues({
    int? alpha,
    int? red,
    int? green,
    int? blue,
  }) {
    return Color.fromARGB(
      alpha ?? this.alpha,
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
    );
  }
}
