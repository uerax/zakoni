/// 自定义网络线路实体模型
class CustomNetworkRoute {
  final String id;
  final String name;
  final String url;

  const CustomNetworkRoute({
    required this.id,
    required this.name,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
      };

  factory CustomNetworkRoute.fromJson(Map<String, dynamic> json) {
    return CustomNetworkRoute(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomNetworkRoute &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CustomNetworkRoute(id: $id, name: $name, url: $url)';
}
