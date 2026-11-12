// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../foundation/url_launcher.dart';
import 'types.dart';

class JoyreactorPostDetailsTile extends ConsumerWidget {
  const JoyreactorPostDetailsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<JoyreactorPost>(context);
    final theme = Kurumi.themeOf(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.totalAttachments > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Symbols.collections, size: 16),
                  label: Text(
                    'Attachment ${post.attachmentIndex + 1} of ${post.totalAttachments} (Post #${post.parentPostId})',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
            Row(
              children: [
                if (post.uploaderName case final author?
                    when author.isNotEmpty) ...[
                  const Icon(Symbols.person, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    author,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),
                if (post.postUrl case final postUrl? when postUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      launchExternalUrlString(
                        postUrl,
                        launcher: ref.read(externalUrlLauncherProvider),
                      );
                    },
                    icon: const Icon(Symbols.open_in_new, size: 16),
                    label: const Text('Open on JoyReactor'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JoyreactorStatsTile extends StatelessWidget {
  const JoyreactorStatsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final post = InheritedPost.of<JoyreactorPost>(context);

    return SliverToBoxAdapter(
      child: SimplePostStatsTile(
        totalComments: post.commentCount ?? 0,
        favCount: 0,
        score: post.score,
      ),
    );
  }
}

class JoyreactorInheritedTagsTile extends ConsumerWidget {
  const JoyreactorInheritedTagsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DefaultInheritedBasicTagsTile<JoyreactorPost>();
  }
}

final kJoyreactorPostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<JoyreactorPost>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<JoyreactorPost>(),
  },
  full: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<JoyreactorPost>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<JoyreactorPost>(),
    DetailsPart.artistInfo: (context) => const JoyreactorPostDetailsTile(),
    DetailsPart.stats: (context) => const JoyreactorStatsTile(),
    DetailsPart.tags: (context) => const JoyreactorInheritedTagsTile(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<JoyreactorPost>(),
  },
);
