enum MemberRole {
  owner,
  editor,
  viewer;

  bool get canEdit => this == MemberRole.owner || this == MemberRole.editor;
  bool get isOwner => this == MemberRole.owner;

  String get displayName {
    switch (this) {
      case MemberRole.owner:
        return 'Owner';
      case MemberRole.editor:
        return 'Editor';
      case MemberRole.viewer:
        return 'Viewer';
    }
  }

  static MemberRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return MemberRole.owner;
      case 'editor':
        return MemberRole.editor;
      case 'viewer':
      default:
        return MemberRole.viewer;
    }
  }

  String toJson() => name;
}
