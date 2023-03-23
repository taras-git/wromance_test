import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womanly_mobile/domain/entities/book.dart';
import 'package:womanly_mobile/presentation/common/widgets/book_cover.dart';
import 'package:womanly_mobile/presentation/misc/config/remote_config.dart';
import 'package:womanly_mobile/presentation/misc/expiration_timer/expiration_timer_settings.dart';
import 'package:womanly_mobile/presentation/misc/extensions.dart';

class BookShelf extends StatefulWidget {
  final List<Book> books;
  final VoidCallback? onNewItemPressed;
  final Function(Book)? onDeletePressed;
  final List<Book>? highlighted;
  final bool? isEditing;
  final int columns;
  final Function(Book)? beforeOnTap;
  final ExpirationTimerSettings expirationTimerSettings;
  final bool distorted2ColumnList;
  final bool finishLabelVisible;
  final bool sortByExpirationDate;
  const BookShelf(
    this.books, {
    this.onNewItemPressed,
    this.onDeletePressed,
    this.highlighted,
    this.isEditing,
    this.columns = 3,
    this.beforeOnTap,
    required this.expirationTimerSettings,
    this.distorted2ColumnList = false,
    this.finishLabelVisible = false,
    this.sortByExpirationDate = false,
    Key? key,
  }) : super(key: key);

  @override
  State<BookShelf> createState() => _BookShelfState();

  static List<Book> availableBooks(BuildContext context, List<Book> allBooks) {
    final list = List.of(allBooks);
    final expiredBooks = list.where((it) => it.isExpired).toList();
    // Books are expired anyway and for all, even if user had purchased it(!) v1.0.172
    // expiredBooks.removeWhere((it) => !ExpiringBookLabel.showFor(context, it));
    list.removeWhere((it) => expiredBooks.contains(it));

    return list;
  }
}

class _BookShelfState extends State<BookShelf>
    with SingleTickerProviderStateMixin {
  late final animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  final random = Random();
  late final List<ShakerAnimation> shaked = [
    for (int i = 0; i < 10; i++) ShakerAnimation(random, animationController)
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant BookShelf oldWidget) {
    if (widget.isEditing == true) {
      animationController.reset();
      animationController.repeat(
          reverse: true, period: const Duration(milliseconds: 110));
    } else {
      for (var it in shaked) {
        it.stopShake();
      }
      animationController.stop();
      animationController.value = 0.5;
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgets = (widget.highlighted ?? widget.books)
        .map(
          (it) {
            const rotation = 0.003;
            final shakerAnimation = shaked[random.nextInt(shaked.length)];
            final bookCover = BookCover(
              it,
              radius: 10,
              beforeOnTap: () {
                widget.beforeOnTap?.call(it);
              },
              expirationTimerSettings: widget.expirationTimerSettings,
              finishLabelVisible: widget.finishLabelVisible,
            );
            final child = Padding(
              padding: const EdgeInsets.all(8),
              child: (widget.sortByExpirationDate)
                  ? Column(
                      children: [
                        bookCover,
                      ],
                    )
                  : bookCover,
            );
            if (widget.isEditing == true) {
              shakerAnimation.startShake();

              return RotationTransition(
                turns: Tween<double>(begin: -rotation, end: rotation)
                    .animate(shakerAnimation),
                child: Stack(
                  children: [
                    IgnorePointer(
                      ignoring: widget.isEditing == true,
                      child: child,
                    ),
                    Visibility(
                      visible: widget.isEditing == true,
                      child: _BadgeDelete(onPressed: () {
                        widget.onDeletePressed?.call(it);
                      }),
                    ),
                  ],
                ),
                // ),
              );
            } else {
              return child;
            }
          },
        )
        .cast<Widget>()
        .toList();

    // final List<Book> restBooks = widget.highlighted == null
    //     ? []
    //     : widget.books
    //         .where((it) => !widget.highlighted!.contains(it))
    //         .toList();

    // widgets.addAll(restBooks
    //     .map<Widget>(
    //       // ignore: unnecessary_cast
    //       (it) => ColorFiltered(
    //         colorFilter: ColorFilter.mode(
    //             const Color(0xFF091227).withOpacity(0.7), BlendMode.srcATop),
    //         child: Padding(
    //           padding: const EdgeInsets.all(8),
    //           child: BookCover(it, radius: 10),
    //         ),
    //       ) as Widget,
    //     )
    //     .toList());

    // if (widget.onNewItemPressed != null && !(widget.isEditing ?? false)) {
    //   final newItem = NewItem(onPressed: widget.onNewItemPressed!);
    //   widgets.add(
    //     widget.sortByExpirationDate ? Column(children: [newItem]) : newItem,
    //   );
    // }

    if (widget.distorted2ColumnList) {
      final columns = 2;
      final books = (widget.highlighted ?? widget.books);
      final prefs = context.read<SharedPreferences>();
      final List<Widget> positionedWidgets = [];
      double left = 0;
      double top0 = 0;
      double top1 = 0;
      final double itemWidth =
          (MediaQuery.of(context).size.width - (columns - 1) * 16) / columns;
      final double itemHeight = itemWidth;
      for (int i = 0; i < books.length; i++) {
        final double height = itemHeight +
            (books[i].expirationTimerDays(prefs) != null
                ? widget.expirationTimerSettings.height
                : 0);
        positionedWidgets.add(
          Positioned(
            left: left,
            top: i % 2 == 0 ? top0 : top1,
            child: SizedBox(
              width: itemWidth,
              height: height,
              child: widgets[i],
            ),
          ),
        );
        if (left == 0) {
          left += itemWidth;
        } else {
          left = 0;
        }
        if (i % 2 == 0) {
          top0 += height;
        } else {
          top1 += height;
        }
      }
      if (widgets.length > books.length) {
        positionedWidgets.add(
          Positioned(
            left: left,
            top: books.length % 2 == 0 ? top0 : top1,
            child: SizedBox(
              width: itemWidth,
              height: itemHeight,
              child: widgets.last,
            ),
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        height: max(top0, top1),
        child: Stack(
          children: positionedWidgets,
        ),
      );
    }

    //TODO: 'shrinkWrap: true' builds all list items if placed in a column, for example
    //refactor for true builder where needed (use of slivers)
    final itemWidth = (MediaQuery.of(context).size.width - 16) / 3;
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        childAspectRatio: 1 - (RemoteConfig.isExpiredTimerEnabled ? 0.16 : 0),
      ),
      itemCount: widgets.length,
      itemBuilder: (BuildContext context, int index) => widgets[index],
    );
  }
}

class _BadgeDelete extends StatelessWidget {
  final VoidCallback onPressed;
  const _BadgeDelete({required this.onPressed, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(top: RemoteConfig.isExpiredTimerEnabled ? 20.0 : 0),
      child: Align(
        alignment: Alignment.topRight,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 10),
            child: Image.asset(
              "assets/images/icons/badge_delete.png",
              width: 24,
              height: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class ShakerAnimation extends CompoundAnimation<double> {
  late double start;
  bool _isStarted = false;
  static const stoppedAnimation = AlwaysStoppedAnimation<double>(0.5);

  ShakerAnimation(Random random, Animation<double> first)
      : super(first: first, next: stoppedAnimation) {
    start = random.nextDouble();
  }

  void startShake() {
    _isStarted = true;
  }

  void stopShake() {
    _isStarted = false;
  }

  @override
  double get value {
    if (!_isStarted) {
      return stoppedAnimation.value;
    }

    double res = first.value;
    if (first.status == AnimationStatus.forward) {
      res = first.value + start;
      if (res > 1) {
        res -= 2 * (res - 1.0);
      }
    } else if (first.status == AnimationStatus.reverse) {
      res = first.value - start;
      if (res < 0) {
        res = -res;
      }
    }

    return res;
  }
}
