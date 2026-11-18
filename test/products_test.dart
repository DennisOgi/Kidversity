import 'package:flutter_test/flutter_test.dart';
import 'package:kidversity/data/products.dart';
import 'package:kidversity/router/navigation.dart';

void main() {
  test('products parse from the server and ignore unknown ids', () {
    expect(Product.parse(['mandarin', 'labs', 'exams', null]), {
      Product.mandarin,
      Product.labs,
    });
    expect(Product.parse(null), isEmpty);
  });

  test('student pages map to the product they need', () {
    expect(productForPath('/student/mandarin'), Product.mandarin);
    expect(productForPath('/student/foundation/abc'), Product.mandarin);
    expect(productForPath('/student/maths?level=3'), Product.maths);
    expect(productForPath('/student/labs/pendulum'), Product.labs);
    expect(productForPath('/student/play'), isNull);
    expect(productForPath('/student/path'), isNull);
  });
}
