// Conditional export for AvatarView
export 'avatar_view_stub.dart'
    if (dart.library.io) 'avatar_view_mobile.dart'
    if (dart.library.html) 'avatar_view_web.dart';
