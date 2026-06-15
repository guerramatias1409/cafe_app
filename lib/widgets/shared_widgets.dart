import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

// ── Section header ─────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.caramel,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.grey300),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
        Row(
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppTheme.brownDark,
                )),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ],
    ),
  );
}

// ── Price input ────────────────────────────────────────────────────────────────

class PriceField extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const PriceField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<PriceField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(PriceField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value.toString()) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label,
          style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
      const SizedBox(height: 6),
      TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(prefixText: '\$ '),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed != null) widget.onChanged(parsed);
        },
      ),
    ],
  );
}

// ── Number stepper ─────────────────────────────────────────────────────────────

class NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? label;

  const NumberStepper({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 4,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null) ...[
          Text(label!,
              style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
          const Spacer(),
        ],
        _Btn(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.brownDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Btn(
          icon: Icons.add,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _Btn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: enabled ? AppTheme.cream : AppTheme.grey100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled ? AppTheme.caramel : AppTheme.grey300,
        ),
      ),
      child: Icon(icon,
          size: 18,
          color: enabled ? AppTheme.brownMed : AppTheme.grey300),
    ),
  );
}
