import 'package:flutter/material.dart';

/// 与 Web 看护端一致的暖色表单视觉
abstract final class CareFormTheme {
  static const Color scaffoldBg = Color(0xFFFFF7EE);
  static const Color slate900 = Color(0xFF5C4A3D);
  static const Color slate700 = Color(0xFF6F5A4C);
  static const Color slate600 = Color(0xFF8B7A6E);
  static const Color slate500 = Color(0xFFA19084);
  static const Color slate200 = Color(0xFFFFDDBE);
  static const Color slate100 = Color(0xFFFFE9D6);
  static const Color slate50 = Color(0xFFFFFBF7);
  static const Color blue600 = Color(0xFFE8863D);
  static const Color blue100 = Color(0xFFFFD9BA);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);

  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: slate700,
    height: 1.25,
  );

  static const TextStyle hintSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: slate500,
    height: 1.35,
  );

  static BoxDecoration card() => BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCF8), Color(0xFFFFF3E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );

  static InputDecoration fieldDecoration({
    required String hint,
    int maxLines = 1,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: slate500.withValues(alpha: 0.85), fontSize: 15),
      filled: true,
      fillColor: const Color(0xFFFFFEFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: blue600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
    );
  }

  static ButtonStyle primaryButton({required bool enabled}) {
    return FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: enabled ? blue600 : slate100,
      foregroundColor: enabled ? Colors.white : slate500,
      disabledBackgroundColor: slate100,
      disabledForegroundColor: slate500,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  static Widget frequencyChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? blue600 : slate200, width: selected ? 1.5 : 1),
            color: selected ? blue600 : const Color(0xFFFFFEFC),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: blue100.withValues(alpha: 0.9),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : slate600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `DOSAGE_FORMS` 对齐（仅展示与写入备注，后端暂无独立剂型字段）
const List<({String value, String label})> kDosageForms = [
  (value: 'tablet', label: '片剂'),
  (value: 'capsule', label: '胶囊'),
  (value: 'liquid', label: '口服液'),
  (value: 'granule', label: '颗粒'),
  (value: 'other', label: '其他'),
];
