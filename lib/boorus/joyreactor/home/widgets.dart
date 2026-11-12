// Package imports:
import 'package:booru_clients/joyreactor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/announcements/widgets.dart';
import '../../../core/configs/config/providers.dart';
import '../../../core/home/widgets.dart';
import '../../../core/posts/count/widgets.dart';
import '../../../core/posts/listing/providers.dart';
import '../../../core/posts/listing/widgets.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/search/types.dart';
import '../../../core/search/search/widgets.dart';
import '../../../core/search/selected_tags/providers.dart';
import '../../../core/settings/providers.dart';
import '../../../core/tags/metatag/providers.dart';
import '../../../foundation/display.dart';
import '../posts/providers.dart';
import '../posts/types.dart';

class JoyreactorHomePage extends ConsumerStatefulWidget {
  const JoyreactorHomePage({super.key});

  @override
  ConsumerState<JoyreactorHomePage> createState() => _JoyreactorHomePageState();
}

class _JoyreactorHomePageState extends ConsumerState<JoyreactorHomePage> {
  final selectedTagString = ValueNotifier('');
  late final SelectedTagController selectedTagController;

  @override
  void initState() {
    super.initState();

    selectedTagController = SelectedTagController(
      metatagExtractor: ref.read(metatagExtractorProvider(ref.readConfigAuth)),
    );
  }

  @override
  void dispose() {
    super.dispose();
    selectedTagString.dispose();
    selectedTagController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfigSearch;
    final feed = ref.watch(joyreactorFeedTypeProvider);
    final postRepo = ref.watch(
      joyreactorPostRepoWithFeedProvider((config: config, feed: feed)),
    );
    final searchBarPosition = ref.watch(searchBarPositionProvider);

    return PostScope(
      fetcher: (page) {
        return postRepo.getPostsFromController(
          selectedTagController.tagSet,
          page,
        );
      },
      builder: (context, postController) => Column(
        children: [
          Expanded(
            child: PostGrid(
              controller: postController,
              sliverHeaders: [
                if (context.isLargeScreen ||
                    searchBarPosition == SearchBarPosition.top)
                  SliverHomeSearchBar(
                    selectedTagController: selectedTagController,
                    selectedTagString: selectedTagString,
                    onSearch: () {
                      postController.refresh();
                    },
                  ),
                const SliverAppAnnouncementBanner(),
                SliverToBoxAdapter(
                  child: JoyreactorFeedSelectorBar(
                    selectedFeed: feed,
                    onFeedSelected: (newFeed) {
                      if (newFeed == feed) return;
                      ref.read(joyreactorFeedTypeProvider.notifier).state =
                          newFeed;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        postController.refresh();
                      });
                    },
                  ),
                ),
                if (context.isLargeScreen)
                  SliverResultHeader(
                    selectedTagString: selectedTagString,
                    controller: postController,
                  ),
              ],
            ),
          ),
          if (searchBarPosition == SearchBarPosition.bottom &&
              !context.isLargeScreen)
            Consumer(
              builder: (_, ref, _) {
                final position = ref.watch(
                  settingsProvider.select(
                    (value) => value.booruConfigSelectorPosition,
                  ),
                );

                return SafeArea(
                  top: false,
                  bottom: !position.isBottom,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: CustomScrollView(
                      slivers: [
                        SliverHomeSearchBar(
                          primary: false,
                          selectedTagController: selectedTagController,
                          selectedTagString: selectedTagString,
                          onSearch: () {
                            postController.refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class JoyreactorSearchPage extends ConsumerStatefulWidget {
  const JoyreactorSearchPage({
    required this.params,
    super.key,
  });

  final SearchParams params;

  @override
  ConsumerState<JoyreactorSearchPage> createState() =>
      _JoyreactorSearchPageState();
}

class _JoyreactorSearchPageState extends ConsumerState<JoyreactorSearchPage> {
  late JoyreactorFeed _feed = ref.read(joyreactorFeedTypeProvider);
  ValueNotifier<PostGridController<JoyreactorPost>?>? _postController;

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfigSearch;
    final postRepo = ref.watch(
      joyreactorPostRepoWithFeedProvider((config: config, feed: _feed)),
    );

    return SearchPageScaffold<JoyreactorPost>(
      params: widget.params,
      fetcher: (page, controller) => postRepo.getPostsFromController(
        controller.tagSet,
        page,
      ),
      searchRegionBuilder: (postController, controller) {
        _postController = postController;

        return DefaultSearchRegion(
          controller: controller,
          initialQuery: widget.params.query,
          postController: postController,
        );
      },
      extraHeaders: (context, postController) => [
        SliverToBoxAdapter(
          child: JoyreactorFeedSelectorBar(
            selectedFeed: _feed,
            onFeedSelected: (newFeed) {
              if (_feed == newFeed) return;
              setState(() {
                _feed = newFeed;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _postController?.value?.refresh();
              });
            },
          ),
        ),
      ],
    );
  }
}

class JoyreactorFeedSelectorBar extends StatelessWidget {
  const JoyreactorFeedSelectorBar({
    required this.selectedFeed,
    required this.onFeedSelected,
    super.key,
  });

  final JoyreactorFeed selectedFeed;
  final ValueChanged<JoyreactorFeed> onFeedSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          for (final entry in const [
            (JoyreactorFeed.abyss, 'All'),
            (JoyreactorFeed.good, 'Good'),
            (JoyreactorFeed.best, 'Best'),
            (JoyreactorFeed.latest, 'New'),
            (JoyreactorFeed.abyss, 'Abyss'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.$2),
                selected: selectedFeed == entry.$1,
                onSelected: (selected) {
                  if (selected) {
                    onFeedSelected(entry.$1);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
