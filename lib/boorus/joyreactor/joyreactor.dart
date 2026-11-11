// Project imports:
import '../../core/boorus/booru/types.dart';
import '../../core/boorus/engine/types.dart';
import 'joyreactor_builder.dart';
import 'joyreactor_repository.dart';

BooruComponents createJoyreactor() => BooruComponents(
  parser: DefaultBooruParser(
    config: BooruYamlConfigs.joyreactor,
  ),
  createBuilder: JoyreactorBuilder.new,
  createRepository: (ref) => JoyreactorRepository(ref: ref),
);
