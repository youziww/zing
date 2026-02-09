/// Represents a single review event in the log.
class ReviewLog {
  final int id; // timestamp in ms
  final int cardId;
  final int ease; // 1=again, 2=hard, 3=good, 4=easy
  final int interval; // new interval (positive=days, negative=seconds)
  final int lastInterval;
  final int factor; // new ease factor
  final int time; // review time in ms
  final int type; // 0=learn, 1=review, 2=relearn, 3=filtered

  ReviewLog({
    required this.id,
    required this.cardId,
    required this.ease,
    required this.interval,
    required this.lastInterval,
    required this.factor,
    required this.time,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cid': cardId,
      'ease': ease,
      'ivl': interval,
      'lastIvl': lastInterval,
      'factor': factor,
      'time': time,
      'type': type,
    };
  }

  factory ReviewLog.fromMap(Map<String, dynamic> map) {
    return ReviewLog(
      id: map['id'] as int,
      cardId: map['cid'] as int,
      ease: map['ease'] as int,
      interval: map['ivl'] as int? ?? 0,
      lastInterval: map['lastIvl'] as int? ?? 0,
      factor: map['factor'] as int? ?? 0,
      time: map['time'] as int? ?? 0,
      type: map['type'] as int? ?? 0,
    );
  }
}
