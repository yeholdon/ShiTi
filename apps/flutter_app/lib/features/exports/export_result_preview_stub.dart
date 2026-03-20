import 'package:flutter/material.dart';

import '../shared/workspace_shell.dart';

class ExportResultPreview extends StatelessWidget {
  const ExportResultPreview({
    super.key,
    required this.uri,
  });

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return const WorkspaceMessageBanner.info(
      title: '结果预览',
      message: '当前平台提供结果入口和地址管理，你可以继续使用“浏览器打开”查看导出文件。',
    );
  }
}
