const String bangumiImageHostBangumi = 'lain.bgm.tv';
const String bangumiImageHostMirror = 'bgmimg.anibt.net';
const String defaultBangumiImageHost = bangumiImageHostMirror;
const String officialBangumiImageHost = bangumiImageHostBangumi;

String currentBangumiImageHost = defaultBangumiImageHost;

void setBangumiImageHost(String host) {
  final cleanHost = host
      .trim()
      .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
      .split('/')
      .first
      .toLowerCase();
  if (cleanHost.isNotEmpty) {
    currentBangumiImageHost = cleanHost;
  }
}

/// 纯粹的通用 Host 替换与 HTTPS 升级（方案 A：零硬编码域名白名单，零动态裁剪拼接）
/// 1. 任何带有 /pic/ 的 Bangumi 图片资产，直接替换为其在目标镜像/官方图床上的对应 Host
/// 2. 自动移除遗留的 /r/{size}/ 裁剪前缀，保证所有标准反代镜像均可 100% 直连原图
/// 3. 非图片或外部第三方地址原样返回
String bangumiImageUrl(String url, {String? overrideHost}) {
  final src = url.trim();
  if (src.isEmpty) return '';

  final uri = Uri.tryParse(src);
  if (uri == null) return src;

  final targetHost = overrideHost ?? currentBangumiImageHost;

  // 相对路径 (例如 /pic/cover/l/...)
  if (!uri.hasScheme && !src.startsWith('//')) {
    final cleanPath = src.startsWith('/') ? src : '/$src';
    final normalized = cleanPath.replaceFirst(RegExp(r'^/r/\d+/'), '/');
    return 'https://$targetHost$normalized';
  }

  // 只要路径包含 /pic/，一律纯净换 Host 直连原图
  if (uri.path.contains('/pic/')) {
    final cleanPath = uri.path.replaceFirst(RegExp(r'^/r/\d+/'), '/');
    return uri.replace(
      scheme: 'https',
      host: targetHost,
      port: null,
      path: cleanPath,
    ).toString();
  }

  return src;
}

/// 向后兼容：废除客户端拼装 /r/ 动态切片，直接统一委托给 bangumiImageUrl 原图直连
String preferResizedCover(
  String url, {
  int? maxEdge,
  String? imageHost,
}) =>
    bangumiImageUrl(url, overrideHost: imageHost);

/// 为图片生成协议与域名无关的通用磁盘缓存 Key：
/// 剥离不同图床 Host 与协议差异，提取标准资产路径（如 bgm_img:/pic/cover/l/... 或 bgm_img:/r/400/pic/...），
/// 使得用户在切换镜像源或官方源时，本地磁盘已下载的图片缓存能够 100% 复用命中。
String getBangumiImageCacheKey(String url) {
  final src = url.trim();
  if (src.isEmpty) return '';

  final uri = Uri.tryParse(src);
  if (uri != null && uri.path.contains('/pic/')) {
    final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    return 'bgm_img:$path';
  }

  return src.replaceFirst(RegExp(r'^https?:', caseSensitive: false), '');
}
