import 'base_camp_map_export_stub.dart'
    if (dart.library.html) 'base_camp_map_export_web.dart'
    as platform;

void exportBaseCampMapJson(String json) => platform.exportBaseCampMapJson(json);
