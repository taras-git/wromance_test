// ignore_for_file: comment_references

import 'package:flutter/material.dart';
import 'package:womanly_mobile/domain/entities/book.dart';
import 'package:womanly_mobile/presentation/misc/analytics/analytics.dart';
import 'package:womanly_mobile/presentation/misc/analytics/analytics_event.dart';
import 'package:womanly_mobile/presentation/misc/analytics/book_statistics.dart';
import 'package:womanly_mobile/presentation/misc/analytics/event_book_completed_totals_af.dart';
import 'package:womanly_mobile/presentation/misc/analytics/event_book_completed_uniques_af.dart';
import 'package:womanly_mobile/presentation/misc/analytics/placement.dart';

/// This event records only successful attempts, the only last attempt
/// is recorded (e.g. 2 retries with no success will be skipped, they
/// won't be presented in [msToLoadHomeTotal] parameter)
class EventMeasureLoadTime extends AnalyticsEvent {
  static bool _wasSentThisLaunch = false;

  EventMeasureLoadTime._();

  static final request1 = Measurement();
  static final request2 = Measurement();
  static final request3 = Measurement();
  static final request4 = Measurement();
  static final services = Measurement();
  static final data = Measurement();
  static final total = Measurement();
  static final totalWithRetries = Measurement();
  static int _countRetries = 0;

  static void reset(Measurement measurement) {
    measurement._reset();
  }

  static void measure(Measurement measurement) {
    measurement._save();
  }

  static void retry() {
    _countRetries++;
  }

  @override
  String get eventName => 'measure_load_time';

  @override
  Map<String, dynamic>? get eventProperties => {
        "splash_to_home_ms": totalWithRetries.totalMs,
        "last_successful_ms": total.totalMs,
        "services_ms": services.totalMs,
        "data_ms": data.totalMs,
        "request_1_ms": request1.totalMs,
        "request_2_ms": request2.totalMs,
        "request_3_ms": request3.totalMs,
        "request_4_ms": request4.totalMs,
        "count_retries": _countRetries,
      };

  static void send() {
    if (!_wasSentThisLaunch) {
      _wasSentThisLaunch = true;
      Analytics.logEvent(EventMeasureLoadTime._());
    }
  }
}

class Measurement {
  int _startMs = 0;
  int _endMs = 0;

  int? get totalMs => _endMs > 0 && _startMs > 0 ? _endMs - _startMs : null;

  void _reset() {
    _startMs = _now;
  }

  void _save() {
    _endMs = _now;
  }

  static int get _now => DateTime.now().millisecondsSinceEpoch;
}
