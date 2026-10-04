/// 弹幕文本归一化工具类
/// 用于同屏弹幕相似度比对、重复合并检索与屏蔽词匹配
abstract final class DanmakuTextNormalizer {
  static final RegExp _repeatedCharsRegex = RegExp(r'(.)\1{2,}');
  static final RegExp _trimPunctuationRegex = RegExp(
    r'^[\s,.;:!?~—_=+~～！，。？：、]+|[\s,.;:!?~—_=+~～！，。？：、]+$',
  );

  /// 将弹幕文本归一化
  /// 1. 全角 ASCII 符号转半角
  /// 2. 连续 3 个及以上相同字符折叠为 2 个 (例如: "233333" -> "233", "哈哈哈哈" -> "哈哈")
  /// 3. 去除首尾装饰性标点
  /// 4. 转为小写修剪空格
  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var text = raw.trim().toLowerCase();
    if (text.isEmpty) return '';

    // 全角转半角
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code == 0x3000) {
        // 全角空格 -> 半角空格
        buffer.writeCharCode(0x20);
      } else if (code >= 0xFF01 && code <= 0xFF5E) {
        // 全角字符 (! ~ ~)
        buffer.writeCharCode(code - 0xFEE0);
      } else {
        buffer.writeCharCode(code);
      }
    }
    text = buffer.toString();

    // 连续重复字符折叠 (3个以上折叠为2个)
    text = text.replaceAllMapped(_repeatedCharsRegex, (match) {
      final char = match.group(1)!;
      return '$char$char';
    });

    // 剥离首尾多余标点
    final stripped = text.replaceAll(_trimPunctuationRegex, '');
    return stripped.isNotEmpty ? stripped : text;
  }
}
