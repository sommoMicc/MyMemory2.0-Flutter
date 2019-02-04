import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageHelper {
  // Uso un'implementazione del design pattern Singleton trovata
  // su StackOverflow
  static final StorageHelper _singleton = StorageHelper._internal();
  factory StorageHelper() {
    return _singleton;
  }

  final FlutterSecureStorage _storage;
  final String _keyToken = "LetsMemoryAccessToken";
  final String _keyUsername = "LetsMemoryUsername";

  // Costruttore vero e proprio
  StorageHelper._internal() : _storage = FlutterSecureStorage();

  //Copia in memoria dei valori, per evitare continui accessi al "disco"
  String username;
  String token;

  Future<String> getToken() async {
    return this.token ?? await _storage.read(key: _keyToken);
  }

  void setToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
    this.token = token;
  }

  Future<String> getUsername() async {
    return this.username ?? await _storage.read(key: _keyUsername);
  }

  void setUsername(String username) async {
    await _storage.write(key: _keyUsername, value: username);
    this.username = username;
  }

  void logout() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyToken);
    this.username = null;
    this.token = null;
  }
}