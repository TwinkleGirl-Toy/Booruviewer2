// Package imports:
import 'package:booru_clients/joyreactor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/configs/config/types.dart';
import '../../core/ddos/handler/providers.dart';
import '../../core/http/client/providers.dart';
import '../../core/http/client/types.dart';
import '../../foundation/loggers.dart';

final joyreactorClientProvider =
    Provider.family<JoyreactorClient, BooruConfigAuth>((ref, config) {
      final dio = ref.watch(joyreactorDioProvider(config));

      return JoyreactorClient(
        dio: dio,
        baseUrl: config.url,
      );
    });

final joyreactorDioProvider = Provider.family<Dio, BooruConfigAuth>((
  ref,
  config,
) {
  final ddosProtectionHandler = ref.watch(httpDdosProtectionBypassProvider);
  final loggerService = ref.watch(loggerProvider);

  final dio = newDio(
    options: DioOptions(
      ddosProtectionHandler: ddosProtectionHandler,
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      loggerService: loggerService,
      networkProtocolInfo: ref.watch(
        defaultNetworkProtocolInfoProvider(config),
      ),
      baseUrl: config.url,
      proxySettings: config.proxySettings,
    ),
    additionalInterceptors: [
      SlidingWindowRateLimitInterceptor(
        config: const SlidingWindowRateLimitConfig(
          requestsPerWindow: 25,
          windowSizeMs: 60000,
          maxDelayMs: 8000,
        ),
      ),
    ],
  );

  dio.options.headers['Referer'] = config.url.endsWith('/')
      ? config.url
      : '${config.url}/';

  return dio;
});
