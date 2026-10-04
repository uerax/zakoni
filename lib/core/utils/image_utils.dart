/// Bangumi 图片静态资源处理与 Host 映射工具
///
/// 【架构与特殊处理说明】：
/// 1. 本项目为客户端直连架构，不存在独立部署的“图片 API 微服务”，图片均为公开静态资源文件。
/// 2. 之所以需要 [currentBangumiImageHost] 和 [bangumiImageUrl]：
///    - Bangumi 官方接口返回的数据中写死了明文 HTTP 地址（如 `http://lain.bgm.tv/pic/...`），
///      在现代移动端平台上会因明文网络安全策略被拦截，且在国内直连官方图床常被严重阻断或限速。
///    - 因此客户端在展示前，需将 Host 改写为当前激活线路的图片域名，并强制升级为 HTTPS。
/// 3. 关于图片线路与后续自定义线路：
///    - 公共镜像（anibt）因配置了 30 天静态 CDN 缓存策略，保留了专用的图片域名 `bgmimg.anibt.net`；
///    - 对于用户自建的反代，通常全量反代或同源代理，图片 Host 默认直接复用 API 域名即可，无需单独配置。
/// 4. 磁盘缓存复用保证：
///    - [getBangumiImageCacheKey] 会剥离 Host，提取通用路径（如 `bgm_img:/pic/...`）。
///    - 用户在不同线路之间切换时，本地磁盘已缓存的图片仍能 100% 命中，免去重复下载流量。
String currentBangumiImageHost = 'bgmimg.anibt.net';

/// 动态更新当前用于替换 Bangumi 图片资产的目标 Host
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

/// 纯粹的通用 Host 替换与 HTTPS 升级（零硬编码域名白名单，零动态裁剪拼接）：
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
