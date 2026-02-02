import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class ErrorHandler {
  static void show(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final (title, reason, solution) = _parseError(error);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection('问题描述', reason),
              const SizedBox(height: 12),
              _buildSection('建议方案', solution, isSolution: true),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TDButton(
                    text: '关闭',
                    type: TDButtonType.text,
                    theme: TDButtonTheme.defaultTheme,
                    onTap: () => Navigator.pop(ctx),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 12),
                    TDButton(
                      text: '重试',
                      type: TDButtonType.fill,
                      theme: TDButtonTheme.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        onRetry();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSection(
    String label,
    String content, {
    bool isSolution = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: isSolution ? Colors.green.shade700 : Colors.black87,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  static (String, String, String) _parseError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ('网络连接超时', '服务器响应时间过长，可能是网络不稳定。', '请检查您的网络连接，或稍后重试。');
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          String detail = '服务器返回错误';
          if (data is Map && data['detail'] != null) {
            detail = data['detail'].toString();
          } else if (data is String) {
            // 尝试截取部分错误信息
            detail = data.length > 50 ? '${data.substring(0, 50)}...' : data;
          }

          if (statusCode == 413) {
            return ('文件过大', '上传的图片或文件超过了服务器限制。', '请尝试压缩图片或选择较小的文件。');
          } else if (statusCode == 429) {
            return ('请求过于频繁', '您的操作太快了，触发了频率限制。', '请稍等片刻后再试。');
          }

          return ('服务请求失败 ($statusCode)', detail, '请联系管理员或稍后重试。');
        case DioExceptionType.connectionError:
          return ('网络连接错误', '无法连接到服务器，可能是网络中断或服务器维护。', '请检查网络设置，确保设备已联网。');
        default:
          return ('网络请求异常', error.message ?? '未知网络错误', '请检查网络并重试。');
      }
    }

    // 处理普通异常
    final msg = error.toString();
    if (msg.contains('format')) {
      return ('格式错误', '数据格式不符合要求。', '请检查输入内容或上传的文件格式。');
    }

    return (
      '发生错误',
      msg.length > 100 ? '${msg.substring(0, 100)}...' : msg,
      '如持续失败，请截图联系技术支持。',
    );
  }
}
