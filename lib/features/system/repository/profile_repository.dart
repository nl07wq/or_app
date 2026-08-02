import '../models/profile_model.dart';

abstract interface class ProfileRepository {
  Future<ProfileModel?> findCurrent();

  Future<ProfileModel> save(ProfileModel profile);

  Future<void> deleteCurrent();
}
