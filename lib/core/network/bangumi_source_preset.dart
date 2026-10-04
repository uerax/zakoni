/// Bangumi 数据源预设枚举
///
/// 【架构与特殊处理说明】：
/// 1. [apiBase] 为客户端发起 API 请求（如番剧日历、条目详情、搜索）的基础路径。
/// 2. [imageHost] 为该线路配套的图片资产 CDN 域名：
///    - Bangumi 接口数据默认携带明文 `http://lain.bgm.tv/pic/...`，易被移动平台拦截且国内直连不稳定；
///    - 客户端在展示图片时会将 Host 替换为该线路的 [imageHost] 并升级为 HTTPS；
///    - 本项目无独立“图片 API”，图片均为静态资源下载；未来扩展用户自定义线路时，
///      图片 Host 默认直接取反代 URL 的域名即可，无需也不能强制要求用户分别配置两个端点。
enum BangumiSourcePreset {
  mirror(
    'https://bgmapi.anibt.net',
    'bgmimg.anibt.net',
    '镜像加速线路 (推荐，Anycast CDN 国内直连)',
  ),
  official(
    'https://api.bgm.tv',
    'lain.bgm.tv',
    '官方直连线路 (海外用户推荐)',
  );

  final String apiBase;
  final String imageHost;
  final String label;

  const BangumiSourcePreset(this.apiBase, this.imageHost, this.label);
}

