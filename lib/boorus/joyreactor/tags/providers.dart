// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/configs/config/types.dart';
import '../../../core/tags/autocompletes/types.dart';
import '../client_provider.dart';

final joyreactorAutocompleteRepoProvider =
    Provider.family<AutocompleteRepository, BooruConfigAuth>((ref, config) {
      final client = ref.watch(joyreactorClientProvider(config));

      return AutocompleteRepositoryBuilder(
        autocomplete: (query) async {
          final text = query.text.trim();
          if (text.isEmpty) return const [];

          final dtos = await client.autocomplete(query: text);
          return dtos
              .where((e) => e.tag != null && e.tag!.isNotEmpty)
              .map(
                (e) => AutocompleteData(
                  label: e.label ?? e.tag!,
                  value: e.tag!.replaceAll(' ', '_'),
                  postCount: e.postCount,
                ),
              )
              .toList();
        },
      );
    });
