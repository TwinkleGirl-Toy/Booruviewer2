// Project imports:
import '../../core/boorus/defaults/widgets.dart';
import '../../core/boorus/engine/types.dart';
import '../../core/configs/config/types.dart';
import '../../core/configs/create/widgets.dart';
import '../../core/posts/details/widgets.dart';
import '../../core/posts/details_parts/types.dart';
import 'home/widgets.dart';
import 'posts/types.dart';
import 'posts/widgets.dart';

class JoyreactorBuilder extends BaseBooruBuilder {
  @override
  CreateConfigPageBuilder get createConfigPageBuilder =>
      (context, id, {backgroundColor}) => CreateBooruConfigScope(
        id: id,
        config: BooruConfig.defaultConfig(
          booruType: id.booruType,
          url: id.url,
          customDownloadFileNameFormat: null,
        ),
        child: CreateAnonConfigPage(backgroundColor: backgroundColor),
      );

  @override
  HomeViewBuilder get homeViewBuilder => (context) => const JoyreactorHomePage();

  @override
  PostDetailsPageBuilder get postDetailsPageBuilder => (context, payload) {
    final posts = payload.posts.map((e) => e as JoyreactorPost).toList();

    return PostDetailsScope(
      initialIndex: payload.initialIndex,
      initialThumbnailUrl: payload.initialThumbnailUrl,
      posts: posts,
      scrollController: payload.scrollController,
      dislclaimer: payload.dislclaimer,
      child: const DefaultPostDetailsPage<JoyreactorPost>(),
    );
  };

  @override
  PostDetailsUIBuilder get postDetailsUIBuilder =>
      kJoyreactorPostDetailsUIBuilder;
}
