// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/tags/autocompletes/types.dart';
import '../../../core/configs/config/types.dart';
import '../client_provider.dart';

final joyreactorAutocompleteRepoProvider =
    Provider.family<AutocompleteRepository, BooruConfigAuth>((ref, config) {
  final client = ref.watch(joyreactorClientProvider(config));

  return AutocompleteRepositoryBuilder(
    autocomplete: (query) async {
      final tagDtos = await client.searchTags(query: query.text);

      return tagDtos
          .map(
            (e) => AutocompleteData(
              label: e.name,
              value: e.normalizedName,
              postCount: e.count,
            ),
          )
          .toList();
    },
  );
});
