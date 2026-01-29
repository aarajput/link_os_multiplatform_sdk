import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageUtils {
  /// Converts an image to ZPL format for Zebra printers
  ///
  /// [imageBytes] - The image data as Uint8List (PNG, JPEG, etc.)
  /// [threshold] - Threshold for converting to monochrome (0-255, default: 128)
  /// [labelWidth] - Optional: Width of the label in dots (defaults to image width)
  /// [labelHeight] - Optional: Height of the label in dots (defaults to image height)
  ///
  /// Returns ZPL commands as a String
  static String convertImageToZpl(
    Uint8List imageBytes, {
    int threshold = 128,
    int? labelWidth,
    int? labelHeight,
  }) {
    // Decode the image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Convert to grayscale and then to monochrome
    image = img.grayscale(image);

    final width = labelWidth ?? image.width;
    final height = labelHeight ?? image.height;

    // Resize if label dimensions are specified
    if (labelWidth != null || labelHeight != null) {
      image = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );
    }

    // Convert to ZPL hex format
    final hexData = _convertToZplHex(image, threshold);
    final bytesPerRow = (width + 7) ~/ 8;
    final totalBytes = bytesPerRow * height;

    // Build ZPL command
    final zpl = StringBuffer();
    zpl.write('^XA\n'); // Start of ZPL format
    zpl.write('^FO0,0\n'); // Field Origin (X,Y position)
    zpl.write(
      '^GFA,$totalBytes,$totalBytes,$bytesPerRow,$hexData\n',
    ); // Graphic Field (ASCII)
    zpl.write('^FS\n'); // End of field
    zpl.write('^XZ\n'); // End of ZPL format

    return zpl.toString();
  }

  /// Converts an image to hex string for ZPL
  static String _convertToZplHex(img.Image image, int threshold) {
    final width = image.width;
    final height = image.height;
    final bytesPerRow = (width + 7) ~/ 8;
    final hexData = StringBuffer();

    for (int y = 0; y < height; y++) {
      final rowBytes = List<int>.filled(bytesPerRow, 0);

      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        // Get luminance (brightness) of the pixel
        final luminance = pixel.r.toInt(); // Already grayscale, so r = g = b

        // If pixel is darker than threshold, set bit to 1 (black)
        if (luminance < threshold) {
          final byteIndex = x ~/ 8;
          final bitIndex = 7 - (x % 8);
          rowBytes[byteIndex] |= (1 << bitIndex);
        }
      }

      // Convert bytes to hex string
      for (final byte in rowBytes) {
        hexData.write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
      hexData.write('\n');
    }

    return hexData.toString();
  }

  /// Creates a simple ZPL command with custom positioning
  ///
  /// [imageBytes] - The image data as Uint8List
  /// [x] - X position in dots (default: 0)
  /// [y] - Y position in dots (default: 0)
  /// [threshold] - Threshold for converting to monochrome (0-255, default: 128)
  /// [labelWidth] - Optional: Width of the label in dots
  /// [labelHeight] - Optional: Height of the label in dots
  static String convertImageToZplWithPosition(
    Uint8List imageBytes, {
    int x = 0,
    int y = 0,
    int threshold = 128,
    int? labelWidth,
    int? labelHeight,
  }) {
    // Decode and process the image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    image = img.grayscale(image);

    final width = labelWidth ?? image.width;
    final height = labelHeight ?? image.height;

    if (labelWidth != null || labelHeight != null) {
      image = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );
    }

    final hexData = _convertToZplHex(image, threshold);
    final bytesPerRow = (width + 7) ~/ 8;
    final totalBytes = bytesPerRow * height;

    // Build ZPL with custom position
    final zpl = StringBuffer();
    zpl.write('^XA\n');
    zpl.write('^FO$x,$y\n');
    zpl.write('^GFA,$totalBytes,$totalBytes,$bytesPerRow,$hexData\n');
    zpl.write('^FS\n');
    zpl.write('^XZ\n');

    return zpl.toString();
  }
}
