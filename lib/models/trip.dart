import 'member_role.dart';

class Trip {
  final String id;
  final String title;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String? coverImageUrl;
  final String ownerId;
  final String inviteCode; // e.g. "TYO-8821"
  final MemberRole defaultInviteRole; // Role assigned to users joining with inviteCode
  final Map<String, MemberRole> members; // userId -> MemberRole
  final Map<String, List<String>> dayLocations; // "YYYY-MM-DD" -> List of location names
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.coverImageUrl,
    required this.ownerId,
    required this.inviteCode,
    this.defaultInviteRole = MemberRole.editor,
    required this.members,
    this.dayLocations = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total days in the trip (inclusive of start and end dates)
  int get daysCount {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return e.difference(s).inDays + 1;
  }

  /// Generates a list of all normalized dates (one for each consecutive day)
  List<DateTime> get daysList {
    final list = <DateTime>[];
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    for (int i = 0; i < daysCount; i++) {
      list.add(start.add(Duration(days: i)));
    }
    return list;
  }

  static String dateToKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  List<String>? getCustomLocationsForDate(DateTime d) {
    final key = dateToKey(d);
    final locs = dayLocations[key];
    if (locs != null && locs.isNotEmpty) {
      return List<String>.unmodifiable(locs);
    }
    return null;
  }

  MemberRole? getRole(String userId) {
    if (userId == ownerId) return MemberRole.owner;
    return members[userId];
  }

  bool canUserEdit(String userId) {
    final role = getRole(userId);
    return role != null && role.canEdit;
  }

  Trip copyWith({
    String? id,
    String? title,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? coverImageUrl,
    String? ownerId,
    String? inviteCode,
    MemberRole? defaultInviteRole,
    Map<String, MemberRole>? members,
    Map<String, List<String>>? dayLocations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      ownerId: ownerId ?? this.ownerId,
      inviteCode: inviteCode ?? this.inviteCode,
      defaultInviteRole: defaultInviteRole ?? this.defaultInviteRole,
      members: members ?? this.members,
      dayLocations: dayLocations ?? this.dayLocations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'destination': destination,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'coverImageUrl': coverImageUrl,
      'ownerId': ownerId,
      'inviteCode': inviteCode,
      'defaultInviteRole': defaultInviteRole.toJson(),
      'members': members.map((key, value) => MapEntry(key, value.toJson())),
      'dayLocations': dayLocations.map((k, v) => MapEntry(k, List<dynamic>.from(v))),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'] as Map<String, dynamic>? ?? {};
    final parsedMembers = rawMembers.map(
      (key, value) => MapEntry(key, MemberRole.fromString(value as String?)),
    );

    final rawDayLocations = map['dayLocations'] as Map<String, dynamic>? ?? {};
    final parsedDayLocations = rawDayLocations.map(
      (key, value) => MapEntry(
        key,
        (value as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
      ),
    );

    return Trip(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      destination: map['destination'] as String? ?? '',
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      coverImageUrl: map['coverImageUrl'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      defaultInviteRole: MemberRole.fromString(map['defaultInviteRole'] as String?),
      members: parsedMembers,
      dayLocations: parsedDayLocations,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
