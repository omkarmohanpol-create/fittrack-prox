import 'package:supabase_flutter/supabase_flutter.dart';

/// True when Supabase answered and refused the request (bad data, RLS, a
/// server error). Anything else, such as a socket error or timeout, means the
/// request never got an answer, and the write is kept on the device to retry.
bool isServerRejection(Object e) =>
    e is PostgrestException ||
    e is AuthException ||
    e is StorageException ||
    e is FunctionException;
