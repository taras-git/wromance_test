import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:womanly_mobile/domain/audio_player.dart';
import 'package:womanly_mobile/domain/entities/book.dart';
import 'package:womanly_mobile/domain/entities/progress.dart';
import 'package:womanly_mobile/domain/library_state.dart';
import 'package:womanly_mobile/presentation/misc/config/new_design.dart';
import 'package:womanly_mobile/presentation/misc/experiments.dart';
import 'package:womanly_mobile/presentation/misc/extensions.dart';
import 'package:womanly_mobile/presentation/misc/log.dart';
import 'package:womanly_mobile/presentation/screens/product/widgets/press_button.dart';
import 'package:womanly_mobile/presentation/theme/theme_colors.dart';
import 'package:womanly_mobile/presentation/theme/theme_text_style.dart';

// ignore: must_be_immutable
class ListenButton extends StatelessWidget {
  final Book book;
  final Function? beforeOnTap;
  final ScrollController? scrollController;
  TextStyle? textStyle;
  final bool onlyPurchase;
  final bool allowNavigateToPlayer;
  final bool forRecommendationScreen;
  final bool inCaseOfSpecialOfferStyleAsOffer;
  ListenButton(
    this.book, {
    this.beforeOnTap,
    this.scrollController,
    this.textStyle,
    this.onlyPurchase = false,
    this.allowNavigateToPlayer = true,
    this.forRecommendationScreen = false,
    this.inCaseOfSpecialOfferStyleAsOffer = false,
    Key? key,
  }) : super(key: key);

  // factory ListenButton.normal(Book book, {
  //   beforeOnTap,
  //   scrollController
  // }) =>
  //     ListenButton._( book);

  @override
  Widget build(BuildContext context) {
    final audioPlayer = context.read<AudioPlayer>();

    final bool isLoading = false;
    final bool subscriptionStatusChanged = false;
    bool isSpecialOfferApplied = true;

    final bool isSpecialBlueOfferStyle = false;

    String priceSuffix = " for \$0.99";

    final isNeedToSubscribe = false;
    final isStarted = false;

    bool borderedStyle = true;

    Color labelColor = Colors.white;
    if (borderedStyle) {
      textStyle = ThemeTextStyle.s15w600;
      labelColor = ThemeColors.accentBlueTextTabActive;
    }

    final isFreeUpExperiment3WelcomeGift = false;

    final freeUpExperiment3Widgets = [
      Text(
        'Listen FREE',
        style: (textStyle ?? ThemeTextStyle.s17w600).copyWith(
          color: labelColor,
        ),
      ),
      const SizedBox(width: 7),
      Image.asset(
        'assets/images/icons/gift.png',
        width: 20,
        height: 20,
      ),
    ];

    final content = Experiments.resolveListenButtonTitle(
            context, book, textStyle ?? ThemeTextStyle.s17w600, onlyPurchase) ??
        (isFreeUpExperiment3WelcomeGift
            ? freeUpExperiment3Widgets
            : [
                Padding(
                  padding: EdgeInsets.only(bottom: borderedStyle ? 2 : 0),
                  child: Text(
                    'Listen$priceSuffix',
                    style: forRecommendationScreen
                        ? ThemeTextStyle.s15w500.copyWith(
                            color: ThemeColors.accentBlueTextTabActive,
                          )
                        : ((textStyle ?? ThemeTextStyle.s17w600).copyWith(
                            color: labelColor,
                          )),
                  ),
                ),
                const SizedBox(width: 7),
                Image.asset(
                  isSpecialBlueOfferStyle
                      ? 'assets/images/icons/tag.png'
                      : 'assets/images/icons/playIcon.png',
                  width: isSpecialBlueOfferStyle ? 20 : 10,
                  color: forRecommendationScreen
                      ? ThemeColors.accentBlueTextTabActive
                      : (borderedStyle ? labelColor : null),
                ),
              ]);
    if (isLoading) {
      content.addAll([
        const SizedBox(width: 9),
        CupertinoActivityIndicator(
          radius: 8,
          color: labelColor,
        ),
      ]);
    }

    final child = Opacity(
      opacity: book.isEnabledSharingAndListening(context) ? 1.0 : 0.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: content,
      ),
    );

    final chapter = book
        .chapters[context.read<LibraryState>().getProgress(book).chapterIndex];
    final allowedFor3ChaptersExperiment = true;
    // Free3ChaptersExperimentState.isExperimentActive
    //     ? (chapter.isMainPart && chapter.id % 1000 > 3 ? true : false)
    //     : true;

    final pressButton = PressButton(
      color: forRecommendationScreen
          ? const Color(0xFF0A142A)
          : book.isEnabledSharingAndListening(context)
              ? (isSpecialOfferApplied &&
                      //bookStatus == BookStatus.withPrice &&
                      !isSpecialBlueOfferStyle &&
                      allowedFor3ChaptersExperiment)
                  ? ThemeColors.pink
                  : ThemeColors.accentBlueButtons
              : const Color.fromARGB(255, 34, 57, 104),
      noisyGradientStyle: isNeedToSubscribe,
      specialHeight: borderedStyle || forRecommendationScreen ? 36 : null,
      forRecommendationScreen: forRecommendationScreen,
      borderedStyle: borderedStyle,
      onPressed: (() async {
        if (!book.isEnabledSharingAndListening(context)) {
          return;
        }
        beforeOnTap?.call();

        if (isLoading) {
          return;
        }

        Future<void> _startListeningLogic() async {
          Log.stub();
          Log.dialog(context, "In-app purchase");
        }

        if (!onlyPurchase) {
          if (Experiments.resolveIsAllowedToListenBook(context, book)) {
            await _startListeningLogic();
            return;
          }

          if (isFreeUpExperiment3WelcomeGift) {
            await _startListeningLogic();
            return;
          }
        }

        await _startListeningLogic();
      }),
      child: child,
    );

    return pressButton;
  }

  void _startWithChapter(
      AudioPlayer audioPlayer, Book book, Progress progress) {
    if (!book.isStarted(progress)) {
      try {
        final index =
            book.chapters.indexWhere((it) => it.id == book.startChapter);
        audioPlayer.setChapter(index);
      } catch (e) {
        Log.print(e);
      }
    }
  }

  void _navigateToPlayer() {
    Log.stub();
  }
}

class _AnimatedButton extends StatefulWidget {
  final int animationNum;
  const _AnimatedButton(this.animationNum, {Key? key}) : super(key: key);

  @override
  State<_AnimatedButton> createState() => __AnimatedButtonState();
}

class __AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late final animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8 * 2),
  );
  late final Animation<double> animation;

  @override
  void initState() {
    super.initState();
    animation = Tween(begin: 0.0, end: 1.0).animate(animationController);
    animationController.repeat();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = const Color(0xFF091227)
        .withOpacity(widget.animationNum == 2 ? 1.0 : 0.5);
    // final baseColor = Colors.white;
    const leftSpot = Color(0xFFFF288F);
    const rightSpot = Color(0xFFA012D2);
    // final rightSpot = Colors.transparent;
    final tileMode =
        widget.animationNum == 2 ? TileMode.clamp : TileMode.mirror;
    final radius = widget.animationNum == 2 ? 5.5 : 7.0;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Container(
        height: newProduct ? 60 : 50,
        // width: 100,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          // backgroundBlendMode: BlendMode.colorDodge,
          gradient: RadialGradient(
            tileMode: tileMode,
            center: Alignment.topLeft,
            radius: radius,
            focal: const Alignment(-1.0, -1.0),
            focalRadius: 2.5,
            colors: [
              // baseColor,
              leftSpot,
              baseColor,
            ],
            transform: GradientSkewRotation(2 * pi * animationController.value),
          ),
          // gradient: SweepGradient(
          //   colors: <Color>[Color(0xFFFFFFFF), Color(0xFF009900)],
          //   transform: GradientRotation(2 * pi * animation.value),
          // )
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            gradient: RadialGradient(
              tileMode: tileMode,
              center: Alignment.bottomRight,
              // center: Alignment.bottomCenter,
              focal: const Alignment(1.0, 1.0),
              focalRadius: 2.5,
              radius: radius + 1,
              colors: const [
                rightSpot,
                Colors.transparent,
              ],
              transform:
                  GradientSkewRotation(2 * pi * animationController.value),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientSkewRotation extends GradientTransform {
  /// Constructs a [GradientRotation] for the specified angle.
  ///
  /// The angle is in radians in the clockwise direction.
  const GradientSkewRotation(this.radians);

  /// The angle of rotation in radians in the clockwise direction.
  final double radians;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // assert(bounds != null);
    final double sinRadians = sin(radians);
    final double oneMinusCosRadians = 1 - cos(radians);
    final Offset center = bounds.center;
    final double originX =
        sinRadians * center.dy + oneMinusCosRadians * center.dx;
    final double originY =
        -sinRadians * center.dx + oneMinusCosRadians * center.dy;

    return Matrix4.identity()
      ..translate(originX, originY)
      ..scale(1.0, 1.0, 1.0)
      ..rotateZ(radians);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is GradientRotation && other.radians == radians;
  }

  @override
  int get hashCode => radians.hashCode;
}
