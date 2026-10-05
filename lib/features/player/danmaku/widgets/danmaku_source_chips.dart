import 'package:flutter/material.dart';
import '../models/danmaku_pool_models.dart';

/// 底部弹幕源池状态栏与快捷开关 Chips 组件 (1:1 对齐 animaku SourcesFooter)
class DanmakuSourceChipsBar extends StatelessWidget {
  const DanmakuSourceChipsBar({
    super.key,
    required this.chips,
    required this.onToggleSource,
    required this.primaryColor,
  });

  final List<DanmakuSourceChip> chips;
  final ValueChanged<DanmakuPoolId> onToggleSource;
  final Color primaryColor;

  Color _getSourceColor(DanmakuPoolId id) {
    return switch (id) {
      DanmakuPoolId.dandan => const Color(0xFF10B981), // Emerald
      DanmakuPoolId.bilibiliAuto => const Color(0xFFEC4899), // Pink
      DanmakuPoolId.bilibiliManual => const Color(0xFFA855F7), // Purple
      DanmakuPoolId.upload => const Color(0xFF0EA5E9), // Sky
    };
  }

  @override
  Widget build(BuildContext context) {
    final loaded = chips.where((c) => c.loaded).toList();
    if (loaded.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(color: Color(0x22FFFFFF), height: 1, thickness: 0.5),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '弹幕源池',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '点击徽章可独立开/关',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: loaded.map((chip) {
                    final color = _getSourceColor(chip.id);
                    final isEnabled = chip.enabled;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => onToggleSource(chip.id),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? color.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isEnabled
                                  ? color.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chip.label,
                                style: TextStyle(
                                  color: isEnabled ? color : Colors.white38,
                                  fontSize: 10.5,
                                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isEnabled ? color : Colors.white24,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  chip.count.toString(),
                                  style: TextStyle(
                                    color: isEnabled ? Colors.white : Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
