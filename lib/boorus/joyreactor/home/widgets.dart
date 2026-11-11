// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:booru_clients/joyreactor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/providers.dart';
import '../../../core/home/widgets.dart';
import '../../../core/posts/listing/widgets.dart';
import '../posts/providers.dart';
import '../posts/types.dart';

final joyreactorSelectedFeedProvider =
    StateProvider.autoDispose<JoyreactorFeed>((ref) => JoyreactorFeed.good);

class JoyreactorHomePage extends ConsumerWidget {
  const JoyreactorHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watchConfigSearch;
    final postRepo = ref.watch(joyreactorPostRepoProvider(config));
    final selectedFeed = ref.watch(joyreactorSelectedFeedProvider);

    return PostScope<JoyreactorPost>(
      fetcher: (page) => postRepo.getPosts('feed:${selectedFeed.name}', page),
      builder: (context, controller) => Column(
        children: [
          _JoyreactorFeedSelectorBar(
            selectedFeed: selectedFeed,
            onFeedChanged: (newFeed) {
              ref.read(joyreactorSelectedFeedProvider.notifier).state = newFeed;
              controller.refresh();
            },
          ),
          Expanded(
            child: PostGrid<JoyreactorPost>(
              controller: controller,
              sliverHeaders: [
                SliverHomeSearchBar(onSearch: controller.refresh),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JoyreactorFeedSelectorBar extends StatelessWidget {
  const _JoyreactorFeedSelectorBar({
    required this.selectedFeed,
    required this.onFeedChanged,
  });

  final JoyreactorFeed selectedFeed;
  final ValueChanged<JoyreactorFeed> onFeedChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          for (final feed in JoyreactorFeed.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(feed.displayName),
                selected: selectedFeed == feed,
                onSelected: (selected) {
                  if (selected && selectedFeed != feed) onFeedChanged(feed);
                },
              ),
            ),
        ],
      ),
    );
  }
}
