import 'package:flutter_test/flutter_test.dart';
import 'package:prepnotes/core/utils/responsive.dart';

void main() {
  group('Breakpoints.sizeForWidth', () {
    test('mobile below 600', () {
      expect(Breakpoints.sizeForWidth(360), ScreenSize.mobile);
      expect(Breakpoints.sizeForWidth(599.9), ScreenSize.mobile);
    });

    test('tablet from 600 to 1024', () {
      expect(Breakpoints.sizeForWidth(600), ScreenSize.tablet);
      expect(Breakpoints.sizeForWidth(768), ScreenSize.tablet);
      expect(Breakpoints.sizeForWidth(1024), ScreenSize.tablet);
    });

    test('desktop above 1024', () {
      expect(Breakpoints.sizeForWidth(1025), ScreenSize.desktop);
      expect(Breakpoints.sizeForWidth(1920), ScreenSize.desktop);
    });
  });
}
