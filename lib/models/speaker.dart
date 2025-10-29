/// 화자 정보 모델
class Speaker {
  final String id;
  final String name;
  final String color; // UI에서 화자 구분용 색상

  Speaker({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Speaker.fromMap(Map<String, dynamic> map) {
    return Speaker(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
    );
  }

  Speaker copyWith({
    String? id,
    String? name,
    String? color,
  }) {
    return Speaker(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
