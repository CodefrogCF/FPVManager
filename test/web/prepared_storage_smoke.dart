import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:web/web.dart' as web;

import 'package:fpvmanager/features/offline/offline_map_store_web.dart';
import 'package:fpvmanager/features/offline/offline_region_package.dart';

@JS('failNextPreparedWrite')
external void failNextPreparedWrite(JSString prefix);
void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final status = web.document.getElementById('status')!;
  try {
    final response = await web.window
        .fetch('/prepared-fixture.fpvregion'.toJS)
        .toDart;
    final bytes = (await response.arrayBuffer().toDart).toDart.asUint8List();
    final first = decodeRegionPackage(bytes), store = WebOfflineMapStore();
    await store.clear();
    await store.importPackage(first);
    check(
      (await store.regions()).single.packageId == first.region.packageId,
      'Initial browser publication',
    );
    check(
      (await store.tiles()).length == first.files.length,
      'Browser package completeness',
    );
    final archive = ZipDecoder().decodeBytes(bytes), next = Archive();
    for (final file in archive.files) {
      var body = file.readBytes()!;
      if (file.name == 'manifest.json') {
        final manifest = jsonDecode(utf8.decode(body));
        manifest['region']['name'] = 'Replacement';
        body = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
      }
      next.add(
        ArchiveFile.bytes(file.name, body)..compression = CompressionType.none,
      );
    }
    final second = decodeRegionPackage(ZipEncoder().encodeBytes(next));
    failNextPreparedWrite('prepared/${second.region.packageId}/'.toJS);
    var failed = false;
    try {
      await store.importPackage(second);
    } catch (_) {
      failed = true;
    }
    check(failed, 'Simulated browser quota failure must reject');
    check(
      (await store.regions()).single.packageId == first.region.packageId,
      'Old browser pointer retained',
    );
    check(
      (await store.tiles()).length == first.files.length,
      'Failed staging cleaned up',
    );
    final reopened = WebOfflineMapStore();
    check(
      (await reopened.regions()).single.packageId == first.region.packageId,
      'Browser restart reopens package',
    );
    await store.importPackage(second);
    check(
      (await reopened.regions()).single.packageId == second.region.packageId,
      'Recovery publishes replacement',
    );
    check(
      (await store.tiles()).length == second.files.length,
      'Successful replacement prunes old namespace',
    );
    await store.clear();
    check((await reopened.tiles()).isEmpty, 'Browser cleanup');
    status.textContent = 'PASS — browser package import, failed replacement, recovery, restart and cleanup';
  } catch (error, stack) {
    status.textContent = 'FAIL — $error\n$stack';
  }
}
