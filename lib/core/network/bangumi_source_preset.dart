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
