import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/max_client.dart';

void main() {
  group('parseDohAnswer', () {
    test('Cloudflare dns-json: первый A-record', () {
      const body =
          '{"Status":0,"Answer":[{"name":"api.oneme.ru","type":1,"TTL":60,'
          '"data":"212.109.195.59"}]}';
      expect(parseDohAnswer(body), '212.109.195.59');
    });

    test('пропускает CNAME (type 5), берёт A (type 1)', () {
      const body = '{"Answer":[{"type":5,"data":"cname.example"},'
          '{"type":1,"data":"1.2.3.4"}]}';
      expect(parseDohAnswer(body), '1.2.3.4');
    });

    test('нет Answer -> null', () {
      expect(parseDohAnswer('{"Status":3}'), isNull);
    });

    test('невалидный JSON -> null', () {
      expect(parseDohAnswer('not json'), isNull);
    });
  });
}
