// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/boorus/defaults/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/create.dart';
import '../../core/downloads/filename/types.dart';
import '../../core/downloads/urls/types.dart';
import '../../core/posts/post/providers.dart';
import '../../core/posts/post/types.dart';
import '../../core/tags/autocompletes/types.dart';
import 'client_provider.dart';
import 'downloads/providers.dart';
import 'posts/providers.dart';
import 'tags/providers.dart';

class JoyreactorRepository extends BooruRepositoryDefault {
  const JoyreactorRepository({required this.ref});

  @override
  final Ref ref;

  @override
  PostRepository<Post> post(BooruConfigSearch config) {
    return ref.read(joyreactorPostRepoProvider(config));
  }

  @override
  AutocompleteRepository autocomplete(BooruConfigAuth config) {
    return ref.watch(joyreactorAutocompleteRepoProvider(config));
  }

  @override
  DownloadFileUrlExtractor downloadFileUrlExtractor(BooruConfigAuth config) {
    return const JoyreactorDownloadFileUrlExtractor();
  }

  @override
  BooruSiteValidator? siteValidator(BooruConfigAuth config) {
    final client = ref.watch(joyreactorClientProvider(config));
    return () => client.getPosts().then((posts) => posts.isNotEmpty);
  }

  @override
  PostLinkGenerator<Post> postLinkGenerator(BooruConfigAuth config) {
    return SingularPostLinkGenerator(baseUrl: config.url);
  }

  @override
  DownloadFilenameGenerator<Post> downloadFilenameBuilder(
    BooruConfigAuth config,
  ) {
    return createJoyreactorDownloadFilenameGenerator();
  }
}
