import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show RealtimeChannel, PostgresChangeEvent;

import '../models/community_model.dart';
import '../models/user_model.dart';
import '../services/supabase_config.dart';

class CommunityProvider extends ChangeNotifier {
  CommunityProvider() {
    syncFromDatabase();
    _initRealtime();
  }

  final List<CommunityPostModel> posts = [];
  final List<CommunityCommentModel> comments = [];
  bool isLoading = false;
  bool isActionLoading = false;
  String? errorMessage;

  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  CommunityPostModel? getPostById(String postId) {
    for (final post in posts) {
      if (post.postId == postId) return post;
    }
    return null;
  }

  List<CommunityCommentModel> getCommentsByPost(String postId) {
    return comments.where((comment) => comment.postId == postId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  int getCommentCount(String postId) {
    return comments.where((comment) => comment.postId == postId).length;
  }

  bool canManagePost(CommunityPostModel post, UserModel? user) {
    if (user == null) return false;
    return user.role == 'admin' || post.authorUserId == user.userId;
  }

  bool canManageComment(CommunityCommentModel comment, UserModel? user) {
    if (user == null) return false;
    return user.role == 'admin' || comment.authorUserId == user.userId;
  }

  Future<void> syncFromDatabase({bool showLoading = true}) async {
    if (showLoading) {
      isLoading = true;
    }
    errorMessage = null;
    if (showLoading) {
      notifyListeners();
    }

    try {
      final postRows = await SupabaseConfig.client
          .from('community_posts')
          .select()
          .order('created_at', ascending: false);

      final commentRows = await SupabaseConfig.client
          .from('community_comments')
          .select()
          .order('created_at');

      posts
        ..clear()
        ..addAll(
          postRows.map(
            (row) =>
                CommunityPostModel.fromSupabase(Map<String, dynamic>.from(row)),
          ),
        );
      comments
        ..clear()
        ..addAll(
          commentRows.map(
            (row) => CommunityCommentModel.fromSupabase(
              Map<String, dynamic>.from(row),
            ),
          ),
        );
    } catch (error) {
      debugPrint('[CommunityProvider] syncFromDatabase error: $error');
      posts.clear();
      comments.clear();
      errorMessage = '커뮤니티 데이터를 불러오지 못했습니다.';
    } finally {
      if (showLoading) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<String> createPost({
    required UserModel user,
    required String title,
    required String body,
  }) => _runAction(() async {
    final normalizedTitle = _normalizeTitle(title);
    final normalizedBody = body.trim();

    if (normalizedTitle.isEmpty || normalizedBody.isEmpty) {
      return '제목과 내용을 입력하세요.';
    }
    if (normalizedTitle.length > 80) {
      return '제목은 80자까지 입력할 수 있습니다.';
    }
    if (normalizedBody.length > 1200) {
      return '내용은 1200자까지 입력할 수 있습니다.';
    }

    final now = DateTime.now();
    final post = CommunityPostModel(
      postId: 'post_${user.userId}_${now.microsecondsSinceEpoch}',
      authorUserId: user.userId,
      authorName: user.name,
      title: normalizedTitle,
      body: normalizedBody,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await SupabaseConfig.client
          .from('community_posts')
          .insert(post.toSupabase());
      await syncFromDatabase(showLoading: false);
      return '게시글을 올렸습니다.';
    } catch (error) {
      debugPrint('[CommunityProvider] createPost error: $error');
      return '게시글 저장에 실패했습니다.';
    }
  });

  Future<String> deletePost({
    required UserModel user,
    required CommunityPostModel post,
  }) => _runAction(() async {
    if (!canManagePost(post, user)) {
      return '삭제 권한이 없습니다.';
    }

    try {
      await SupabaseConfig.client
          .from('community_posts')
          .delete()
          .eq('id', post.postId);
      posts.removeWhere((item) => item.postId == post.postId);
      comments.removeWhere((item) => item.postId == post.postId);
      notifyListeners();
      return '게시글을 삭제했습니다.';
    } catch (error) {
      debugPrint('[CommunityProvider] deletePost error: $error');
      return '게시글 삭제에 실패했습니다.';
    }
  });

  Future<String> createComment({
    required UserModel user,
    required String postId,
    required String body,
  }) => _runAction(() async {
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty) {
      return '댓글을 입력하세요.';
    }
    if (normalizedBody.length > 500) {
      return '댓글은 500자까지 입력할 수 있습니다.';
    }

    final now = DateTime.now();
    final comment = CommunityCommentModel(
      commentId: 'comment_${user.userId}_${now.microsecondsSinceEpoch}',
      postId: postId,
      authorUserId: user.userId,
      authorName: user.name,
      body: normalizedBody,
      createdAt: now,
    );

    try {
      await SupabaseConfig.client
          .from('community_comments')
          .insert(comment.toSupabase());
      comments.add(comment);
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
      return '댓글을 남겼습니다.';
    } catch (error) {
      debugPrint('[CommunityProvider] createComment error: $error');
      return '댓글 저장에 실패했습니다.';
    }
  });

  Future<String> deleteComment({
    required UserModel user,
    required CommunityCommentModel comment,
  }) => _runAction(() async {
    if (!canManageComment(comment, user)) {
      return '삭제 권한이 없습니다.';
    }

    try {
      await SupabaseConfig.client
          .from('community_comments')
          .delete()
          .eq('id', comment.commentId);
      comments.removeWhere((item) => item.commentId == comment.commentId);
      notifyListeners();
      return '댓글을 삭제했습니다.';
    } catch (error) {
      debugPrint('[CommunityProvider] deleteComment error: $error');
      return '댓글 삭제에 실패했습니다.';
    }
  });

  Future<String> _runAction(Future<String> Function() action) async {
    isActionLoading = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  void _initRealtime() {
    final channel = SupabaseConfig.client.channel('community_realtime');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_posts',
          callback: (_) => _scheduleRealtimeSync(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_comments',
          callback: (_) => _scheduleRealtimeSync(),
        )
        .subscribe();
    _realtimeChannel = channel;
  }

  void _scheduleRealtimeSync() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(
      const Duration(milliseconds: 700),
      () => syncFromDatabase(showLoading: false),
    );
  }

  String _normalizeTitle(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
