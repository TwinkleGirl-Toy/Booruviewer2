// Package imports:
import 'package:booru_clients/pawchive.dart';
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

final pawchiveSortTypeProvider = StateProvider<PawchiveFeed>(
  (ref) => PawchiveFeed.popularDay,
);

final pawchiveSeenPostIdsProvider =
    Provider.family<Set<int>, BooruConfigSearch>(
      (ref, config) => <int>{},
    );

final pawchivePostIdLookupProvider =
    Provider.family<
      Map<int, ({String service, String creatorId, String postId})>,
      BooruConfigSearch
    >(
      (ref, config) => <int, ({String service, String creatorId, String postId})>{},
    );

final pawchivePostRepoProvider =
    Provider.family<PostRepository<PawchivePost>, BooruConfigSearch>(
      (ref, config) {
        final sort = ref.watch(pawchiveSortTypeProvider);
        return _createPawchivePostRepository(
          ref: ref,
          config: config,
          sort: sort,
        );
      },
    );

final pawchivePostRepoWithSortProvider =
    Provider.family<
      PostRepository<PawchivePost>,
      ({BooruConfigSearch config, PawchiveFeed sort})
    >((ref, params) {
      return _createPawchivePostRepository(
        ref: ref,
        config: params.config,
        sort: params.sort,
      );
    });

PostRepository<PawchivePost> _createPawchivePostRepository({
  required Ref ref,
  required BooruConfigSearch config,
  required PawchiveFeed sort,
}) {
  final client = ref.watch(pawchiveClientProvider(config.auth));
  final tagComposer = ref.watch(defaultTagQueryComposerProvider(config));
  final seenIds = ref.watch(pawchiveSeenPostIdsProvider(config));
  final lookup = ref.watch(pawchivePostIdLookupProvider(config));

  return PostRepositoryBuilder<PawchivePost>(
    tagComposer: tagComposer,
    fetchSingle: (id, {options}) async {
      final numericId = id as NumericPostId?;
      if (numericId == null) return Future.value();

      final target = lookup[numericId.value];
      if (target == null) return null;

      final dto = await client.getPostDetails(
        service: target.service,
        userId: target.creatorId,
        postId: target.postId,
      );
      if (dto == null) return null;

      final posts = postDtoToPosts(dto, null);
      return posts.isNotEmpty ? posts.first : null;
    },
    fetch: (tags, page, {limit, options}) async {
      if (page <= 1) {
        seenIds.clear();
      }

      var effectiveSort = sort;
      final effectiveTags = <String>[];

      for (final rawTag in tags) {
        final lower = rawTag.toLowerCase();
        if (lower == 'sort:popular' || lower == 'order:popular') {
          effectiveSort = PawchiveFeed.popularDay;
        } else if (lower == 'sort:recent' ||
            lower == 'sort:new' ||
            lower == 'order:date') {
          effectiveSort = PawchiveFeed.recent;
        } else {
          effectiveTags.add(rawTag);
        }
      }

      final pageDto = await client.getPage(
        tags: effectiveTags,
        page: page,
        defaultFeed: effectiveSort,
      );

      final metadata = PostMetadata(
        page: page,
        search: tags.join(' '),
        limit: limit,
      );

      // On Pawchive, listing cards only expose the thumbnail image.
      // When there is a single search result or when full detail resolution is needed,
      // we also store the lookup key so fetchSingle can load all full-res attachments.
      final expandedPosts = <PawchivePost>[];
      for (final dto in pageDto.posts) {
        final items = postDtoToPosts(dto, metadata);
        for (final item in items) {
          if (item.service.isNotEmpty &&
              item.creatorId.isNotEmpty &&
              item.rawPostId.isNotEmpty) {
            lookup[item.id] = (
              service: item.service,
              creatorId: item.creatorId,
              postId: item.rawPostId,
            );
          }
          if (seenIds.add(item.id)) {
            expandedPosts.add(item);
          }
        }
      }

      return expandedPosts.toResult(total: pageDto.trueCount ?? pageDto.count);
    },
    getSettings: () async => ref.read(imageListingSettingsProvider),
  );
}
