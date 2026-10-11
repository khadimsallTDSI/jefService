import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const jefPrimary = Color(0xFF079B8F);
const jefOrange = Color(0xFFFF8500);
const jefPale = Color(0xFFDFF7F4);
const jefDark = Color(0xFF046B64);

class JefError implements Exception {
  const JefError(this.message, [this.code]);
  final String message;
  final int? code;
  @override String toString() => message;
}
Map<String, dynamic> jefMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> jefList(dynamic value) =>
    value is List ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList() : [];
int? jefId(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
double? jefNumber(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
String jefText(dynamic value) => value?.toString() ?? '';
String jefMoney(dynamic value) => jefNumber(value) == null ? 'À convenir' : jefNumber(value)!.toStringAsFixed(0) + ' FCFA';
String jefStatus(dynamic value) => {
  'EN_ATTENTE':'En attente', 'ACCEPTEE':'Acceptée', 'EN_COURS':'En cours',
  'TERMINEE':'Terminée', 'PAYEE':'Payée'
}[jefText(value)] ?? 'Non défini';

class JefApi {
  JefApi(this.tokenProvider, {http.Client? client, String? baseUrlOverride})
      : client = client ?? http.Client(),
        _baseUrl = baseUrlOverride ?? baseUrl;
  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const timeout = Duration(seconds: 20);
  final String? Function() tokenProvider;
  final http.Client client;
  final String _baseUrl;

  Uri _url(String path, [Map<String, String>? query]) {
    final host = _baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final parsed = Uri.tryParse(host + path);
    if (host.isEmpty || parsed == null || !parsed.hasAuthority ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw const JefError('Adresse API absente ou invalide. Configurez API_BASE_URL.');
    }
    if (kReleaseMode && parsed.scheme != 'https') {
      throw const JefError('HTTPS est obligatoire en production.');
    }
    return parsed.replace(queryParameters: query);
  }

  Future<dynamic> call(String method, String path, {
    Map<String, String>? query, Object? body, bool auth = true,
  }) async {
    final token = tokenProvider();
    if (auth && (token == null || token.isEmpty)) {
      throw const JefError('Veuillez vous connecter.', 401);
    }
    try {
      final request = http.Request(method, _url(path, query));
      request.headers['Accept'] = 'application/json';
      if (auth) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = method == 'PATCH'
            ? 'application/merge-patch+json' : 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(
          await client.send(request).timeout(timeout));
      dynamic decoded;
      try { decoded = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes)); }
      catch (_) { decoded = null; }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (jefMap(decoded)['success'] == false) {
          throw const JefError('Le serveur a refusé la demande.');
        }
        return decoded;
      }
      if (response.statusCode == 401) throw const JefError('Session expirée ou connexion refusée.', 401);
      if (response.statusCode == 403) throw const JefError('Action non autorisée par le serveur.', 403);
      if (response.statusCode == 404) throw const JefError('Ressource introuvable.', 404);
      final value = jefMap(decoded);
      if (response.statusCode == 400) {
        if (jefText(value['code']) == 'OTP_INVALID' ||
            jefText(value['message']).toLowerCase().contains('otp invalide')) {
          throw const JefError('Code OTP incorrect ou expiré.', 400);
        }
        throw const JefError('Vérifiez les informations saisies.', 400);
      }
      throw JefError('Erreur du serveur. Réessayez plus tard.', response.statusCode);
    } on JefError { rethrow; }
    on TimeoutException { throw const JefError('Le serveur ne répond pas. Réessayez.'); }
    catch (_) { throw const JefError('Erreur réseau. Vérifiez la connexion et le serveur.'); }
  }

  Future<void> sendOtp(String phone, {required bool professional, required bool registration,
    required double latitude, required double longitude}) async {
    if (professional && !registration) {
      await call('POST', '/api/login-otp-request', auth: false, body: {'phoneNumber': phone});
    } else {
      await call('POST', '/api/register-client', auth: false, body: {
        'phoneNumber': phone, 'latitude': latitude, 'longitude': longitude,
      });
    }
  }

  Future<Map<String, dynamic>> checkOtp(String phone, String otp, {
    required bool professional, required double latitude, required double longitude,
    Map<String, dynamic>? registration,
  }) async {
    final path = registration != null ? '/api/technicien/validate-otp'
        : professional ? '/api/login-otp-validate' : '/api/validate-otp';
    final response = jefMap(await call('POST', path, auth: false, body: {
      'phoneNumber': phone, 'otp': otp,
      'latitude': latitude, 'longitude': longitude,
      if (registration != null) ...registration,
    }));
    return professional && registration == null ? response : jefMap(response['data']);
  }

  Future<Map<String, dynamic>> account() async => jefMap(await call('GET', '/api/account'));
  Future<void> updateAccount(Map<String, dynamic> value) async {
    await call('POST', '/api/account', body: value);
  }

  Future<int?> profileId(int userId, {required bool professional}) async {
    final type = professional ? 'techniciens' : 'clients';
    final found = jefList(await call('GET', '/api/$type', query: {
      'userId.equals': '$userId', 'page': '0', 'size': '1',
    }));
    return found.isEmpty ? null : jefId(found.first['id']);
  }

  Future<List<Map<String, dynamic>>> paged(String path, Map<String, String> filters) async {
    const pageSize = 100;
    final all = <Map<String, dynamic>>[];
    for (var page = 0; page < 10; page++) {
      final batch = jefList(await call('GET', path, query: {
        ...filters, 'page': '$page', 'size': '$pageSize',
      }));
      all.addAll(batch);
      if (batch.length < pageSize) break;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> services() =>
      paged('/api/service-jefs', {'actif.equals': 'true', 'sort': 'nom,asc'});
  Future<List<Map<String, dynamic>>> technicians(int serviceId) =>
      paged('/api/techniciens', {
        'serviceJefsId.equals': '$serviceId', 'disponible.equals': 'true',
        'statutValidation.equals': 'VALIDE',
      });
  Future<Map<String, dynamic>> technician(int id) async =>
      jefMap(await call('GET', '/api/techniciens/$id'));
  Future<void> availability(int technicianId, bool available) async {
    final tech = await technician(technicianId);
    if (tech['statutValidation'] != 'VALIDE') {
      throw const JefError('Votre compte professionnel doit être validé.');
    }
    await call('PATCH', '/api/techniciens/$technicianId',
        body: {'id': technicianId, 'disponible': available});
  }
  Future<List<Map<String, dynamic>>> missions(int id, {required bool professional}) =>
      paged('/api/missions', {
        (professional ? 'technicienId.equals' : 'clientId.equals'): '$id',
        'sort': 'dateCreation,desc',
      });
  Future<Map<String, dynamic>> createMission({
    required int clientId, required int serviceId, required String description,
    required double latitude, required double longitude, int? technicianId,
    double? budget,
  }) async => jefMap(await call('POST', '/api/missions', body: {
    'description': description,
    'latitude': latitude, 'longitude': longitude,
    'statut': 'EN_ATTENTE',
    'dateCreation': DateTime.now().toUtc().toIso8601String(),
    'client': {'id': clientId}, 'serviceJef': {'id': serviceId},
    if (technicianId != null) 'technicien': {'id': technicianId},
    if (budget != null) 'prixPropose': budget,
  }));
  Future<void> changeMissionStatus(int id, String expected, String next, int professionalId) async {
    const steps = {'EN_ATTENTE': 'ACCEPTEE', 'ACCEPTEE': 'EN_COURS', 'EN_COURS': 'TERMINEE'};
    if (steps[expected] != next) throw const JefError('Transition de mission interdite.');
    final mission = jefMap(await call('GET', '/api/missions/$id'));
    if (jefId(jefMap(mission['technicien'])['id']) != professionalId) {
      throw const JefError('Cette mission ne vous est pas attribuée.', 403);
    }
    if (mission['statut'] != expected) throw const JefError('La mission a changé. Actualisez la liste.');
    final tech = await technician(professionalId);
    if (tech['statutValidation'] != 'VALIDE') throw const JefError('Profil non validé.');
    await call('PATCH', '/api/missions/$id', body: {'id': id, 'statut': next});
  }
  Future<List<Map<String, dynamic>>> documents(int professionalId) =>
      paged('/api/documents', {'technicienId.equals': '$professionalId'});
  Future<void> uploadDocuments(int professionalId, String cni, String diploma) async {
    final token = tokenProvider();
    if (token == null) throw const JefError('Veuillez vous connecter.', 401);
    try {
      final req = http.MultipartRequest('POST', _url('/api/technicien/$professionalId/documents'));
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath('cni', cni));
      req.files.add(await http.MultipartFile.fromPath('DIPLOME', diploma));
      final res = await http.Response.fromStream(await client.send(req).timeout(timeout));
      if (res.statusCode == 401) throw const JefError('Session expirée.', 401);
      if (res.statusCode == 403) throw const JefError('Dépôt de documents non autorisé.', 403);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw const JefError('L’envoi des documents a échoué.');
      }
      final payload = jefMap(jsonDecode(res.body));
      if (payload['success'] == false) throw const JefError('Le serveur a refusé les fichiers.');
    } on JefError { rethrow; }
    on TimeoutException { throw const JefError('Envoi expiré. Réessayez.'); }
    catch (_) { throw const JefError('Impossible de transmettre les documents.'); }
  }
}

enum JefRole { client, technician }

class JefSession extends ChangeNotifier {
  JefSession() : api = JefApi(() => _token);
  static String? _token;
  final JefApi api;
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  Map<String, dynamic> accountData = {};
  JefRole role = JefRole.client;
  int? profileId;
  bool ready = false;
  String? startupError;
  bool get loggedIn => _token != null && _token!.isNotEmpty;

  Future<void> start() async {
    ready = false;
    startupError = null;
    notifyListeners();
    try {
      _token = await storage.read(key: 'jef_token');
      role = (await storage.read(key: 'jef_role')) == 'technician'
          ? JefRole.technician : JefRole.client;
      if (loggedIn) {
        if (JefApi.baseUrl.isEmpty) {
          startupError = 'Configurez l\'adresse du serveur (API_BASE_URL).';
        } else {
          try {
            await refresh();
          } on JefError catch (error) {
            if (error.code == 401 || error.code == 403) {
              await logout();
            } else {
              startupError = error.message;
            }
          }
        }
      }
    } catch (_) {
      _token = null;
      accountData = {};
      profileId = null;
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> signIn(String token, JefRole selected) async {
    startupError = null;
    _token = token;
    role = selected;
    try {
      await refresh();
      await storage.write(key: 'jef_token', value: token);
      await storage.write(key: 'jef_role', value: selected.name);
    } catch (_) {
      _token = null;
      accountData = {};
      profileId = null;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    final identity = await api.account();
    final permissions = identity['authorities'];
    final requiredRole = role == JefRole.client ? 'ROLE_CLIENT' : 'ROLE_TECHNICIEN';
    if (permissions is! List || !permissions.contains(requiredRole)) {
      throw const JefError('Le compte ne possède pas le rôle demandé.', 403);
    }
    if (jefText(identity['login']).isEmpty) throw const JefError('Profil incomplet.');
    accountData = identity;
    final userId = jefId(identity['id']);
    profileId = userId == null ? null : await api.profileId(userId,
        professional: role == JefRole.technician);
    notifyListeners();
  }

  Future<void> logout() async {
    startupError = null;
    _token = null; profileId = null; accountData = {}; role = JefRole.client;
    await storage.delete(key: 'jef_token');
    await storage.delete(key: 'jef_role');
    notifyListeners();
  }
}

Future<Position> jefPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const JefError('Activez la localisation du téléphone.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const JefError('Autorisez la localisation dans les réglages du téléphone.');
  }
  try {
    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
        .timeout(const Duration(seconds: 20));
  } catch (_) { throw const JefError('Position indisponible. Réessayez.'); }
}
