import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class ProfileStorageDataSource {
  static const String _bucket = 'gs://mesclainvest-dev.firebasestorage.app';

  final FirebaseStorage _storage;

  ProfileStorageDataSource({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instanceFor(bucket: _bucket);

  Future<String> uploadUserIcon({
    required String uid,
    required Uint8List bytes,
  }) async {
    final reference = _storage.ref().child('user-icons/$uid/profile.jpg');

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=3600',
      ),
    );

    return reference.getDownloadURL();
  }

  Future<void> deleteUserIcon({required String uid}) async {
    final reference = _storage.ref().child('user-icons/$uid/profile.jpg');

    try {
      await reference.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
