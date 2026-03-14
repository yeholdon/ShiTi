import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../../core/theme/telegram_palette.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class ExportResultPreview extends StatelessWidget {
  const ExportResultPreview({
    super.key,
    required this.uri,
  });

  final Uri uri;

  static final Set<String> _registeredViewTypes = <String>{};

  @override
  Widget build(BuildContext context) {
    final viewType = 'shiti-export-preview-${uri.toString().hashCode}';
    if (_registeredViewTypes.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final iframe = web.HTMLIFrameElement()
          ..src = uri.toString()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#ffffff';
        return iframe;
      });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TelegramPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TelegramPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '结果预览',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '当前在 Web 端直接内嵌展示结果文件。如果浏览器或服务器策略阻止内嵌，可以继续使用“浏览器打开”。',
            style: TextStyle(
              height: 1.6,
              color: TelegramPalette.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 520,
              child: HtmlElementView(viewType: viewType),
            ),
          ),
        ],
      ),
    );
  }
}
