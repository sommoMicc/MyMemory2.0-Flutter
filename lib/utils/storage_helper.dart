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

  Future<String> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  void setToken(String token) {
    _storage.write(key: _keyToken, value: token);
  }

  Future<String> getUsername() async {
    return await _storage.read(key: _keyUsername);
  }

  void setUsername(String username) {
    _storage.write(key: _keyUsername, value: username);
  }
}