import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class ProfileStorageDataSource {
  static const String _bucket = 'gs://mesclainvest-dev.firebasestorage.app';
  static const String _avatarsRoot = 'user-avatars';
  static const String _legacyRoot = 'user-icons';

  final FirebaseStorage _storage;

  ProfileStorageDataSource({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instanceFor(bucket: _bucket);

  Reference _avatarReference(String uid) {
    return _storage.ref().child('$_avatarsRoot/$uid/avatar.jpg');
  }

  Reference _legacyAvatarReference(String uid) {
    return _storage.ref().child('$_legacyRoot/$uid/profile.jpg');
  }

  Future<String> uploadUserIcon({
    required String uid,
    required Uint8List bytes,
  }) async {
    final reference = _avatarReference(uid);

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=3600',
      ),
    );

    await _deleteIfExists(_legacyAvatarReference(uid));

    return reference.getDownloadURL();
  }

  Future<void> deleteUserIcon({required String uid}) async {
    await _deleteIfExists(_avatarReference(uid));
    await _deleteIfExists(_legacyAvatarReference(uid));
  }

  Future<void> _deleteIfExists(Reference reference) async {
    try {
      await reference.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
