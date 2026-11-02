import 'base_camp_asset_import_stub.dart'
    if (dart.library.html) 'base_camp_asset_import_web.dart';

export 'base_camp_asset_import_stub.dart'
    if (dart.library.html) 'base_camp_asset_import_web.dart';

Future<BaseCampImportedFile?> pickBaseCampAssetFile() =>
    platformPickBaseCampAssetFile();
