// Project imports:
import '../../core/boorus/booru/types.dart';
import '../../core/boorus/engine/types.dart';
import 'pawchive_builder.dart';
import 'pawchive_repository.dart';

BooruComponents createPawchive() => BooruComponents(
  parser: DefaultBooruParser(
    config: BooruYamlConfigs.pawchive,
  ),
  createBuilder: PawchiveBuilder.new,
  createRepository: (ref) => PawchiveRepository(ref: ref),
);
