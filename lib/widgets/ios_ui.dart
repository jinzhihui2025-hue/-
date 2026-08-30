// 共享 iOS 风格组件与常量
import 'package:flutter/cupertino.dart';

const kIosBlue = Color(0xFF007AFF);
const kIosGreen = Color(0xFF34C759);
const kIosLabel = Color(0xFF1C1C1E);
const kIosSecondary = Color(0xFF8E8E93);
const kIosSeparator = Color(0xFFE5E5EA);
const kIosBg = Color(0xFFF2F2F7);
const kIosRed = Color(0xFFFF3B30);

/// 白色圆角分组（iOS 设置风格）
class IosGroup extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const IosGroup(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: padding,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// 细分隔线
class IosDivider extends StatelessWidget {
  final double leftInset;
  const IosDivider({super.key, this.leftInset = 16});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: EdgeInsets.only(left: leftInset),
      color: kIosSeparator,
    );
  }
}

/// 纵向分隔线（统计栏用）
class IosVDivider extends StatelessWidget {
  final double height;
  const IosVDivider({super.key, this.height = 30});
  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: height, color: kIosSeparator);
  }
}

/// 分组区块标题（iOS section header）
class IosSectionHeader extends StatelessWidget {
  final String text;
  const IosSectionHeader(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: kIosSecondary)),
    );
  }
}
