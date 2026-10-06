import '../../../core/constants/firestore_paths.dart';

/// A Drive or YouTube link a student pasted, understood.
class RoomLink {
  const RoomLink({required this.type, required this.url, this.id});

  /// RoomItemType.drive or RoomItemType.youtube.
  final String type;

  /// Cleaned-up https link (what we store).
  final String url;

  /// YouTube video id, or Drive file / folder id (null if unknown).
  final String? id;

  bool get isYoutube => type == RoomItemType.youtube;

  /// Parses a pasted link. Only Google Drive / Docs and YouTube links are
  /// allowed (the Resource Room isn't a general bookmark list). Null = not
  /// a supported link.
  static RoomLink? parse(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.startsWith('http')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    final clean = uri.replace(scheme: 'https').toString();

    if (host == 'youtu.be') {
      final id = uri.pathSegments.firstOrNull;
      return _youtube(clean, id);
    }
    if (host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com') {
      final segs = uri.pathSegments;
      final id =
          uri.queryParameters['v'] ??
          (segs.length >= 2 &&
                  const {'shorts', 'embed', 'live'}.contains(segs[0])
              ? segs[1]
              : null);
      // Playlists / channels are fine too (no single video id).
      return _youtube(clean, id);
    }
    if (host == 'drive.google.com' || host == 'docs.google.com') {
      final segs = uri.pathSegments;
      final dIndex = segs.indexOf('d');
      final folders = segs.indexOf('folders');
      final id =
          (dIndex >= 0 && dIndex + 1 < segs.length ? segs[dIndex + 1] : null) ??
          (folders >= 0 && folders + 1 < segs.length
              ? segs[folders + 1]
              : null) ??
          uri.queryParameters['id'];
      return RoomLink(type: RoomItemType.drive, url: clean, id: id);
    }
    return null;
  }

  static RoomLink _youtube(String url, String? id) => RoomLink(
    type: RoomItemType.youtube,
    url: url,
    id: id != null && RegExp(r'^[\w-]{11}$').hasMatch(id) ? id : null,
  );

  /// Address that shows a Drive item inside an embedded frame. Works when
  /// the file is shared as "Anyone with the link".
  static String drivePreviewUrl(String url) {
    final link = parse(url);
    final id = link?.id;
    if (link == null || id == null) return url;
    final uri = Uri.parse(link.url);
    if (uri.pathSegments.contains('folders')) {
      return 'https://drive.google.com/embeddedfolderview?id=$id#list';
    }
    if (uri.host == 'docs.google.com' && uri.pathSegments.isNotEmpty) {
      // docs / spreadsheets / presentation → /…/d/<id>/preview
      return 'https://docs.google.com/${uri.pathSegments.first}/d/$id/preview';
    }
    return 'https://drive.google.com/file/d/$id/preview';
  }
}
