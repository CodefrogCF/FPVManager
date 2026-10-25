import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

const backupMaxBytes = 64 * 1024 * 1024;
const backupMaxRows = 100000;
const _headerLength = 37;
final _magic = ascii.encode('FPVBK001');

void validateBackupJsonText(String text, {bool expectList = false}) {
  if (text.length > 4 * 1024 * 1024) {
    throw const FormatException('Stored planning JSON exceeds limit');
  }
  var depth = 0, items = 0, quoted = false, escaped = false;
  for (final c in text.codeUnits) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (c == 92) {
        escaped = true;
      } else if (c == 34) {
        quoted = false;
      }
    } else if (c == 34) {
      quoted = true;
    } else if (c == 91 || c == 123) {
      if (++depth > 20) {
        throw const FormatException('Stored planning JSON nesting limit');
      }
    } else if (c == 93 || c == 125) {
      depth--;
    } else if (c == 44 && ++items > 100000) {
      throw const FormatException('Stored planning JSON item limit');
    }
  }
  final json = jsonDecode(text);
  if (expectList ? json is! List : json is! Map) {
    throw const FormatException('Invalid stored planning JSON');
  }
}

class BackupEncodeJob {
  const BackupEncodeJob(this.payload, this.password);
  final Uint8List payload;
  final String? password;
}

class BackupDecodeJob {
  const BackupDecodeJob(this.bytes, this.password);
  final Uint8List bytes;
  final String? password;
}

bool isEncryptedBackup(Uint8List bytes) {
  if (bytes.length < _headerLength + 16 ||
      bytes.length > backupMaxBytes ||
      !_equal(bytes.sublist(0, 8), _magic) ||
      bytes[8] > 1) {
    throw const FormatException('Unsupported, truncated or oversized backup');
  }
  return bytes[8] == 1;
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}

Future<SecretKey> _key(String password, List<int> salt) {
  if (password.isEmpty || password.length > 1024) {
    throw const FormatException('A password of 1–1024 characters is required');
  }
  return Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);
}

/// Fixed parameters bound KDF work; the entire versioned header is authenticated.
Future<Uint8List> encodeBackup(BackupEncodeJob job) async {
  if (job.payload.length > backupMaxBytes - 128) {
    throw const FormatException('Backup exceeds the 64 MiB limit');
  }
  final encrypted = job.password != null;
  final header = Uint8List(_headerLength)..setRange(0, 8, _magic);
  header[8] = encrypted ? 1 : 0;
  if (encrypted) {
    final random = Random.secure();
    for (var i = 9; i < header.length; i++) {
      header[i] = random.nextInt(256);
    }
    final key = await _key(job.password!, header.sublist(9, 25));
    try {
      final box = await AesGcm.with256bits().encrypt(
        job.payload,
        secretKey: key,
        nonce: header.sublist(25),
        aad: header,
      );
      return (BytesBuilder(copy: false)
            ..add(header)
            ..add(box.cipherText)
            ..add(box.mac.bytes))
          .takeBytes();
    } finally {
      key.destroy();
    }
  }
  return (BytesBuilder(copy: false)
        ..add(header)
        ..add(hash.sha256.convert(job.payload).bytes)
        ..add(job.payload))
      .takeBytes();
}

Future<Map<String, dynamic>> decodeBackup(BackupDecodeJob job) async {
  final encrypted = isEncryptedBackup(job.bytes);
  final header = Uint8List.sublistView(job.bytes, 0, _headerLength);
  List<int> payload;
  if (encrypted) {
    final key = await _key(job.password ?? '', header.sublist(9, 25));
    try {
      payload = await AesGcm.with256bits().decrypt(
        SecretBox(
          Uint8List.sublistView(
            job.bytes,
            _headerLength,
            job.bytes.length - 16,
          ),
          nonce: header.sublist(25),
          mac: Mac(job.bytes.sublist(job.bytes.length - 16)),
        ),
        secretKey: key,
        aad: header,
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException('Wrong password or damaged backup');
    } finally {
      key.destroy();
    }
  } else {
    if (job.bytes.length < _headerLength + 32 ||
        header.skip(9).any((b) => b != 0)) {
      throw const FormatException('Invalid backup header');
    }
    payload = Uint8List.sublistView(job.bytes, _headerLength + 32);
    final digest = hash.sha256.convert(payload).bytes;
    if (!_equal(digest, job.bytes.sublist(_headerLength, _headerLength + 32))) {
      throw const FormatException('Backup checksum mismatch');
    }
  }
  // Bound nesting before allocating a JSON object graph. Strings may contain
  // escaped braces; none of their contents influence the nesting counter.
  var depth = 0,
      containers = 0,
      separators = 0,
      rowMaps = 0,
      quoted = false,
      escaped = false;
  for (final b in payload) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (b == 92) {
        escaped = true;
      } else if (b == 34) {
        quoted = false;
      }
    } else if (b == 34) {
      quoted = true;
    } else if (b == 123 || b == 91) {
      if (++depth > 12) {
        throw const FormatException('Backup nesting limit exceeded');
      }
      if (++containers > backupMaxRows * 4 + 128 ||
          b == 123 && depth == 4 && ++rowMaps > backupMaxRows) {
        throw const FormatException('Backup object/row limit exceeded');
      }
    } else if (b == 125 || b == 93) {
      depth--;
    } else if (b == 44 && ++separators > backupMaxRows * 64) {
      throw const FormatException('Backup complexity limit exceeded');
    }
  }
  final decoded = jsonDecode(utf8.decode(payload));
  if (decoded is! Map<String, dynamic> ||
      decoded['format'] != 'fpvmanager-backup' ||
      decoded['version'] != 1 ||
      decoded['schema'] is! int ||
      (decoded['schema'] as int) < 1 ||
      decoded['tables'] is! Map<String, dynamic> ||
      decoded['createdAt'] is! String ||
      DateTime.tryParse(decoded['createdAt'] as String) == null) {
    throw const FormatException('Unsupported backup format or version');
  }
  var rows = 0;
  for (final value in (decoded['tables'] as Map).values) {
    if (value is! List ||
        (rows += value.length) > backupMaxRows ||
        value.any((row) => row is! Map<String, dynamic>)) {
      throw const FormatException('Invalid backup table or row limit');
    }
  }
  return decoded;
}
