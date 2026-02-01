import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

/// Persistent storage using SharedPreferences
/// Data persists between app sessions
class SimpleStorage {
  static SimpleStorage? _instance;
  static SharedPreferences? _prefs;

  SimpleStorage._();

  static Future<SimpleStorage> getInstance() async {
    if (_instance == null || _prefs == null) {
      _instance = SimpleStorage._();
      _prefs = await SharedPreferences.getInstance();
      // Force reload to get latest data
      await _prefs!.reload();
      LoggerService.log('SimpleStorage initialized/reloaded');
    }
    return _instance!;
  }

  String? getString(String key) {
    final value = _prefs?.getString(key);
    LoggerService.log('SimpleStorage.getString($key) = $value');
    return value;
  }

  Future<void> setString(String key, String value) async {
    LoggerService.log('SimpleStorage.setString($key, $value)');
    await _prefs?.setString(key, value);
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }
}
