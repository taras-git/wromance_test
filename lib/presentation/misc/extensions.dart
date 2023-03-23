import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womanly_mobile/domain/entities/actor.dart';
import 'package:womanly_mobile/domain/entities/book.dart';
import 'package:womanly_mobile/domain/entities/chapter.dart';
import 'package:womanly_mobile/domain/entities/progress.dart';
import 'package:womanly_mobile/domain/entities/series.dart';
import 'package:womanly_mobile/domain/library_state.dart';
import 'package:womanly_mobile/presentation/misc/analytics/book_statistics.dart';
import 'package:womanly_mobile/presentation/misc/config/remote_config.dart';
import 'package:womanly_mobile/presentation/misc/expiration_timer/expiration_timer_settings.dart';
import 'package:womanly_mobile/presentation/misc/log.dart';
import 'package:womanly_mobile/presentation/theme/theme_text_style.dart';

extension BookX on Book {
  String get author {
    try {
      final author = actors.firstWhere((it) => it.isAuthor);
      return author.name;
    } catch (e) {
      return "";
    }
  }

  String get narrator {
    try {
      final narrator = actors.firstWhere((it) => !it.isAuthor);
      return narrator.name;
    } catch (e) {
      return "";
    }
  }

  Duration get totalDuration {
    return Duration(
      milliseconds: chapters.fold<int>(
          0,
          (previousValue, element) =>
              previousValue + element.duration.inMilliseconds),
    );
  }

  Duration position(Progress progress) {
    final msBefore = chapters.take(progress.chapterIndex).fold<int>(
        0,
        (previousValue, element) =>
            previousValue + element.duration.inMilliseconds);
    return Duration(milliseconds: msBefore + progress.position.inMilliseconds);
  }

  ///Use this method to check if book is finished to update its state in [LibraryState]
  ///For retrieving information use [LibraryState.isFinished] method directly.
  bool isFormallyFinished(Progress progress) {
    final currentChapter = chapters[progress.chapterIndex];
    final nextChapter = progress.chapterIndex + 1 < chapters.length
        ? chapters[progress.chapterIndex + 1]
        : null;

    final isLastChapter =
        currentChapter.isMainPart && (nextChapter?.isEnding ?? true);

    return isLastChapter && BookStatistics.isOpenedAtLeastHalf(this);
  }

  bool isTimeToShowRecommendations(Progress progress) {
    final currentChapter = chapters[progress.chapterIndex];
    final last5SecondsCondition = (currentChapter.duration.inMilliseconds -
            progress.position.inMilliseconds <=
        5000);
    final first5SecondsCondition = progress.position.inMilliseconds < 5000;

    final lastChapter = chapters[chapters.length - 1];

    if (progress.chapterIndex == chapters.length - 1) {
      if (lastChapter.isEnding && first5SecondsCondition) {
        return true;
      }
      if (lastChapter.isMainPart && last5SecondsCondition) {
        return true;
      }
    }

    return false;

    // final targetChapter = (progress.chapterIndex == chapters.length - 1 &&
    //         lastChapter.isMainPart) ||
    //     (progress.chapterIndex == chapters.length - 2 && lastChapter.isEnding);
    // final targetChapter = progress.chapterIndex == chapters.length - 1;

    // return targetChapter;
  }

  bool isStarted(Progress progress) {
    return progress.position.inMilliseconds > 100 || progress.chapterIndex > 0;
  }

  bool anyTagsFrom(Set<String> from) {
    bool hasCommon(List<String> list) {
      for (var s in list) {
        if (from.contains(s)) {
          return true;
        }
      }
      return false;
    }

    return hasCommon(tags) || hasCommon(subGenres) || hasCommon(topTropes);
  }

  bool allTagsFrom(
    Set<String> from, {
    bool onlyFree = false,
  }) {
    final list = from.toList();
    // list.remove(SearchState.freeTag);

    for (int i = 0; i < list.length; i++) {
      final tag = list[i];
      if (!subGenres.contains(tag) &&
          !topTropes.contains(tag) &&
          !tags.contains(tag)) {
        return false;
      }
    }

    return true;
  }

  String tropes(int maxCount) {
    final tropes = [
      ...subGenres.take(maxCount),
      ...topTropes.take(maxCount),
      ...tags.take(maxCount)
    ].take(maxCount).join(" • ");

    return tropes;
  }

  bool get debugIsDarkPlayerControls =>
      [1, 2, 3, 4, 5].map((it) => it.toString()).contains(id);

  Set<String> get allTags =>
      subGenres.toSet().union(topTropes.toSet()).union(tags.toSet());

  String chapterTitleOf(Chapter? chapter) {
    if (chapter == null) {
      return " ";
    }

    var of = "";
    if (chapter.isMainPart) {
      final chaptersMainPart = chapters.where((it) => it.isMainPart).length;
      of = " of $chaptersMainPart";
    }

    return "${chapter.title}$of";
  }

  bool isEnabledSharingAndListening(BuildContext context) {
    bool isEnabled = true;
    if (expirationTimerDays(context.read<SharedPreferences>()) == 0 &&
        !isStarted(context.read<LibraryState>().getProgress(this))) {
      isEnabled = false;
    }
    return isEnabled;
  }

  int? expirationTimerDays(SharedPreferences prefs) {
    // return 0;
    // return null;

    if (!RemoteConfig.isExpiredTimerEnabled) {
      return null;
    }

    // if (name == "Saint") {
    //   return 0; //TODO:REMOVE debug
    // }

    const idsFor3days = [79, 11, 28, 43];
    const idsFor7days = [70, 31, 50, 58, 1, 15, 26, 44, 54, 18, 51, 17];
    const idsFor14days = [75, 65, 13, 35, 45, 59, 67, 90, 56, 27, 53, 19];
    final id = int.parse(this.id);

    if (!idsFor3days.contains(id) &&
        !idsFor7days.contains(id) &&
        !idsFor14days.contains(id)) {
      return null;
    }

    const keyInitialTs = "ExpirationTimerDays.key.initialTimestamp";
    int initialTs = prefs.getInt(keyInitialTs) ?? 0;
    if (initialTs == 0) {
      initialTs = DateTime.now().millisecondsSinceEpoch;
      prefs.setInt(keyInitialTs, initialTs);
    }

    final diffMs = DateTime.now().millisecondsSinceEpoch - initialTs;
    final days = Duration(milliseconds: diffMs).inDays;

    if (days < 0) {
      return 1; //cheaters
    }

    if (idsFor3days.contains(id)) {
      return max(0, 3 - days);
    }
    if (idsFor7days.contains(id)) {
      return max(0, 7 - days);
    }
    if (idsFor14days.contains(id)) {
      return max(0, 14 - days);
    }

    return null;
  }

  Widget expirationTimerLeavingIn(
      int? days, ExpirationTimerBannerStyle bannerStyle) {
    if (days == null) {
      return const SizedBox.shrink();
    }

    final styleRegular = (bannerStyle == ExpirationTimerBannerStyle.normal
            ? ThemeTextStyle.s13w500
            : ThemeTextStyle.s9w500)
        .copyWith(
      color: Colors.white,
    );
    final styleBold = (bannerStyle == ExpirationTimerBannerStyle.normal
            ? ThemeTextStyle.s13w800
            : ThemeTextStyle.s9w700)
        .copyWith(
      color: Colors.white,
    );

    return RichText(
      text: TextSpan(
        style: styleRegular,
        text: days > 1
            ? "Leaving in "
            : days == 1
                ? "Leaving "
                : "",
        children: [
          TextSpan(
            style: styleBold,
            text: days > 1
                ? "$days DAYS"
                : days == 1
                    ? "TODAY"
                    : "GONE",
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }

  int get willExpireInDays =>
      max(0, expiredTs - DateTime.now().millisecondsSinceEpoch) ~/
      (1000 * 60 * 60 * 24);

  bool get willExpireSoon => willExpireInDays <= 30;
  bool get isExpired => willExpireInDays == 0;
}

extension BookListX on List<Book> {
  void updateFromBooks(List<Book> updatedBooks) {
    final ids = map((it) => it.id).toList();
    clear();
    for (var id in ids) {
      try {
        final updatedBook = updatedBooks.firstWhere((it) => it.id == id);
        add(updatedBook);
      } catch (e) {
        Log.print(e);
      }
    }
  }

  List<String> get allTags {
    final Set<String> result = {};

    void addFromList(List<String> list) {
      result.addAll(list);
    }

    forEach((it) => addFromList(it.subGenres));
    forEach((it) => addFromList(it.topTropes));
    forEach((it) => addFromList(it.tags));

    return result.where((it) => it.isNotEmpty).toList();
  }

  int commonTagsCount(List<Book> books) {
    final list1 = allTags;
    final list2 = books.allTags;
    return list1.toSet().intersection(list2.toSet()).length;
  }

  List<String> get tags {
    final Set<String> result = {};
    forEach((it) {
      result.addAll(it.tags);
    });
    return result.where((it) => it.isNotEmpty).toList();
  }

  List<String> get subGenres {
    final Set<String> result = {};
    forEach((it) {
      result.addAll(it.subGenres);
    });
    return result.where((it) => it.isNotEmpty).toList();
  }

  List<String> subGenresSorted(Map<String, int> tropesCount) {
    final data = subGenres;
    data.sort(
        ((a, b) => (tropesCount[b] ?? 0).compareTo((tropesCount[a] ?? 0))));
    return data;
  }

  List<String> get topTropes {
    final Set<String> result = {};
    forEach((it) {
      result.addAll(it.topTropes);
    });
    return result.where((it) => it.isNotEmpty).toList();
  }

  List<String> get topTropesAndTags {
    final Set<String> result = {};
    forEach((it) {
      result.addAll(it.topTropes);
    });
    forEach((it) {
      result.addAll(it.tags);
    });
    return result.where((it) => it.isNotEmpty).toList();
  }
}

extension DurationX on Duration {
  String get minutesAndSeconds {
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);
    if (inHours > 0) {
      final hours = inHours.remainder(24);
      return "${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)}";
    } else {
      return "${pad2(minutes)}:${pad2(seconds)}";
    }
  }

  String get hoursAndMinutes {
    if (inHours > 0) {
      return "${inHours.remainder(24)}h ${inMinutes.remainder(60)}m";
    } else {
      return "${inMinutes.remainder(60)}m";
    }
  }

  String get hoursAndMinutesFull {
    if (inHours > 0) {
      return "${inHours.remainder(24)}h ${inMinutes.remainder(60)} min left";
    } else {
      return "${inMinutes.remainder(60)} min left";
    }
  }
}

extension SeriesX on Series {
  List<String> get authors {
    final Set<String> result = {};
    for (var book in books) {
      result
          .addAll(book.actors.where((it) => it.isAuthor).map((it) => it.name));
    }
    return List.from(result);
  }
}

extension ChapterX on Chapter {
  bool get isBeginning => id ~/ 1000 == 1;
  bool get isMainPart => id ~/ 1000 == 2;
  bool get isEnding => id ~/ 1000 == 3;
}

extension DateTimeX on DateTime {
  String get formatMinutesAndSeconds {
    //m:ss
    final totalSeconds = millisecondsSinceEpoch ~/ 1000;
    final totalMinutes = totalSeconds ~/ 60;
    final m = totalMinutes % 60;
    final s = totalSeconds % 60;
    return "$m:${pad2(s)}";
  }
}

extension ActorX on Actor {
  List<Book> books(List<Book> allBooks) => allBooks
      .where((it) => it.actors
          .where((Actor a) => a.isAuthor)
          .map((e) => e.id)
          .contains(id))
      .toList();

  bool anyTagsFrom(Set<String> from, List<Book> allBooks) {
    return books(allBooks).allTags.toSet().intersection(from).isNotEmpty;
  }

  String get nameSplitted {
    final parts = name.split(' ');
    switch (parts.length) {
      case 2:
        return "${parts[0]}\n${parts[1]}";
      case 3:
        return "${parts[0]} ${parts[1]}\n${parts[2]}";
      default:
        return name;
    }
  }
}

String pad2(num a) => a < 10 ? "0$a" : "$a";
