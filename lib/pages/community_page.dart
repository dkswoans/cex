import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_model.dart';
import '../models/user_model.dart';
import '../providers/community_provider.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';

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
          body: _CommunityPostList(provider: communityProvider),
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
  const _CommunityPostList({required this.provider});

  final CommunityProvider provider;

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const _CommunityHeaderBanner(),
          const SizedBox(height: 14),
          if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _CommunityEmptyPanel(text: emptyText),
            )
          else
            ...posts.map(
              (post) => _CommunityPostCard(
                post: post,
                commentCount: provider.getCommentCount(post.postId),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          _CommunityPostDetailPage(postId: post.postId),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Design tokens (punk-zine: paper panels + neon accents + sticker shadows)
// ---------------------------------------------------------------------------

const _paper = Color(0xFFFF67C7); // neon pink panel base

const _communityPaperColor = _paper;
const _communitySubtleColor = bgColor;
const _communityInkColor = textColor;
const _communityMutedColor = mutedTextColor;
const _communityLineColor = borderColor;

const _cardTitleStyle = TextStyle(
  color: borderColor,
  fontSize: 19,
  fontWeight: FontWeight.w900,
  height: 1.18,
  letterSpacing: -0.2,
);

const _postDetailTitleStyle = TextStyle(
  color: borderColor,
  fontSize: 28,
  fontWeight: FontWeight.w900,
  height: 1.12,
  letterSpacing: -0.3,
);

const _postBodyStyle = TextStyle(
  color: borderColor,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.6,
  letterSpacing: 0,
);

const _commentBodyStyle = TextStyle(
  color: borderColor,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.5,
  letterSpacing: 0,
);

class _CardTone {
  const _CardTone({required this.hero, required this.shadow});

  final Color hero; // spine, avatar, comment pill
  final Color shadow; // offset sticker shadow
}

const _cardTones = <_CardTone>[
  _CardTone(hero: redColor, shadow: blueColor),
  _CardTone(hero: textColor, shadow: greenColor),
  _CardTone(hero: greenColor, shadow: redColor),
  _CardTone(hero: amberColor, shadow: mutedTextColor),
  _CardTone(hero: blueColor, shadow: borderColor),
];

_CardTone _toneFor(String seed) =>
    _cardTones[seed.hashCode.abs() % _cardTones.length];

double _cardWobbleAngle(String seed) {
  return ((seed.hashCode.abs() % 9) - 4) * 0.007;
}

/// Black on light fills, white on dark fills — keeps text legible on any tone.
Color _onColor(Color c) =>
    c.computeLuminance() > 0.5 ? borderColor : Colors.white;

class _CommunityHeaderBanner extends StatelessWidget {
  const _CommunityHeaderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor, width: 2.5),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.bolt, color: redColor, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '자유게시판',
                  style: TextStyle(
                    color: bgColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.3,
                    shadows: [
                      Shadow(
                        color: borderColor,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '오늘 헬스장은 어땠나요? 마음껏 떠들어요!',
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityEmptyPanel extends StatelessWidget {
  const _CommunityEmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: _paper,
        border: Border.all(color: borderColor, width: 2.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: -0.05,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: redColor,
                border: Border.all(color: borderColor, width: 2.5),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: borderColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityWriteButton extends StatelessWidget {
  const _CommunityWriteButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: redColor,
        border: Border.all(color: borderColor, width: 2.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: isLoading ? null : onTap,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 18, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, color: Colors.white, size: 20),
                SizedBox(width: 7),
                Text(
                  '글쓰기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0.2,
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

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.commentCount,
    required this.onTap,
  });

  final CommunityPostModel post;
  final int commentCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(post.postId);
    final isHot = commentCount >= 5;

    return Transform.rotate(
      angle: _cardWobbleAngle(post.postId),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: [
            BoxShadow(
              color: tone.shadow,
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          foregroundPainter: _WobblyCardBorderPainter(color: tone.hero),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 5,
                              decoration: BoxDecoration(
                                color: borderColor,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 16,
                              height: 5,
                              decoration: BoxDecoration(
                                color: tone.hero,
                                border: Border.all(
                                  color: borderColor,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                post.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _cardTitleStyle,
                              ),
                            ),
                            if (isHot) ...[
                              const SizedBox(width: 8),
                              const _HotTag(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _AuthorAvatar(
                              name: post.authorName,
                              size: 30,
                              color: tone.hero,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: borderColor,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatDateTime(post.createdAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: mutedTextColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _PostMetric(
                              icon: Icons.chat_bubble_outline,
                              count: commentCount,
                              fillColor: tone.hero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      decoration: BoxDecoration(
                        color: tone.hero,
                        border: const Border(
                          right: BorderSide(color: borderColor, width: 2.5),
                        ),
                      ),
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

class _WobblyCardBorderPainter extends CustomPainter {
  const _WobblyCardBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    const inset = 2.0;

    final outline = Path()
      ..moveTo(13, inset + 3)
      ..cubicTo(
        width * 0.18,
        inset - 4,
        width * 0.36,
        inset + 7,
        width * 0.54,
        inset + 1,
      )
      ..cubicTo(
        width * 0.70,
        inset - 5,
        width * 0.86,
        inset + 5,
        width - 14,
        inset + 2,
      )
      ..quadraticBezierTo(width - inset + 1, inset + 5, width - inset - 2, 15)
      ..cubicTo(
        width - inset + 5,
        height * 0.28,
        width - inset - 6,
        height * 0.44,
        width - inset + 2,
        height * 0.61,
      )
      ..cubicTo(
        width - inset + 6,
        height * 0.76,
        width - inset - 4,
        height * 0.88,
        width - 11,
        height - inset - 2,
      )
      ..quadraticBezierTo(
        width - inset - 2,
        height - inset + 1,
        width - 18,
        height - inset - 1,
      )
      ..cubicTo(
        width * 0.78,
        height - inset + 5,
        width * 0.58,
        height - inset - 6,
        width * 0.39,
        height - inset + 2,
      )
      ..cubicTo(
        width * 0.23,
        height - inset + 8,
        width * 0.12,
        height - inset - 5,
        12,
        height - inset - 1,
      )
      ..quadraticBezierTo(inset - 1, height - inset - 3, inset + 2, height - 15)
      ..cubicTo(
        inset - 4,
        height * 0.76,
        inset + 6,
        height * 0.59,
        inset + 1,
        height * 0.42,
      )
      ..cubicTo(
        inset - 5,
        height * 0.26,
        inset + 5,
        height * 0.13,
        inset + 2,
        13,
      )
      ..quadraticBezierTo(inset + 1, inset + 1, 13, inset + 3)
      ..close();

    final outlinePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(outline, outlinePaint);

    final accentPath = Path()
      ..moveTo(18, 7)
      ..cubicTo(32, 2, 46, 12, 60, 7)
      ..quadraticBezierTo(70, 3, 83, 8);
    final accentPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(accentPath, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _WobblyCardBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _HotTag extends StatelessWidget {
  const _HotTag();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: redColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_fire_department, color: Colors.white, size: 13),
            SizedBox(width: 3),
            Text(
              'HOT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostMetric extends StatelessWidget {
  const _PostMetric({
    required this.icon,
    required this.count,
    required this.fillColor,
  });

  final IconData icon;
  final int count;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final fg = _onColor(fillColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ],
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
    final tone = _toneFor(post.postId);

    return Transform.rotate(
      angle: _cardWobbleAngle('detail_${post.postId}') * 0.45,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: [
            BoxShadow(
              color: tone.shadow,
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          foregroundPainter: _WobblyCardBorderPainter(color: tone.hero),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 8, color: tone.hero),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(post.title, style: _postDetailTitleStyle),
                    const SizedBox(height: 13),
                    _DetailMetaRow(
                      authorName: post.authorName,
                      createdAt: post.createdAt,
                      commentCount: commentCount,
                      accentColor: tone.hero,
                    ),
                    const SizedBox(height: 14),
                    Container(height: 2.5, color: borderColor),
                    const SizedBox(height: 16),
                    _PostBodyText(text: post.body),
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

class _PostBodyText extends StatelessWidget {
  const _PostBodyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _postBodyStyle);
  }
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({
    required this.authorName,
    required this.createdAt,
    required this.commentCount,
    this.accentColor = textColor,
  });

  final String authorName;
  final DateTime createdAt;
  final int commentCount;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: accentColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: borderColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: mutedTextColor,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      formatDateTime(createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mutedTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _PostMetric(
          icon: Icons.chat_bubble_outline,
          count: commentCount,
          fillColor: accentColor,
        ),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.name,
    this.size = 34,
    this.color = textColor,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = _authorInitial(name);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: _onColor(color),
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
          const Icon(Icons.forum_outlined, color: borderColor, size: 20),
          const SizedBox(width: 7),
          const Text(
            '댓글',
            style: TextStyle(
              color: borderColor,
              fontSize: 17,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
        color: _paper,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: const [
          BoxShadow(color: blueColor, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.mode_comment_outlined, color: mutedTextColor, size: 26),
          SizedBox(height: 8),
          Text(
            '아직 댓글이 없어요!  첫 댓글을 남겨보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _communityMutedColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingPostPanel extends StatelessWidget {
  const _MissingPostPanel();

  @override
  Widget build(BuildContext context) {
    return const _CommunityEmptyPanel(text: '게시글을 찾을 수 없습니다.');
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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(keepScrollOffset: false);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
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
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                _CommunityPostArticle(
                  post: post,
                  commentCount: comments.length,
                ),
                const SizedBox(height: 16),
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
    final tone = _toneFor(comment.authorName);

    return Transform.rotate(
      angle: _cardWobbleAngle(comment.commentId) * 0.35,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: [
            BoxShadow(
              color: tone.shadow,
              offset: const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          foregroundPainter: _WobblyCardBorderPainter(color: tone.hero),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorAvatar(
                      name: comment.authorName,
                      size: 32,
                      color: tone.hero,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: borderColor,
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
                              color: mutedTextColor,
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
                const SizedBox(height: 10),
                Text(comment.body, style: _commentBodyStyle),
              ],
            ),
          ),
        ),
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
