// Package imports:
import 'package:booru_clients/pawchive.dart';
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
import '../../../core/posts/post/providers.dart';
import '../../../core/search/search/routes.dart';
import '../../../core/search/search/types.dart';
import '../../../core/search/search/widgets.dart';
import '../../../core/search/selected_tags/providers.dart';
import '../../../core/settings/providers.dart';
import '../../../core/tags/metatag/providers.dart';
import '../../../foundation/display.dart';
import '../posts/providers.dart';
import '../posts/types.dart';

class PawchiveHomePage extends ConsumerStatefulWidget {
  const PawchiveHomePage({super.key});

  @override
  ConsumerState<PawchiveHomePage> createState() => _PawchiveHomePageState();
}

class _PawchiveHomePageState extends ConsumerState<PawchiveHomePage> {
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
    final sort = ref.watch(pawchiveSortTypeProvider);
    final postRepo = ref.watch(
      pawchivePostRepoWithSortProvider((config: config, sort: sort)),
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
                  child: PawchiveSortAndFilterBar(
                    selectedSort: sort,
                    onSortSelected: (newSort) {
                      if (newSort == sort) return;
                      ref.read(pawchiveSortTypeProvider.notifier).state =
                          newSort;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        postController.refresh();
                      });
                    },
                    onServiceTap: (serviceTag) {
                      goToSearchPage(ref, tag: serviceTag);
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

class PawchiveSearchPage extends ConsumerStatefulWidget {
  const PawchiveSearchPage({
    required this.params,
    super.key,
  });

  final SearchParams params;

  @override
  ConsumerState<PawchiveSearchPage> createState() => _PawchiveSearchPageState();
}

class _PawchiveSearchPageState extends ConsumerState<PawchiveSearchPage> {
  late PawchiveFeed _sort = ref.read(pawchiveSortTypeProvider);
  ValueNotifier<PostGridController<PawchivePost>?>? _postController;

  @override
  Widget build(BuildContext context) {
    final config = ref.watchConfigSearch;
    final postRepo = ref.watch(
      pawchivePostRepoWithSortProvider((config: config, sort: _sort)),
    );

    return SearchPageScaffold<PawchivePost>(
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
          child: PawchiveSortAndFilterBar(
            selectedSort: _sort,
            onSortSelected: (newSort) {
              if (_sort == newSort) return;
              setState(() {
                _sort = newSort;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _postController?.value?.refresh();
              });
            },
            onServiceTap: (serviceTag) {
              goToSearchPage(ref, tag: serviceTag);
            },
          ),
        ),
      ],
    );
  }
}

class PawchiveSortAndFilterBar extends StatelessWidget {
  const PawchiveSortAndFilterBar({
    required this.selectedSort,
    required this.onSortSelected,
    required this.onServiceTap,
    super.key,
  });

  final PawchiveFeed selectedSort;
  final ValueChanged<PawchiveFeed> onSortSelected;
  final ValueChanged<String> onServiceTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          for (final entry in const [
            (PawchiveFeed.popularDay, 'Popular'),
            (PawchiveFeed.recent, 'Recent'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.$2),
                selected: selectedSort == entry.$1,
                onSelected: (selected) {
                  if (selected) {
                    onSortSelected(entry.$1);
                  }
                },
              ),
            ),
          const SizedBox(width: 8),
          for (final service in const [
            ('Patreon', 'service:patreon'),
            ('Fanbox', 'service:fanbox'),
            ('Gumroad', 'service:gumroad'),
            ('SubscribeStar', 'service:subscribestar'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(service.$1),
                onPressed: () => onServiceTap(service.$2),
              ),
            ),
        ],
      ),
    );
  }
}
