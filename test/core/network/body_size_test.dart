import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/key_value_entry.dart';
import 'package:relay/core/models/request_body.dart';
import 'package:relay/core/network/body_size.dart';

void main() {
  group('estimatedWireBytes', () {
    test('none/raw/urlencoded bodies are always zero — capped well under 1MB server-side', () {
      expect(estimatedWireBytes(const NoneBody()), 0);
      expect(estimatedWireBytes(const RawBody(raw: 'a large raw body would still be capped at 200KB server-side')), 0);
      expect(
        estimatedWireBytes(
          const UrlEncodedBody(
            entries: [KeyValueEntry(key: 'a', value: 'b')],
          ),
        ),
        0,
      );
    });

    test('a binary body is its base64 payload length', () {
      final body = BinaryBody(fileName: 'a.bin', dataBase64: 'a'.padRight(800000, 'a'));
      expect(estimatedWireBytes(body), 800000);
    });

    test('a form-data body sums only its file parts, not text parts', () {
      final body = FormDataBody(
        parts: [
          const FormTextPart(key: 'name', value: 'a text field, however long, is never counted'),
          FormFilePart(key: 'file1', fileName: 'a.png', dataBase64: 'a'.padRight(300000, 'a')),
          FormFilePart(key: 'file2', fileName: 'b.png', dataBase64: 'a'.padRight(500000, 'a')),
        ],
      );
      expect(estimatedWireBytes(body), 800000);
    });
  });

  test('bodySizeWarningThresholdBytes sits under role-node\'s 1MB REQUEST_BODY_LIMIT', () {
    expect(bodySizeWarningThresholdBytes, lessThan(1000000));
  });
}
