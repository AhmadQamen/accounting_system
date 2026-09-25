import 'dart:async';

import 'package:accounting_system/core/configs/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DeviceKeyStorage {
  Future<String> getOrCreate();
}

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FlutterSecureValueStore implements SecureValueStore {
  FlutterSecureValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class SecureDeviceKeyStorage implements DeviceKeyStorage {
  SecureDeviceKeyStorage({SecureValueStore? store})
    : _store = store ?? FlutterSecureValueStore();

  static const _key = 'accounting.device.key.v1';
  final SecureValueStore _store;
  Future<String>? _inFlight;

  @override
  Future<String> getOrCreate() {
    return _inFlight ??= _readOrCreate().whenComplete(() => _inFlight = null);
  }

  Future<String> _readOrCreate() async {
    final existing = await _store.read(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = uuid.v4().toLowerCase();
    await _store.write(_key, generated);
    return generated;
  }
}
