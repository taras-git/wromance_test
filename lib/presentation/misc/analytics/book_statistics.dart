// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womanly_mobile/domain/audio_player.dart';
import 'package:womanly_mobile/domain/data_repository.dart';
import 'package:womanly_mobile/domain/entities/book.dart';
import 'package:womanly_mobile/domain/library_state.dart';
import 'package:womanly_mobile/presentation/misc/analytics/analytics.dart';
import 'package:womanly_mobile/presentation/misc/analytics/event_playback_restored.dart';
import 'package:womanly_mobile/presentation/misc/analytics/event_playback_stopped.dart';
import 'package:womanly_mobile/presentation/misc/extensions.dart';
import 'package:womanly_mobile/presentation/misc/log.dart';

class BookStatistics {
  static late final SharedPreferences _prefs;
  static bool _initialized = false;
  static late final AudioPlayer _player;
  static late final LibraryState _state;
  static int finishedPaidBooks = 0;

  static const _updateDuration = Duration(seconds: 10);
  static Timer? _updateTimer;
  static DateTime _chapterListeningStartedTime = DateTime.now();
  static DateTime _playbackPauseReasonLastChanged = DateTime.now();
  static DateTime _lastTimeUserPressedPlayButton = DateTime.now();

  static final Map<Book, List<String>> _listOpenedChapters = {};
  static final Map<Book, int> _chapterCompleteness = {};
  static PlaybackPauseReason _playbackPauseReason = PlaybackPauseReason.none;
  static late DataRepository _dataRepository;
  static Duration _lastPlayerPosition = Duration.zero;
  static int _stopSeconds = 0;

  static void init(
    SharedPreferences prefs,
    AudioPlayer player,
    LibraryState state,
    DataRepository dataRepository,
  ) {
    _dataRepository = dataRepository;
    if (_initialized) {
      return;
    }
    _prefs = prefs;
    _player = player;
    _state = state;
    _initialized = true;
    updateFinishedPaidCount(state);
  }

  static void updateFinishedPaidCount(LibraryState state) {
    Log.stub();
  }

  static void justPressedPlay() {
    _lastTimeUserPressedPlayButton = DateTime.now();
  }

  static void onIsPlayingChanged(bool isPlaying) {
    if (isPlaying) {
      Log.print("==BookStatistics timer started");
      _chapterListeningStartedTime = DateTime.now();
      _updateTimer = Timer.periodic(_updateDuration, _onTimerUpdate);
    } else {
      Log.print("==BookStatistics timer stopped");
      _updateTimer?.cancel();

      final book = _state.currentBook;
      if (_stopSeconds > 0 && book != null) {
        Analytics.logEvent(EventPlaybackStopped(
          book,
          _stopSeconds,
          _playbackPauseReason == PlaybackPauseReason.chapter_ended
              ? "auto_paused"
              : getPlaybackPauseReasonString(),
        ));
      }
    }
  }

  static void onCurrentChapterChanged(int chapterIndex) {
    Log.stub();
  }

  static bool isOpenedAtLeastHalf(Book book) {
    Log.stub();
    return false;
  }

  static void _onTimerUpdate(Timer _) {
    if (_player.isPlaying) {
      Log.print("==BookStatistics timer update (isPlaying)");
      final book = _state.currentBook;
      if (book != null) {
        _logPlayTime(book);

        if (_lastPlayerPosition == _player.currentPosition) {
          _stopSeconds += _updateDuration.inSeconds;
          Analytics.logEvent(EventPlaybackStopped(
            book,
            _stopSeconds,
            "update_timer",
          ));
        } else {
          if (_stopSeconds > 0) {
            Analytics.logEvent(EventPlaybackRestored(book));
          }
          _stopSeconds = 0;
        }
      }

      _lastPlayerPosition = _player.currentPosition;
    }
  }

  static void _logPlayTime(Book book) {
    Log.stub();
  }

  static String _key(_Keys key, Book book) => key.toString() + "_${book.id}";

  static int playTimeMinutes(Book book) {
    int seconds = _prefs.getInt(_key(_Keys.totalPlayTimeSeconds, book)) ?? 0;
    return seconds ~/ 60;
  }

  static int playTimeDays(Book book) {
    Log.stub();
    return 0;
  }

  static int chapterListeningTimeMinutes() {
    final now = DateTime.now();
    final diffMs = now.millisecondsSinceEpoch -
        _chapterListeningStartedTime.millisecondsSinceEpoch;
    return diffMs ~/ (60 * 1000);
  }

  static void updateChapterCompleteness(
      Book book, int chapterIndex, Duration position) async {
    //this delay is needed to properly store analytics in case of chapter (and progress) changes, here we have a 1 second lag
    await Future.delayed(const Duration(seconds: 1));
    _chapterCompleteness[book] = (100 *
            (position.inSeconds /
                book.chapters[chapterIndex].duration.inSeconds))
        .toInt();
    if (_chapterCompleteness[book] == 99) {
      //fix for insufficience of progress counting
      _chapterCompleteness[book] = 100;
    }
  }

  static int getChapterCompleteness(BuildContext context, Book book,
      {bool force = false}) {
    final storedValue = _chapterCompleteness[book];
    if (!force && storedValue != null) {
      return storedValue;
    } else {
      final progress = context.read<LibraryState>().getProgress(book);
      return (100 *
              (progress.position.inSeconds /
                  book.chapters[progress.chapterIndex].duration.inSeconds))
          .toInt();
    }
  }

  static String getPlaybackPauseReasonString() =>
      _playbackPauseReason.toString().split('.')[1];
  static PlaybackPauseReason get playbackPauseReason => _playbackPauseReason;

  static void setPlaybackPauseReason(PlaybackPauseReason reason) {
    final now = DateTime.now();
    final isHot = now.millisecondsSinceEpoch -
            _playbackPauseReasonLastChanged.millisecondsSinceEpoch <
        1000;
    if (isHot) {
      //skip auto-setters by callbacks if this value already has been set explicitly and recently
      return;
    }
    _playbackPauseReasonLastChanged = now;
    _playbackPauseReason = reason;
  }

  static bool isJustPressedPlay() {
    final now = DateTime.now();
    final isHot = now.millisecondsSinceEpoch -
            _lastTimeUserPressedPlayButton.millisecondsSinceEpoch <
        1000;
    return isHot;
  }
}

enum _Keys {
  totalPlayTimeSeconds,
  totalUniqueDays,
  openedChapters,
}

enum PlaybackPauseReason {
  none,
  pause_button,
  chapter_ended,
  user_changed_book,
  user_selected_chapter,
  next_button,
  prev_button,
  sleep_timer,
  call_interrupted, //TODO: currently not used
}
