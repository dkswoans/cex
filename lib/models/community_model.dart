class CommunityPostModel {
  const CommunityPostModel({
    required this.postId,
    required this.authorUserId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String postId;
  final String authorUserId;
  final String authorName;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CommunityPostModel.fromSupabase(Map<String, dynamic> map) {
    return CommunityPostModel(
      postId: map['id'] as String,
      authorUserId: map['author_user_id'] as String,
      authorName: map['author_name'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: _dateFromMap(map['created_at'])!,
      updatedAt: _dateFromMap(map['updated_at'])!,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': postId,
      'author_user_id': authorUserId,
      'author_name': authorName,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CommunityCommentModel {
  const CommunityCommentModel({
    required this.commentId,
    required this.postId,
    required this.authorUserId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String commentId;
  final String postId;
  final String authorUserId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory CommunityCommentModel.fromSupabase(Map<String, dynamic> map) {
    return CommunityCommentModel(
      commentId: map['id'] as String,
      postId: map['post_id'] as String,
      authorUserId: map['author_user_id'] as String,
      authorName: map['author_name'] as String,
      body: map['body'] as String,
      createdAt: _dateFromMap(map['created_at'])!,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': commentId,
      'post_id': postId,
      'author_user_id': authorUserId,
      'author_name': authorName,
      'body': body,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

DateTime? _dateFromMap(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}
