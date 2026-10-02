const String bangumiImageHostBangumi = 'lain.bgm.tv';
const String bangumiImageHostMirror = 'bgmimg.anibt.net';
const String defaultBangumiImageHost = bangumiImageHostMirror;
const String officialBangumiImageHost = bangumiImageHostBangumi;

final Set<String> _rewritableImageHosts = {
  bangumiImageHostBangumi,
  bangumiImageHostMirror,
  'bgm.tv',
  'www.bgm.tv',
  'bgmmi.anibt.net',
};

String currentBangumiImageHost = defaultBangumiImageHost;

void setBangumiImageHost(String host) {
  final h = host.trim().toLowerCase();
  if (h.contains('lain') || h.contains('official') || h.contains('direct')) {
    currentBangumiImageHost = bangumiImageHostBangumi;
  } else if (h.contains('bgmimg') || h.contains('mirror') || h.contains('proxy')) {
    currentBangumiImageHost = bangumiImageHostMirror;
  } else {
    currentBangumiImageHost = h
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .split('/')
        .first;
  }
}

/// 按照 animaku 标准实现：将已知 Bangumi 图片 Host 改写为当前源或指定源，并强制使用 HTTPS
String bangumiImageUrl(String url, {String? overrideHost}) {
  final src = url.trim();
  if (src.isEmpty) return '';

  final match = RegExp(r'^(?:https?:)?//([^/?#]+)(.*)$', caseSensitive: false).firstMatch(src);
  if (match == null) return src;

  final host = match.group(1)!.toLowerCase();
  final pathAndQuery = match.group(2) ?? '';
  final targetHost = overrideHost ?? currentBangumiImageHost;

  if (host == targetHost || !_rewritableImageHosts.contains(host)) {
    return _rewritableImageHosts.contains(host) ? 'https://$host$pathAndQuery' : src;
  }

  return 'https://$targetHost$pathAndQuery';
}

/// 优化 Bangumi 封面图（完全对齐 animaku 规范）：
/// 1. 自动切换为指定的图床 Host（默认 Anycast 镜像，可选官方直连）
/// 2. 对于原始超大封面 (/pic/cover/l/...)，自动挂接 /r/{maxEdge}/pic/ 动态裁剪，将体积从 2MB 降至 20KB 左右
/// 3. 已经缩略的路径（如 /pic/cover/c/, /pic/cover/m/）不重复添加 /r/ 避免 400 错误
String preferResizedCover(
  String url, {
  int maxEdge = 400,
  String? imageHost,
}) {
  final src = url.trim();
  if (src.isEmpty) return '';

  // 1. 如果已经带有 /r/{size}/ 路径，仅替换 host
  if (RegExp(r'/r/\d+/').hasMatch(src)) {
    return bangumiImageUrl(src, overrideHost: imageHost);
  }

  // 2. 如果已经是预缩略规格 (c=common, m=medium, s=small, g=grid)，仅替换 host
  if (RegExp(r'/(?:cover|user|icon)/[cmsg]/', caseSensitive: false).hasMatch(src)) {
    return bangumiImageUrl(src, overrideHost: imageHost);
  }

  // 3. 原始大图通过 /r/{maxEdge}/pic/ 动态裁剪
  final resized = src.replaceFirstMapped(
    RegExp(
      r'^(https?://(?:lain\.)?bgm\.tv|https?://bgmimg\.anibt\.net|https?://bgmmi\.anibt\.net)/pic/',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}/r/$maxEdge/pic/',
  );

  return bangumiImageUrl(resized, overrideHost: imageHost);
}

/// 为图片生成协议与域名无关的通用磁盘缓存 Key：
/// 剥离不同图床 Host（lain.bgm.tv / bgmimg.anibt.net 等）与前缀协议差异，
/// 使得用户在切换镜像源或官方源时，本地磁盘已下载的图片缓存能够 100% 复用命中。
String getBangumiImageCacheKey(String url) {
  final src = url.trim();
  if (src.isEmpty) return '';

  // 匹配已知 Bangumi 图床与镜像的相对路径
  final match = RegExp(
    r'^(?:https?:)?//[^/?#]+(/(?:r/\d+/)?pic/.*)$',
    caseSensitive: false,
  ).firstMatch(src);

  if (match != null) {
    return 'bgm_img:${match.group(1)}';
  }

  // 非标准路径则降级使用去除协议的路径
  return src.replaceFirst(RegExp(r'^https?:', caseSensitive: false), '');
}
