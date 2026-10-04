import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/constants/storage_paths.dart';

void main() {
  test('Firestore paths match the data model', () {
    expect(FirestorePaths.user('u1'), 'users/u1');
    expect(FirestorePaths.entitlement('u1', 'n1'), 'users/u1/entitlements/n1');
    expect(FirestorePaths.studySessions('u1'), 'users/u1/studySessions');
    expect(FirestorePaths.recentlyViewed('u1'), 'users/u1/recentlyViewed');
    expect(FirestorePaths.note('n1'), 'notes/n1');
    expect(FirestorePaths.order('o1'), 'orders/o1');
    expect(FirestorePaths.statsGlobal, 'stats/global');
  });

  test('Storage paths match the storage layout', () {
    expect(StoragePaths.notePdf('n1'), 'notes_private/n1/file.pdf');
    expect(StoragePaths.noteThumbnail('n1'), 'notes_public/n1/thumbnail.jpg');
    expect(StoragePaths.notePreview('n1'), 'notes_public/n1/preview.pdf');
    expect(StoragePaths.resourceFile('r1', 'a.pdf'), 'resources/r1/a.pdf');
    expect(StoragePaths.avatar('u1'), 'avatars/u1/avatar.jpg');
  });
}
