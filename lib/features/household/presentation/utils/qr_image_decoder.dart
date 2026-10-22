/// Decodes QR codes from a picked image on the web, where mobile_scanner's
/// `analyzeImage()` is unsupported. Uses the browser's native
/// `BarcodeDetector` (Chrome/Edge 83+, Safari 17+); other platforms get the
/// stub and keep using mobile_scanner.
library;

export 'qr_image_decoder_stub.dart'
    if (dart.library.js_interop) 'qr_image_decoder_web.dart';
