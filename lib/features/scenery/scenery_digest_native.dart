import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Future<String> sceneryDigest(Uint8List bytes) async =>
    sha256.convert(bytes).toString();
