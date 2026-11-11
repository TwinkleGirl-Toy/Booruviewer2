// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import 'types.dart';

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
    DetailsPart.artistPosts: (context) =>
        const JoyreactorPostMetadataSection(),
    DetailsPart.source: (context) =>
        const DefaultInheritedSourceSection<JoyreactorPost>(),
    DetailsPart.tags: (context) =>
        const DefaultInheritedBasicTagsTile<JoyreactorPost>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<JoyreactorPost>(),
  },
);

class JoyreactorPostMetadataSection extends ConsumerWidget {
  const JoyreactorPostMetadataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.maybeOf<JoyreactorPost>(context);
    if (post == null) return const SizedBox.shrink();

    final currentPost = post.post;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentPost.title != null && currentPost.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                currentPost.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (currentPost.description != null &&
              currentPost.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                currentPost.description!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (currentPost.uploaderName != null &&
                  currentPost.uploaderName!.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(currentPost.uploaderName!),
                  visualDensity: VisualDensity.compact,
                ),
              if (currentPost.attachmentCount > 1)
                Chip(
                  avatar: const Icon(Icons.collections_outlined, size: 16),
                  label: Text(
                    'Image ${currentPost.attachmentIndex + 1} of ${currentPost.attachmentCount}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              if (currentPost.commentCount != null)
                Chip(
                  avatar: const Icon(Icons.comment_outlined, size: 16),
                  label: Text('${currentPost.commentCount} comments'),
                  visualDensity: VisualDensity.compact,
                ),
              if (currentPost.postUrl != null &&
                  currentPost.postUrl!.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open on JoyReactor'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final uri = Uri.tryParse(currentPost.postUrl!);
                    if (uri != null) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
