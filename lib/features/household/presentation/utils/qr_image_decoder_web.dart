import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// True when the browser exposes the Shape Detection `BarcodeDetector` API.
bool get isWebQrImageDecodingSupported => globalContext.has('BarcodeDetector');

/// Returns the raw values of every QR code found in [bytes] (PNG/JPEG/...).
///
/// Throws when the browser cannot decode the image or lacks QR support, so
/// callers should show a generic "no code found" message on any error.
Future<List<String>> decodeQrFromImageBytes(Uint8List bytes) async {
  if (!isWebQrImageDecodingSupported) {
    throw UnsupportedError('BarcodeDetector is not available in this browser.');
  }

  final blob = globalContext
      .getProperty<JSFunction>('Blob'.toJS)
      .callAsConstructor<JSObject>([bytes.toJS].toJS);
  final bitmap = await globalContext
      .callMethod<JSPromise<JSObject>>('createImageBitmap'.toJS, blob)
      .toDart;

  try {
    final options = JSObject()..['formats'] = ['qr_code'.toJS].toJS;
    final detector = globalContext
        .getProperty<JSFunction>('BarcodeDetector'.toJS)
        .callAsConstructor<JSObject>(options);
    final barcodes = await detector
        .callMethod<JSPromise<JSArray<JSObject>>>('detect'.toJS, bitmap)
        .toDart;

    return [
      for (final barcode in barcodes.toDart)
        if (barcode.getProperty<JSString?>('rawValue'.toJS) case final raw?)
          raw.toDart,
    ];
  } finally {
    // Release the decoded pixels right away; screenshots can be large.
    bitmap.callMethod<JSAny?>('close'.toJS);
  }
}
