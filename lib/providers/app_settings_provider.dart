import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyShowExplanationAlways = 'show_explanation_always';
const _keyTargetExamDate = 'target_exam_date';
const _keyTextScale = 'text_scale';
const _keyEnableSound = 'enable_sound';
const _keyReminderHour = 'reminder_hour';
const _keyReminderMinute = 'reminder_minute';

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});

class AppSettingsState {
  final bool showExplanationAlways;
  final DateTime? targetExamDate;
  final double textScale;
  final bool enableSound;
  final TimeOfDay? reminderTime;

  const AppSettingsState({
    this.showExplanationAlways = false,
    this.targetExamDate,
    this.textScale = 1.0,
    this.enableSound = true,
    this.reminderTime,
  });

  AppSettingsState copyWith({
    bool? showExplanationAlways,
    DateTime? targetExamDate,
    double? textScale,
    bool? enableSound,
    // Using a simple flag for clearing reminder since copyWith with nullables is tricky
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
  }) {
    return AppSettingsState(
      showExplanationAlways:
          showExplanationAlways ?? this.showExplanationAlways,
      targetExamDate: targetExamDate ?? this.targetExamDate,
      textScale: textScale ?? this.textScale,
      enableSound: enableSound ?? this.enableSound,
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(const AppSettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final alwaysShow = prefs.getBool(_keyShowExplanationAlways) ?? false;
    final dateStr = prefs.getString(_keyTargetExamDate);
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    
    final scale = prefs.getDouble(_keyTextScale) ?? 1.0;
    final sound = prefs.getBool(_keyEnableSound) ?? true;
    
    final rHour = prefs.getInt(_keyReminderHour);
    final rMinute = prefs.getInt(_keyReminderMinute);
    final reminder = (rHour != null && rMinute != null)
        ? TimeOfDay(hour: rHour, minute: rMinute)
        : null;

    state = AppSettingsState(
      showExplanationAlways: alwaysShow,
      targetExamDate: date,
      textScale: scale,
      enableSound: sound,
      reminderTime: reminder,
    );
  }

  Future<void> setShowExplanationAlways(bool value) async {
    state = state.copyWith(showExplanationAlways: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowExplanationAlways, value);
  }

  Future<void> setTargetExamDate(DateTime? date) async {
    state = state.copyWith(targetExamDate: date);
    final prefs = await SharedPreferences.getInstance();
    if (date != null) {
      await prefs.setString(_keyTargetExamDate, date.toIso8601String());
    } else {
      await prefs.remove(_keyTargetExamDate);
    }
  }

  Future<void> setTextScale(double value) async {
    state = state.copyWith(textScale: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTextScale, value);
  }

  Future<void> setEnableSound(bool value) async {
    state = state.copyWith(enableSound: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableSound, value);
  }

  Future<void> setReminderTime(TimeOfDay? time) async {
    if (time != null) {
      state = state.copyWith(reminderTime: time);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyReminderHour, time.hour);
      await prefs.setInt(_keyReminderMinute, time.minute);
    } else {
      state = state.copyWith(clearReminderTime: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyReminderHour);
      await prefs.remove(_keyReminderMinute);
    }
  }
}
