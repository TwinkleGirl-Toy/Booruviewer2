// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/search/search/routes.dart';
import '../../../foundation/url_launcher.dart';
import 'types.dart';

class PawchivePostDetailsTile extends ConsumerWidget {
  const PawchivePostDetailsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<PawchivePost>(context);
    final theme = Kurumi.themeOf(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.title case final title? when title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Symbols.hub, size: 16),
                  label: Text('Service: ${post.service}'),
                  onPressed: () => goToSearchPage(
                    ref,
                    tag: 'service:${post.service}',
                  ),
                ),
                if (post.creatorId.isNotEmpty)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Symbols.person, size: 16),
                    label: Text(
                      'Creator: ${post.uploaderName ?? post.creatorId}',
                    ),
                    onPressed: () => goToSearchPage(
                      ref,
                      tag: 'creator:${post.service}:${post.creatorId}',
                    ),
                  ),
                if (post.totalAttachments > 1)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Symbols.collections, size: 16),
                    label: Text(
                      'Attachment ${post.attachmentIndex + 1} of ${post.totalAttachments}',
                    ),
                  ),
              ],
            ),
            if (post.content case final content? when content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (post.postUrl case final postUrl? when postUrl.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    launchExternalUrlString(
                      postUrl,
                      launcher: ref.read(externalUrlLauncherProvider),
                    );
                  },
                  icon: const Icon(Symbols.open_in_new, size: 16),
                  label: const Text('Open on Pawchive'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PawchiveInheritedTagsTile extends ConsumerWidget {
  const PawchiveInheritedTagsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultInheritedBasicTagsTile<PawchivePost>();
  }
}

final kPawchivePostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<PawchivePost>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<PawchivePost>(),
  },
  full: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<PawchivePost>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<PawchivePost>(),
    DetailsPart.artistInfo: (context) => const PawchivePostDetailsTile(),
    DetailsPart.tags: (context) => const PawchiveInheritedTagsTile(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<PawchivePost>(),
  },
);
