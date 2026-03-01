import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Claves de preferencias para la configuración de la app.
abstract class SettingsKeys {
  static const String themeMode = 'theme_mode'; // 0=system, 1=light, 2=dark
  static const String textScale = 'text_scale'; // 1.0, 1.15, 1.3
  static const String autoSyncEnabled = 'auto_sync_enabled';
  static const String syncIntervalMinutes =
      'sync_interval_minutes'; // 15, 30, 60
  static const String wifiOnlySync = 'wifi_only_sync';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String syncCompleteNotifications = 'sync_complete_notifications';
  static const String appLockEnabled =
      'app_lock_enabled'; // para futuro PIN/biometría

  /// Cédula del habitante vinculada al perfil del usuario (por Firebase UID).
  static String linkedHabitanteCedulaKey(String uid) =>
      'profile_habitante_cedula_$uid';

  /// Módulo Formación (tipo Classroom): true = visible en Home; false = deshabilitado.
  static const String formacionModuleEnabled = 'formacion_module_enabled';
}

/// Servicio para leer y guardar preferencias de la aplicación.
class SettingsService {
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- Tema ---
  static Future<int> getThemeMode() async {
    final p = await _instance;
    return p.getInt(SettingsKeys.themeMode) ?? 0;
  }

  static Future<void> setThemeMode(int value) async {
    final p = await _instance;
    await p.setInt(SettingsKeys.themeMode, value);
  }

  // --- Escala de texto ---
  static Future<double> getTextScale() async {
    final p = await _instance;
    return p.getDouble(SettingsKeys.textScale) ?? 1.0;
  }

  static Future<void> setTextScale(double value) async {
    final p = await _instance;
    await p.setDouble(SettingsKeys.textScale, value);
  }

  // --- Sincronización ---
  static Future<bool> getAutoSyncEnabled() async {
    final p = await _instance;
    return p.getBool(SettingsKeys.autoSyncEnabled) ?? false;
  }

  static Future<void> setAutoSyncEnabled(bool value) async {
    final p = await _instance;
    await p.setBool(SettingsKeys.autoSyncEnabled, value);
  }

  static Future<int> getSyncIntervalMinutes() async {
    final p = await _instance;
    return p.getInt(SettingsKeys.syncIntervalMinutes) ?? 30;
  }

  static Future<void> setSyncIntervalMinutes(int value) async {
    final p = await _instance;
    await p.setInt(SettingsKeys.syncIntervalMinutes, value);
  }

  static Future<bool> getWifiOnlySync() async {
    final p = await _instance;
    return p.getBool(SettingsKeys.wifiOnlySync) ?? false;
  }

  static Future<void> setWifiOnlySync(bool value) async {
    final p = await _instance;
    await p.setBool(SettingsKeys.wifiOnlySync, value);
  }

  // --- Notificaciones ---
  static Future<bool> getNotificationsEnabled() async {
    final p = await _instance;
    return p.getBool(SettingsKeys.notificationsEnabled) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool value) async {
    final p = await _instance;
    await p.setBool(SettingsKeys.notificationsEnabled, value);
  }

  static Future<bool> getSyncCompleteNotifications() async {
    final p = await _instance;
    return p.getBool(SettingsKeys.syncCompleteNotifications) ?? true;
  }

  static Future<void> setSyncCompleteNotifications(bool value) async {
    final p = await _instance;
    await p.setBool(SettingsKeys.syncCompleteNotifications, value);
  }

  // --- Bloqueo de app (preferencia; lógica de PIN/biometría aparte) ---
  static Future<bool> getAppLockEnabled() async {
    final p = await _instance;
    return p.getBool(SettingsKeys.appLockEnabled) ?? false;
  }

  static Future<void> setAppLockEnabled(bool value) async {
    final p = await _instance;
    await p.setBool(SettingsKeys.appLockEnabled, value);
  }

  // --- Perfil vinculado a habitante (por usuario Firebase) ---
  static Future<int?> getLinkedHabitanteCedula(String? uid) async {
    if (uid == null || uid.isEmpty) return null;
    final p = await _instance;
    final v = p.getInt(SettingsKeys.linkedHabitanteCedulaKey(uid));
    return v;
  }

  static Future<void> setLinkedHabitanteCedula(String? uid, int cedula) async {
    if (uid == null || uid.isEmpty) return;
    final p = await _instance;
    await p.setInt(SettingsKeys.linkedHabitanteCedulaKey(uid), cedula);
  }

  static Future<void> clearLinkedHabitanteCedula(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    final p = await _instance;
    await p.remove(SettingsKeys.linkedHabitanteCedulaKey(uid));
  }

  // --- Módulo Formación (temporal; se puede deshabilitar) ---
  static Future<bool> getFormacionModuleEnabled() async {
    final p = await _instance;
    return p.getBool(SettingsKeys.formacionModuleEnabled) ?? true;
  }

  static Future<void> setFormacionModuleEnabled(bool value) async {
    final p = await _instance;
    await p.setBool(SettingsKeys.formacionModuleEnabled, value);
  }
}

/// Convierte valor guardado en ThemeMode.
ThemeMode themeModeFromInt(int value) {
  switch (value) {
    case 1:
      return ThemeMode.light;
    case 2:
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

int themeModeToInt(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 1;
    case ThemeMode.dark:
      return 2;
    case ThemeMode.system:
      return 0;
  }
}
