// Package imports:
import 'package:booru_clients/joyreactor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/queries/providers.dart';
import '../../../core/settings/providers.dart';
import '../client_provider.dart';
import 'parser.dart';
import 'types.dart';

final joyreactorFeedTypeProvider = StateProvider<JoyreactorFeedType>(
  (ref) => JoyreactorFeedType.all,
);

final joyreactorSeenPostIdsProvider =
    Provider.family<Set<int>, BooruConfigSearch>(
      (ref, config) => <int>{},
    );

final joyreactorPostRepoProvider =
    Provider.family<PostRepository<JoyreactorPost>, BooruConfigSearch>(
      (ref, config) {
        final feed = ref.watch(joyreactorFeedTypeProvider);
        return _createJoyreactorPostRepository(
          ref: ref,
          config: config,
          feed: feed,
        );
      },
    );

final joyreactorPostRepoWithFeedProvider =
    Provider.family<
      PostRepository<JoyreactorPost>,
      ({BooruConfigSearch config, JoyreactorFeedType feed})
    >((ref, params) {
      return _createJoyreactorPostRepository(
        ref: ref,
        config: params.config,
        feed: params.feed,
      );
    });

PostRepository<JoyreactorPost> _createJoyreactorPostRepository({
  required Ref ref,
  required BooruConfigSearch config,
  required JoyreactorFeedType feed,
}) {
  final client = ref.watch(joyreactorClientProvider(config.auth));
  final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));
  final seenIds = ref.watch(joyreactorSeenPostIdsProvider(config));

  return PostRepositoryBuilder<JoyreactorPost>(
    tagComposer: tagComposer,
    fetchSingle: (id, {options}) async {
      final numericId = id as NumericPostId?;
      if (numericId == null) return Future.value();

      final dto = await client.getPost(numericId.value);
      if (dto == null) return null;

      final posts = postDtoToPosts(dto, null);
      return posts.isNotEmpty ? posts.first : null;
    },
    fetch: (tags, page, {limit, options}) async {
      if (page <= 1) {
        seenIds.clear();
      }

      var effectiveFeed = feed;
      final effectiveTags = <String>[];

      for (final rawTag in tags) {
        final lower = rawTag.toLowerCase();
        if (lower == 'feed:good' || lower == 'sort:good') {
          effectiveFeed = JoyreactorFeedType.good;
        } else if (lower == 'feed:best' || lower == 'sort:best') {
          effectiveFeed = JoyreactorFeedType.best;
        } else if (lower == 'feed:new' || lower == 'sort:new') {
          effectiveFeed = JoyreactorFeedType.newPosts;
        } else if (lower == 'feed:abyss' || lower == 'abyss') {
          effectiveFeed = JoyreactorFeedType.abyss;
        } else if (lower == 'feed:all') {
          effectiveFeed = JoyreactorFeedType.all;
        } else {
          effectiveTags.add(rawTag);
        }
      }

      final pageDto = await client.getPosts(
        tags: effectiveTags,
        page: page,
        feed: effectiveFeed,
      );

      final metadata = PostMetadata(
        page: page,
        search: tags.join(' '),
        limit: limit,
      );

      final expandedPosts = <JoyreactorPost>[];
      for (final dto in pageDto.posts) {
        final items = postDtoToPosts(dto, metadata);
        for (final item in items) {
          if (seenIds.add(item.id)) {
            expandedPosts.add(item);
          }
        }
      }

      return expandedPosts.toResult();
    },
    getSettings: () async => ref.read(imageListingSettingsProvider),
  );
}
