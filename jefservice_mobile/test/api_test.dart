import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jefservice_mobile/core/jef_core.dart';

void main() {
  test('client OTP request matches backend payload', () async {
    final api = JefApi(
      () => null,
      baseUrlOverride: 'https://jef.example',
      client: MockClient((req) async {
        expect(req.url.path, '/api/register-client');
        expect(req.method, 'POST');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['phoneNumber'], '771234567');
        expect(body['latitude'], 14.7);
        return http.Response('{"success":true}', 200);
      }),
    );
    await api.sendOtp(
      '771234567',
      professional: false,
      registration: false,
      latitude: 14.7,
      longitude: -17.4,
    );
  });

  test('client OTP data contains token and clientId', () async {
    final api = JefApi(
      () => null,
      baseUrlOverride: 'https://jef.example',
      client: MockClient(
        (req) async => http.Response(
          '{"success":true,"data":{"token":"abc","clientId":42}}',
          200,
        ),
      ),
    );
    final result = await api.checkOtp(
      '771234567',
      '1234',
      professional: false,
      latitude: 14.7,
      longitude: -17.4,
    );
    expect(result['token'], 'abc');
    expect(result['clientId'], 42);
  });

  test('pagination and JWT are used for service listing', () async {
    var count = 0;
    final api = JefApi(
      () => 'jwt',
      baseUrlOverride: 'https://jef.example',
      client: MockClient((req) async {
        count++;
        expect(req.headers['Authorization'], 'Bearer jwt');
        if (req.url.queryParameters['page'] == '0') {
          return http.Response(
            jsonEncode(
              List.generate(
                100,
                (i) => {'id': i + 1, 'nom': 'Service', 'actif': true},
              ),
            ),
            200,
          );
        }
        return http.Response('[{"id":101,"nom":"Dernier"}]', 200);
      }),
    );
    expect((await api.services()).length, 101);
    expect(count, 2);
  });

  test('invalid mission transition is rejected locally', () async {
    var calls = 0;
    final api = JefApi(
      () => 'jwt',
      baseUrlOverride: 'https://jef.example',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.changeMissionStatus(9, 'TERMINEE', 'PAYEE', 5),
      throwsA(isA<JefError>()),
    );
    expect(calls, 0);
  });
}
