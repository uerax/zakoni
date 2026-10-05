import 'package:flutter/material.dart';

/// 时间轴微调步进器组件 (-1s, -0.5s, 输入框, +0.5s, +1s, 双击归零)
class DanmakuOffsetStepper extends StatefulWidget {
  const DanmakuOffsetStepper({
    super.key,
    required this.offsetMs,
    required this.onChanged,
    required this.onReset,
    this.label,
    this.subLabel,
    required this.primaryColor,
  });

  /// 当前偏移毫秒数
  final int offsetMs;

  /// 偏移变更回调 (毫秒)
  final ValueChanged<int> onChanged;

  /// 重置为 0 回调
  final VoidCallback onReset;

  final String? label;
  final String? subLabel;
  final Color primaryColor;

  @override
  State<DanmakuOffsetStepper> createState() => _DanmakuOffsetStepperState();
}

class _DanmakuOffsetStepperState extends State<DanmakuOffsetStepper> {
  bool _editing = false;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: _formatSec(widget.offsetMs));
  }

  @override
  void didUpdateWidget(covariant DanmakuOffsetStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offsetMs != widget.offsetMs && !_editing) {
      _editController.text = _formatSec(widget.offsetMs);
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  String _formatSec(int ms) {
    final sec = ms / 1000.0;
    return sec.toStringAsFixed(1);
  }

  String _formatDisplay(int ms) {
    if (ms == 0) return '0.0s';
    final sec = ms / 1000.0;
    return sec > 0 ? '+${sec.toStringAsFixed(1)}s' : '${sec.toStringAsFixed(1)}s';
  }

  void _commitInput() {
    final parsed = double.tryParse(_editController.text.trim());
    if (parsed != null) {
      final ms = (parsed * 1000).round();
      widget.onChanged(ms);
    } else {
      _editController.text = _formatSec(widget.offsetMs);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasShift = widget.offsetMs != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.subLabel != null)
                Text(
                  widget.subLabel!,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              // 快退 1s
              _buildStepButton(
                label: '-1s',
                onTap: () => widget.onChanged(widget.offsetMs - 1000),
              ),
              const SizedBox(width: 4),
              // 微退 0.5s
              _buildStepButton(
                label: '-0.5s',
                onTap: () => widget.onChanged(widget.offsetMs - 500),
              ),
              const SizedBox(width: 4),

              // 中间显示 / 点击输入 / 双击归零
              Expanded(
                child: _editing
                    ? SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _editController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: widget.primaryColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: widget.primaryColor),
                            ),
                          ),
                          onSubmitted: (_) => _commitInput(),
                          onTapOutside: (_) => _commitInput(),
                        ),
                      )
                    : Tooltip(
                        message: '点击手动输入，双击重置为 0.0s',
                        child: InkWell(
                          onTap: () {
                            _editController.text = _formatSec(widget.offsetMs);
                            setState(() => _editing = true);
                          },
                          onDoubleTap: widget.onReset,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: hasShift
                                  ? widget.primaryColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: hasShift
                                    ? widget.primaryColor.withValues(alpha: 0.4)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              _formatDisplay(widget.offsetMs),
                              style: TextStyle(
                                color: hasShift ? widget.primaryColor : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(width: 4),
              // 微进 0.5s
              _buildStepButton(
                label: '+0.5s',
                onTap: () => widget.onChanged(widget.offsetMs + 500),
              ),
              const SizedBox(width: 4),
              // 快进 1s
              _buildStepButton(
                label: '+1s',
                onTap: () => widget.onChanged(widget.offsetMs + 1000),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
