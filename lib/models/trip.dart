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
  final String? startLocation; // e.g. "San Francisco" or origin city
  final String? endLocation; // e.g. "San Francisco" or return city
  final String? notes;
  final List<String> links;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastModifiedAt;
  final String? lastModifiedSource; // 'ui' or 'mcp'

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
    this.startLocation,
    this.endLocation,
    this.notes,
    this.links = const [],
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastModifiedAt,
    this.lastModifiedSource,
  });

  bool get isModifiedByMcp => lastModifiedSource?.toLowerCase() == 'mcp';
  bool get isModifiedByUi => lastModifiedSource == null || lastModifiedSource?.toLowerCase() == 'ui';

  /// Total days in the trip (inclusive of start and end dates)
  int get daysCount {
    final sUtc = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final eUtc = DateTime.utc(endDate.year, endDate.month, endDate.day);
    return eUtc.difference(sUtc).inDays + 1;
  }

  /// Generates a list of all normalized dates (one for each consecutive day)
  List<DateTime> get daysList {
    final list = <DateTime>[];
    for (int i = 0; i < daysCount; i++) {
      list.add(DateTime(startDate.year, startDate.month, startDate.day + i));
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
    String? startLocation,
    String? endLocation,
    String? notes,
    List<String>? links,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModifiedAt,
    String? lastModifiedSource,
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
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      notes: notes ?? this.notes,
      links: links ?? this.links,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedSource: lastModifiedSource ?? this.lastModifiedSource,
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
      'memberIds': <String>{ownerId, ...members.keys}.toList(),
      'dayLocations': dayLocations.map((k, v) => MapEntry(k, List<dynamic>.from(v))),
      if (startLocation != null) 'startLocation': startLocation,
      if (endLocation != null) 'endLocation': endLocation,
      if (notes != null) 'notes': notes,
      'links': links,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (lastModifiedAt != null) 'lastModifiedAt': lastModifiedAt!.toIso8601String(),
      if (lastModifiedSource != null) 'lastModifiedSource': lastModifiedSource,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'] as Map<String, dynamic>? ?? {};
    final parsedMembers = rawMembers.map(
      (key, value) => MapEntry(
        key,
        MemberRole.fromString(value as String?),
      ),
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
      startLocation: map['startLocation'] as String?,
      endLocation: map['endLocation'] as String?,
      notes: map['notes'] as String?,
      links: (map['links'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      attachments: (map['attachments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      lastModifiedAt: map['lastModifiedAt'] != null
          ? DateTime.tryParse(map['lastModifiedAt'].toString())
          : (map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null),
      lastModifiedSource: map['lastModifiedSource'] as String?,
    );
  }
}
