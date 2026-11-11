// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/settings/providers.dart';
import '../../../core/search/queries/providers.dart';
import '../../../foundation/riverpod/riverpod.dart';
import '../client_provider.dart';
import 'parser.dart';
import 'types.dart';

final joyreactorPostRepoProvider =
    Provider.family<PostRepository<JoyreactorPost>, BooruConfigSearch>(
  (ref, config) {
    final client = ref.watch(joyreactorClientProvider(config.auth));

    return PostRepositoryBuilder(
      tagComposer: ref.watch(defaultTagQueryComposerProvider(config)),
      getSettings: () async => ref.read(imageListingSettingsProvider),
      fetchSingle: (id, {options}) async {
        final numericId = id as NumericPostId?;
        if (numericId == null) return Future.value(null);

        final dto = await client.getPost(id: numericId.value);
        if (dto == null) return null;

        final expanded = parseJoyreactorPostDto(dto);
        if (expanded.isEmpty) return null;

        // Match exact attachment if synthetic sub-ID was requested, otherwise primary attachment
        return expanded.firstWhere(
          (p) => p.id == numericId.value,
          orElse: () => expanded.first,
        );
      },
      fetch: (tags, page, {limit, options}) async {
        final dtos = await client.getPosts(
          tags: tags,
          page: page,
        );

        final posts = <JoyreactorPost>[];
        for (final dto in dtos) {
          posts.addAll(
            parseJoyreactorPostDto(
              dto,
              metadata: PostMetadata(
                page: page,
                search: tags.join(' '),
                limit: limit,
              ),
            ),
          );
        }

        return posts.toResult();
      },
    );
  },
);
