import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/features/auth/data/models/user_model.dart';

/// Who is signed in and what they may do, from one `/auth/me` call.
class Session {
  const Session({required this.user, required this.access});

  final UserModel user;
  final Access access;
}
