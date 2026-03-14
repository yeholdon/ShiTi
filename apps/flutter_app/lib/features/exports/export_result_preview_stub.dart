import 'package:flutter/material.dart';
import '../../core/theme/telegram_palette.dart';

class ExportResultPreview extends StatelessWidget {
  const ExportResultPreview({
    super.key,
    required this.uri,
  });

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TelegramPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '结果预览',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '当前平台先提供结果入口和地址管理。Web 端会继续优先支持内嵌预览，其余平台后续再补本地查看能力。',
            style: TextStyle(
              height: 1.6,
              color: TelegramPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
