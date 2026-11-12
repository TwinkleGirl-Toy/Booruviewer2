// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/tags/autocompletes/types.dart';
import '../client_provider.dart';

final pawchiveAutocompleteRepoProvider =
    Provider.family<AutocompleteRepository, BooruConfigAuth>((ref, config) {
      final client = ref.watch(pawchiveClientProvider(config));

      return AutocompleteRepositoryBuilder(
        autocomplete: (query) async {
          final text = query.text.trim();
          if (text.isEmpty) return const [];

          final dtos = await client.autocomplete(query: text);
          return dtos
              .where((e) => e.name.isNotEmpty)
              .map(
                (e) => AutocompleteData(
                  label: e.name,
                  value: e.normalizedName,
                  category: e.category,
                  postCount: e.count,
                ),
              )
              .toList();
        },
      );
    });
