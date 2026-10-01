const String defaultBangumiImageHost = 'bgmimg.anibt.net';
const String officialBangumiImageHost = 'lain.bgm.tv';

String currentBangumiImageHost = defaultBangumiImageHost;

void setBangumiImageHost(String host) {
  currentBangumiImageHost = host;
}

final _imageHostRegex = RegExp(
  r'^(https?:)?//(lain\.bgm\.tv|bgmimg\.anibt\.net|bgm\.tv|www\.bgm\.tv|bgmmi\.anibt\.net)',
  caseSensitive: false,
);

/// 优化 Bangumi 封面图：
/// 1. 自动切换为指定的图床 Host（默认 Anycast 镜像，可选官方）
/// 2. 对于原始超大封面 (/pic/cover/l/...)，自动挂接 /r/{maxEdge}/pic/ 动态裁剪，将体积从 2MB 降至 20KB 左右
/// 3. 已经缩略的路径（如 /pic/cover/c/, /pic/cover/m/）不重复添加 /r/ 避免 400 错误
String preferResizedCover(
  String url, {
  int maxEdge = 400,
  String? imageHost,
}) {
  final targetHost = imageHost ?? currentBangumiImageHost;
  final src = url.trim();
  if (src.isEmpty) return '';

  // 1. 如果已经带有 /r/{size}/ 路径，仅替换 host
  if (RegExp(r'/r/\d+/').hasMatch(src)) {
    return _replaceHost(src, targetHost);
  }

  // 2. 如果已经是预缩略规格 (c=common, m=medium, s=small, g=grid)，仅替换 host
  if (RegExp(r'/(?:cover|user|icon)/[cmsg]/', caseSensitive: false).hasMatch(src)) {
    return _replaceHost(src, targetHost);
  }

  // 3. 原始大图通过 /r/{maxEdge}/pic/ 动态裁剪
  final resized = src.replaceFirstMapped(
    RegExp(
      r'^(https?:)?//(?:lain\.)?bgm\.tv/pic/|^(https?:)?//bgmimg\.anibt\.net/pic/|^(https?:)?//bgmmi\.anibt\.net/pic/',
      caseSensitive: false,
    ),
    (m) => 'https://$targetHost/r/$maxEdge/pic/',
  );

  return _replaceHost(resized, targetHost);
}

String _replaceHost(String url, String targetHost) {
  if (url.startsWith('//')) {
    return 'https:$url'.replaceFirst(_imageHostRegex, 'https://$targetHost');
  }
  if (!url.startsWith('http')) {
    return url;
  }
  return url.replaceFirst(_imageHostRegex, 'https://$targetHost');
}
