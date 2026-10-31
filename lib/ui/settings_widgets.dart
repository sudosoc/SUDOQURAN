import 'package:flutter/material.dart';

import 'glass.dart';

class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  const SectionCard({super.key, required this.icon, required this.title, this.subtitle, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(
        radius: 26,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.gold, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(color: AppColors.muted, fontSize: 15)),
                ]),
              ),
              if (trailing != null) trailing!,
            ]),
            if (children.isNotEmpty) const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const ToggleRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 14, color: AppColors.muted)),
          ]),
        ),
        Transform.scale(
          scale: 1.25,
          child: Switch(value: value, onChanged: onChanged, activeColor: AppColors.bg0, activeTrackColor: AppColors.gold),
        ),
      ]),
    );
  }
}

/// Row of big selectable chips.
class ChoiceRow<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const ChoiceRow({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (v, label) in options)
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: v == value ? AppColors.gold.withOpacity(0.22) : Colors.white.withOpacity(0.05),
                border: Border.all(color: v == value ? AppColors.gold : Colors.white24, width: v == value ? 2 : 1),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 17, fontWeight: v == value ? FontWeight.w800 : FontWeight.w500)),
            ),
          ),
      ],
    );
  }
}

class SliderRow extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) label;
  final ValueChanged<double> onChanged;
  const SliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 170, child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      Expanded(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ),
      SizedBox(width: 90, child: Text(label(value), style: TextStyle(fontSize: 17, color: AppColors.gold))),
    ]);
  }
}
