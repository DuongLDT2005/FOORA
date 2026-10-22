import 'dart:typed_data';

/// Native platforms decode picked images with mobile_scanner instead.
bool get isWebQrImageDecodingSupported => false;

/// Not available outside the web.
Future<List<String>> decodeQrFromImageBytes(Uint8List bytes) {
  throw UnsupportedError('QR image decoding via BarcodeDetector is web-only.');
}
