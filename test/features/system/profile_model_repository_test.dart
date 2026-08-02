import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/system/data/profile_nationalities.dart';
import 'package:or_app/features/system/models/profile_model.dart';
import 'package:or_app/features/system/repository/indexed_db_profile_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('nationality source metadata and all formal candidates are exact', () {
    expect(
      ProfileNationalities.sourceUrl,
      'https://www.mofa.go.jp/mofaj/area/index.html',
    );
    expect(ProfileNationalities.verifiedOn, '2026-08-03');
    expect(ProfileNationalities.countries, hasLength(196));
    expect(ProfileNationalities.otherRegions, hasLength(7));
    expect(ProfileNationalities.values, hasLength(203));
    expect(ProfileNationalities.values.toSet(), hasLength(203));
    expect(ProfileNationalities.values.where((value) => value == '日本'), ['日本']);
    final japanIndex = ProfileNationalities.countries.indexOf('日本');
    expect(ProfileNationalities.countries[japanIndex - 1], 'ニジェール共和国');
    expect(ProfileNationalities.countries[japanIndex + 1], 'ニュージーランド');
    expect(ProfileNationalities.otherRegions, [
      '北朝鮮',
      '台湾',
      'パレスチナ',
      '香港',
      'マカオ',
      '北極',
      '南極',
    ]);
  });

  test('Profile validates, normalizes and preserves nulls', () {
    final profile = ProfileModel.validated(
      userName: '  早坂  一馬  ',
      heightCm: 175.5,
      gender: ProfileGender.male,
      nationality: '日本',
    );
    expect(profile.userName, '早坂  一馬');
    expect(profile.heightCm, 175.5);
    expect(const ProfileModel().toBackupRecord(), {
      'version': 1,
      'userName': null,
      'heightCm': null,
      'gender': null,
      'nationality': null,
    });
  });

  test('Profile rejects invalid height, gender and nationality', () {
    expect(
      () => ProfileModel.validated(heightCm: 175.55),
      throwsFormatException,
    );
    expect(() => ProfileModel.validated(heightCm: 0), throwsFormatException);
    expect(
      () => ProfileModel.validated(gender: 'unknown'),
      throwsFormatException,
    );
    expect(
      () => ProfileModel.validated(nationality: '架空国'),
      throwsFormatException,
    );
  });

  test(
    'Repository saves with read-back, reloads and deletes current',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbProfileRepository(
        database,
        clock: () => DateTime.utc(2026, 8, 3, 12),
      );
      expect(await repository.findCurrent(), isNull);

      final saved = await repository.save(
        ProfileModel.validated(
          userName: ' Kazuma ',
          heightCm: 175,
          gender: ProfileGender.preferNotToSay,
          nationality: '日本',
        ),
      );
      expect(saved.userName, 'Kazuma');
      expect(saved.heightCm, 175);
      expect(saved.createdAt, DateTime.utc(2026, 8, 3, 12));
      expect(
        database.rawRecord(IndexedDbStoreNames.profileRecords, 'current'),
        isNotNull,
      );
      expect((await repository.findCurrent())!.nationality, '日本');

      await repository.deleteCurrent();
      expect(await repository.findCurrent(), isNull);
    },
  );
}
