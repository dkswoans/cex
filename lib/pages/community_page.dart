import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_model.dart';
import '../models/user_model.dart';
import '../providers/community_provider.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/wobbly_card.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GymProvider, CommunityProvider>(
      builder: (context, gymProvider, communityProvider, _) {
        final currentUser = gymProvider.currentUser;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('커뮤니티'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '새로고침',
                onPressed: communityProvider.isLoading
                    ? null
                    : () async {
                        await communityProvider.syncFromDatabase();
                        if (!context.mounted) return;
                        if (communityProvider.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(communityProvider.errorMessage!),
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: currentUser == null
              ? null
              : _CommunityWriteButton(
                  isLoading: communityProvider.isActionLoading,
                  onTap: () => _showCreatePostDialog(
                    context,
                    communityProvider,
                    currentUser,
                  ),
                ),
          body: _CommunityPostList(
            provider: communityProvider,
            currentUser: currentUser,
          ),
        );
      },
    );
  }

  Future<void> _showCreatePostDialog(
    BuildContext context,
    CommunityProvider provider,
    UserModel user,
  ) async {
    final request = await showDialog<_PostInput>(
      context: context,
      builder: (_) => const _PostEditorDialog(),
    );
    if (request == null) return;

    final message = await provider.createPost(
      user: user,
      title: request.title,
      body: request.body,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CommunityPostList extends StatelessWidget {
  const _CommunityPostList({required this.provider, required this.currentUser});

  final CommunityProvider provider;
  final UserModel? currentUser;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final posts = provider.posts;
    final emptyText = provider.errorMessage ?? '아직 게시글이 없습니다.';

    return RefreshIndicator(
      onRefresh: provider.syncFromDatabase,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
        children: [
          _sectionLabel('자유게시판'),
          if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _tiltedCard(
                seed: 'community_empty',
                child: Center(child: _funLabel(emptyText, 'community_empty')),
              ),
            )
          else
            ...posts.map(
              (post) => _CommunityPostCard(
                post: post,
                commentCount: provider.getCommentCount(post.postId),
                canDelete: provider.canManagePost(post, currentUser),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          _CommunityPostDetailPage(postId: post.postId),
                    ),
                  );
                },
                onDelete: () =>
                    _confirmDeletePost(context, provider, currentUser, post),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePost(
    BuildContext context,
    CommunityProvider provider,
    UserModel? user,
    CommunityPostModel post,
  ) async {
    if (user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글과 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final message = await provider.deletePost(user: user, post: post);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Widget _tiltedCard({
  required String seed,
  required Widget child,
  List<BoxShadow>? shadows,
  EdgeInsets padding = const EdgeInsets.all(AppSpacing.lg),
  Color fillColor = surfaceColor,
  double rotationScale = 0.018,
}) {
  final angle =
      (math.Random(seed.hashCode ^ 0xABCD).nextDouble() - 0.5) * rotationScale;
  return Transform.rotate(
    angle: angle,
    child: WobblyCard(
      seed: seed,
      shadows: shadows ?? _cleanShadows(seed),
      padding: padding,
      fillColor: fillColor,
      child: child,
    ),
  );
}

List<BoxShadow> _cleanShadows(String seed) {
  final rng = math.Random(seed.hashCode);
  const colors = [blueColor, redColor, greenColor, amberColor];
  final primaryIndex = rng.nextInt(colors.length);
  final primary = colors[primaryIndex];
  final secondary = colors[(primaryIndex + 1 + rng.nextInt(2)) % colors.length];
  return [
    BoxShadow(color: primary, offset: const Offset(4, 4), blurRadius: 0),
    BoxShadow(
      color: secondary,
      offset: const Offset(-1.5, -1.5),
      blurRadius: 0,
    ),
  ];
}

Color _accentColor(String seed) {
  final rng = math.Random(seed.hashCode);
  const colors = [redColor, blueColor, greenColor, amberColor];
  return colors[rng.nextInt(colors.length)];
}

const _postListTitleStyle = TextStyle(
  color: textColor,
  fontSize: 20,
  fontWeight: FontWeight.w900,
  height: 1.12,
);

const _postListMetaStyle = TextStyle(
  color: mutedTextColor,
  fontSize: 13,
  fontWeight: FontWeight.w900,
  height: 1.12,
);

const _communityPaperColor = surfaceColor;
const _communitySubtleColor = bgColor;
const _communityInkColor = textColor;
const _communityMutedColor = mutedTextColor;
const _communityLineColor = borderColor;

const _postDetailTitleStyle = TextStyle(
  color: _communityInkColor,
  fontSize: 23,
  fontWeight: FontWeight.w900,
  height: 1.22,
  letterSpacing: 0,
);

const _postBodyStyle = TextStyle(
  color: _communityInkColor,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.55,
  letterSpacing: 0,
);

const _commentBodyStyle = TextStyle(
  color: _communityInkColor,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.45,
  letterSpacing: 0,
);

Widget _sectionLabel(String text) {
  final rng = math.Random(text.hashCode);
  final angle = (rng.nextDouble() - 0.5) * 0.12;
  const colors = [textColor, blueColor, redColor, amberColor];
  final color = colors[rng.nextInt(colors.length)];
  return Padding(
    padding: const EdgeInsets.only(bottom: 2, top: 10),
    child: Transform.rotate(
      alignment: Alignment.centerLeft,
      angle: angle,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
      ),
    ),
  );
}

Widget _funLabel(String text, String seed) {
  final rng = math.Random(seed.hashCode);
  final angle = (rng.nextDouble() - 0.5) * 0.08;
  return Transform.rotate(
    angle: angle,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1.25,
      ),
    ),
  );
}

class _CommunityWriteButton extends StatelessWidget {
  const _CommunityWriteButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        decoration: BoxDecoration(
          color: redColor,
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: const [
            BoxShadow(color: blueColor, offset: Offset(4, 4), blurRadius: 0),
            BoxShadow(color: amberColor, offset: Offset(-2, -2), blurRadius: 0),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: isLoading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 17, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit, color: bgColor, size: 22),
                  SizedBox(width: 7),
                  Text(
                    '글쓰기',
                    style: TextStyle(
                      color: bgColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: borderColor,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityPostArticle extends StatelessWidget {
  const _CommunityPostArticle({required this.post, required this.commentCount});

  final CommunityPostModel post;
  final int commentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _communityPaperColor,
        border: Border.all(color: borderColor, width: 2.5),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(4, 4), blurRadius: 0),
          BoxShadow(color: redColor, offset: Offset(-2, -2), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailMetaRow(
            authorName: post.authorName,
            createdAt: post.createdAt,
          ),
          const SizedBox(height: 17),
          Text(post.title, style: _postDetailTitleStyle),
          const SizedBox(height: 14),
          _PostBodyText(text: post.body),
          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 1, color: _communityLineColor),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.mode_comment_outlined,
                color: _communityMutedColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '댓글',
                style: const TextStyle(
                  color: _communityMutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              _CountPill(count: commentCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostBodyText extends StatelessWidget {
  const _PostBodyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _postBodyStyle);
  }
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({required this.authorName, required this.createdAt});

  final String authorName;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AuthorAvatar(name: authorName, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _communityInkColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatDateTime(createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _communityMutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: _communitySubtleColor,
            border: Border.all(color: _communityLineColor, width: 1),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: const Text(
            '자유게시판',
            style: TextStyle(
              color: _communityMutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.name, this.size = 34});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = _authorInitial(name);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(blueColor, _communityPaperColor, 0.68),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: _communityInkColor,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }

  String _authorInitial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1);
  }
}

class _CommentSectionHeader extends StatelessWidget {
  const _CommentSectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, color: textColor, size: 21),
          const SizedBox(width: 7),
          const Text(
            '댓글',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 7),
          _CountPill(count: count),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(height: 1, thickness: 2, color: borderColor),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: greenColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: borderColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CommentEmptyPanel extends StatelessWidget {
  const _CommentEmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: _communityPaperColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: const Text(
        '아직 댓글이 없습니다.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _communityMutedColor,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1.3,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MissingPostPanel extends StatelessWidget {
  const _MissingPostPanel();

  @override
  Widget build(BuildContext context) {
    return _tiltedCard(
      seed: 'missing_post',
      child: Center(child: _funLabel('게시글을 찾을 수 없습니다.', 'missing_post')),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.commentCount,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  final CommunityPostModel post;
  final int commentCount;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(post.postId);
    final rng = math.Random(post.postId.hashCode);
    final angle = (rng.nextDouble() - 0.5) * 0.014;
    final radius = 7.0 + rng.nextInt(4);

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: Color.lerp(surfaceColor, accent, 0.08),
            border: Border.all(color: borderColor, width: 3),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: accent,
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 50,
                decoration: BoxDecoration(
                  color: accent,
                  border: Border.all(color: borderColor, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _PostListText(post: post)),
              const SizedBox(width: 8),
              _PostCountBadge(count: commentCount, color: accent),
              if (canDelete)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                  color: redColor,
                  tooltip: '삭제',
                  onPressed: onDelete,
                ),
              const Icon(Icons.chevron_right, color: textColor, size: 23),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostListText extends StatelessWidget {
  const _PostListText({required this.post});

  final CommunityPostModel post;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          post.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _postListTitleStyle,
        ),
        const SizedBox(height: 5),
        Text(
          '${post.authorName}  ·  ${formatDateTime(post.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _postListMetaStyle,
        ),
      ],
    );
  }
}

class _PostCountBadge extends StatelessWidget {
  const _PostCountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [BoxShadow(color: color, offset: const Offset(2, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityPostDetailPage extends StatefulWidget {
  const _CommunityPostDetailPage({required this.postId});

  final String postId;

  @override
  State<_CommunityPostDetailPage> createState() =>
      _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<_CommunityPostDetailPage> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GymProvider, CommunityProvider>(
      builder: (context, gymProvider, communityProvider, _) {
        final currentUser = gymProvider.currentUser;
        final post = communityProvider.getPostById(widget.postId);

        if (post == null) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(title: const Text('게시글')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _MissingPostPanel(),
              ),
            ),
          );
        }

        final comments = communityProvider.getCommentsByPost(post.postId);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('자유게시판'),
            actions: [
              if (communityProvider.canManagePost(post, currentUser))
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                  onPressed: communityProvider.isActionLoading
                      ? null
                      : () => _confirmDeletePost(
                          context,
                          communityProvider,
                          currentUser,
                          post,
                        ),
                ),
            ],
          ),
          bottomNavigationBar: currentUser == null
              ? null
              : _CommentInputBar(
                  controller: _commentController,
                  isLoading: communityProvider.isActionLoading,
                  onSend: () =>
                      _submitComment(communityProvider, currentUser, post),
                ),
          body: RefreshIndicator(
            onRefresh: communityProvider.syncFromDatabase,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                _CommunityPostArticle(
                  post: post,
                  commentCount: comments.length,
                ),
                const SizedBox(height: 18),
                _CommentSectionHeader(count: comments.length),
                if (comments.isEmpty)
                  const _CommentEmptyPanel()
                else
                  ...comments.map(
                    (comment) => _CommentTile(
                      comment: comment,
                      canDelete: communityProvider.canManageComment(
                        comment,
                        currentUser,
                      ),
                      onDelete: () => _confirmDeleteComment(
                        context,
                        communityProvider,
                        currentUser,
                        comment,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitComment(
    CommunityProvider provider,
    UserModel user,
    CommunityPostModel post,
  ) async {
    final body = _commentController.text;
    final message = await provider.createComment(
      user: user,
      postId: post.postId,
      body: body,
    );
    if (!mounted) return;
    if (body.trim().isNotEmpty && message == '댓글을 남겼습니다.') {
      _commentController.clear();
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDeletePost(
    BuildContext context,
    CommunityProvider provider,
    UserModel? user,
    CommunityPostModel post,
  ) async {
    if (user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글과 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final message = await provider.deletePost(user: user, post: post);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDeleteComment(
    BuildContext context,
    CommunityProvider provider,
    UserModel? user,
    CommunityCommentModel comment,
  ) async {
    if (user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final message = await provider.deleteComment(user: user, comment: comment);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final CommunityCommentModel comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 12, 10, 13),
      decoration: BoxDecoration(
        color: _communityPaperColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorAvatar(name: comment.authorName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _communityInkColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDateTime(comment.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _communityMutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                  color: redColor,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(comment.body, style: _commentBodyStyle),
          ),
        ],
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  const _CommentInputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
        decoration: const BoxDecoration(
          color: _communityPaperColor,
          border: Border(top: BorderSide(color: borderColor, width: 2.5)),
          boxShadow: [
            BoxShadow(color: blueColor, offset: Offset(0, -3), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(
                  color: _communityInkColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  hintText: '댓글을 남겨보세요',
                  hintStyle: const TextStyle(
                    color: _communityMutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: _communitySubtleColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: const BorderSide(
                      color: _communityLineColor,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: const BorderSide(color: borderColor, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: redColor,
                border: Border.all(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: bgColor),
                tooltip: '댓글 등록',
                onPressed: isLoading ? null : onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostInput {
  const _PostInput({required this.title, required this.body});

  final String title;
  final String body;
}

class _PostEditorDialog extends StatefulWidget {
  const _PostEditorDialog();

  @override
  State<_PostEditorDialog> createState() => _PostEditorDialogState();
}

class _PostEditorDialogState extends State<_PostEditorDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 4),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: const [
            BoxShadow(color: blueColor, offset: Offset(6, 6), blurRadius: 0),
            BoxShadow(color: redColor, offset: Offset(-3, -3), blurRadius: 0),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 13),
                decoration: const BoxDecoration(
                  color: redColor,
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: borderColor, width: 3),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: const Icon(Icons.edit, color: redColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '글쓰기',
                        style: TextStyle(
                          color: bgColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: borderColor,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: bgColor),
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PostEditorField(
                        controller: _titleController,
                        label: '제목',
                        icon: Icons.title,
                        maxLength: 80,
                        minLines: 1,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _PostEditorField(
                        controller: _bodyController,
                        label: '내용',
                        icon: Icons.notes,
                        maxLength: 1200,
                        minLines: 7,
                        maxLines: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: surfaceColor,
                  border: Border(top: BorderSide(color: borderColor, width: 3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _EditorActionButton(
                        label: '취소',
                        icon: Icons.close,
                        fillColor: bgColor,
                        textColor: textColor,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _EditorActionButton(
                        label: '등록',
                        icon: Icons.check,
                        fillColor: redColor,
                        textColor: bgColor,
                        onTap: () {
                          Navigator.pop(
                            context,
                            _PostInput(
                              title: _titleController.text,
                              body: _bodyController.text,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostEditorField extends StatelessWidget {
  const _PostEditorField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLength;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: const [
          BoxShadow(color: amberColor, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: greenColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            enableSuggestions: true,
            autocorrect: true,
            style: const TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: surfaceColor,
              hintText: '$label 입력',
              hintStyle: const TextStyle(color: mutedTextColor),
              contentPadding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$maxLength자까지',
                style: const TextStyle(
                  color: mutedTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorActionButton extends StatelessWidget {
  const _EditorActionButton({
    required this.label,
    required this.icon,
    required this.fillColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color fillColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
