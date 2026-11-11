// Package imports:
import 'package:booru_clients/joyreactor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/configs/config/types.dart';
import '../../core/http/client/providers.dart';

final joyreactorClientProvider =
    Provider.family<JoyreactorClient, BooruConfigAuth>((ref, config) {
  final dio = ref.watch(defaultDioProvider(config));

  return JoyreactorClient(
    dio: dio,
    baseUrl: config.url,
  );
});
