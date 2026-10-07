import 'dart:io';

import 'package:aisat_fap/models/pram_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every PRAM announcement has a bundled recording', () {
    for (final item in pramLibrary) {
      final f = File('assets/pram/${item.id}.mp3');
      expect(f.existsSync(), isTrue, reason: '${item.id}.mp3 missing');
      expect(f.lengthSync(), greaterThan(10000));
    }
  });
}
