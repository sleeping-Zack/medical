class AdherencePoint {
  AdherencePoint({
    required this.date,
    required this.total,
    required this.taken,
    required this.rate,
  });

  final DateTime date;
  final int total;
  final int taken;
  final int rate;

  factory AdherencePoint.fromJson(Map<String, dynamic> json) {
    return AdherencePoint(
      date: DateTime.parse(json['date'] as String),
      total: (json['total'] as num?)?.toInt() ?? 0,
      taken: (json['taken'] as num?)?.toInt() ?? 0,
      rate: (json['rate'] as num?)?.toInt() ?? 0,
    );
  }
}
