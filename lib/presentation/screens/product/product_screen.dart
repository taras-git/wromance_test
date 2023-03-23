import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womanly_mobile/domain/data_repository.dart';
import 'package:womanly_mobile/domain/entities/book.dart';
import 'package:womanly_mobile/domain/entities/enums/featured_style.dart';
import 'package:womanly_mobile/domain/entities/featured.dart';
import 'package:womanly_mobile/domain/entities/series.dart';
import 'package:womanly_mobile/domain/library_state.dart';
import 'package:womanly_mobile/presentation/common/widgets/authors_and_narrators.dart';
import 'package:womanly_mobile/presentation/common/widgets/book_cover.dart';
import 'package:womanly_mobile/presentation/common/widgets/book_peppers.dart';
import 'package:womanly_mobile/presentation/common/widgets/book_shelf.dart';
import 'package:womanly_mobile/presentation/common/widgets/featured/featured_books.dart';
import 'package:womanly_mobile/presentation/common/widgets/featured/featured_small_sceleton.dart';
import 'package:womanly_mobile/presentation/common/widgets/mini_player_placeholder.dart';
import 'package:womanly_mobile/presentation/common/widgets/my_list_button.dart';
import 'package:womanly_mobile/presentation/common/widgets/sample_button.dart';
import 'package:womanly_mobile/presentation/common/widgets/series_button.dart';
import 'package:womanly_mobile/presentation/common/widgets/share_button.dart';
import 'package:womanly_mobile/presentation/misc/analytics/placement.dart';
import 'package:womanly_mobile/presentation/misc/config/new_design.dart';
import 'package:womanly_mobile/presentation/misc/config/remote_config.dart';
import 'package:womanly_mobile/presentation/misc/experiments.dart';
import 'package:womanly_mobile/presentation/misc/expiration_timer/expiration_timer_settings.dart';
import 'package:womanly_mobile/presentation/misc/extensions.dart';
import 'package:womanly_mobile/presentation/screens/product/widgets/custom_divider.dart';
import 'package:womanly_mobile/presentation/screens/product/widgets/positioned_spot_light.dart';
import 'package:womanly_mobile/presentation/screens/product/product_state.dart';
import 'package:womanly_mobile/presentation/screens/product/widgets/description_text_widget.dart';
import 'package:womanly_mobile/presentation/screens/product/widgets/listen_button.dart';
import 'package:womanly_mobile/presentation/screens/product/widgets/listen_button_container.dart';
import 'package:womanly_mobile/presentation/screens/product/widgets/press_button.dart';
import 'package:womanly_mobile/presentation/theme/theme_colors.dart';
import 'package:womanly_mobile/presentation/theme/theme_text_style.dart';

const double _headersAdditionalTopPadding = 44 + 15; //instead of _appBarHeight
const double _appBarHeight = 56;
const double _tropes2linesHeight = 48;
final double coverHorizontalPadding = newProduct ? 16 : 27.5;
final double compensationHorizontalPadding = newProduct ? 15 : 0;

const bool debugColorListenButtonPositions = false;
const bool debugHideListenButton = true;

class ProductScreen extends StatelessWidget {
  final Book book;
  final String placement;
  const ProductScreen(
    this.book, {
    required this.placement,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final libraryState = context.read<LibraryState>();
    final allBooks = context.read<DataRepository>().books;
    final finishedBookIds = allBooks
        .where((it) => libraryState.isFinished(it))
        .map((it) => it.id)
        .toList();
    return ChangeNotifierProvider<ProductState>(
      create: (context) => ProductState(
          book, finishedBookIds, BookShelf.availableBooks(context, allBooks)),
      child: Placement.named(
        placement,
        subplacement: "book",
        child: ProductScreenBody(book),
      ),
    );
  }
}

class ProductScreenBody extends StatefulWidget {
  final Book book;
  static const double appBarOpacityLimitOffset = 100;

  const ProductScreenBody(this.book, {Key? key}) : super(key: key);

  @override
  State<ProductScreenBody> createState() => _ProductScreenBodyState();
}

class _ProductScreenBodyState extends State<ProductScreenBody> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() => _updateListenButtonPosition(context,
        scrollController.offset, widget.book.isSharingEmotionsEnabled));
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _updateListenButtonPosition(
          context, 0, widget.book.isSharingEmotionsEnabled);
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const PositionedSpotLight(),
        if (newProduct) BackBlur(widget.book),
        BookScreenBody(widget.book, scrollController),
        if (!debugHideListenButton)
          ListenButtonContainer(
            widget.book,
            ListenButton(
              widget.book,
              scrollController: scrollController,
            ),
          ),
        // Padding(
        //   padding: const EdgeInsets.only(top: 80.0),
        //   child: TextButton(
        //     onPressed: () {
        //       showDialog(
        //           context: context,
        //           builder: (context) => RecommendationsScreen());
        //     },
        //     child: Text('Test'),
        //   ),
        // ),
      ],
    );
  }

  void _updateListenButtonPosition(
      BuildContext context, double offset, bool isSharingEmotions) {
    final dataRepository = context.read<DataRepository>();
    final prefs = context.read<SharedPreferences>();
    final Series? series = dataRepository.getSeries(widget.book);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double minPosition =
        MediaQuery.of(context).padding.top + _appBarHeight;
    double limit = MediaQuery.of(context).padding.top +
        _headersAdditionalTopPadding +
        (screenWidth - 2 * coverHorizontalPadding) +
        8 +
        2 + // 16 +
        _tropes2linesHeight +
        // 62 +
        // 16 +
        // 20;
        10 +
        (-0) +
        compensationHorizontalPadding;
    if (series != null) {
      limit += SeriesButton.height;
    }
    if (isSharingEmotions) {
      limit += 16;
    }
    if (widget.book.expirationTimerDays(prefs) != null) {
      limit += const ExpirationTimerSettings().height;
    }
    if (!newProduct) {
      limit += 14;
    }

    context.read<ProductState>().setButtonPosition(
        offset, limit, minPosition, scrollController.hasClients);
  }
}

class BackBlur extends StatelessWidget {
  final Book book;
  BackBlur(this.book, {Key? key}) : super(key: key);

  late final cachedImage = CachedNetworkImage(
    imageUrl: book.coverUrl,
  );

  @override
  Widget build(BuildContext context) {
    const backImageBlur = 10.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonPosition =
        context.select<ProductState, double>((state) => state.buttonPosition);
    final imageSize = screenWidth * 1.35;
    final positionLeft = -(imageSize - screenWidth) / 2;
    var positionTop = -imageSize + buttonPosition;
    if (buttonPosition > imageSize) {
      positionTop = 0;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: positionTop,
          left: positionLeft,
          width: imageSize,
          height: imageSize,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: backImageBlur,
              sigmaY: backImageBlur,
              tileMode: TileMode.decal,
            ),
            child: cachedImage,
          ),
        ),
        Positioned(
          width: screenWidth,
          height: imageSize + 30,
          top: positionTop,
          child: Container(
            width: screenWidth,
            height: 158,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeColors.accentBackground.withOpacity(0.7),
                  ThemeColors.accentBackground.withOpacity(0.7),
                  ThemeColors.accentBackground.withOpacity(1),
                ],
                stops: const [0.0, 0.75, 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BookScreenBody extends StatelessWidget {
  final Book book;
  final ScrollController scrollController;
  const BookScreenBody(this.book, this.scrollController, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool topChips = context.watch<ProductState>().topChips;

    late final bookCover = BookCover(
      book,
      radius: 10,
      radiusTopRight: topChips ? 0 : 10,
      enableRouting: false,
      showEmotions: false,
      expirationTimerSettings:
          const ExpirationTimerSettings(blurWhenGone: false),
    );

    final dataRepository = context.read<DataRepository>();
    final allBooks = BookShelf.availableBooks(context, dataRepository.books);
    final featuredMoreLikeThis =
        context.select<ProductState, Featured?>((state) => state.moreLikeThis);
    final featuredMoreByThisAuthor = Featured(
        "More by this author",
        allBooks
            .where((it) =>
                it.author == book.author &&
                it.id != book.id) //TODO: more than 1 author
            .toList(),
        FeaturedStyle.small);
    final authorBooksIds = featuredMoreByThisAuthor.books.map((it) => it.id);
    final featuredMoreByThisNarrator = Featured(
        "More by these narrators",
        allBooks
            .where((it) =>
                _commonNarrators(it, book) &&
                it.id != book.id &&
                !authorBooksIds.contains(it.id))
            .toList(),
        FeaturedStyle.small);
    final featuredDescription = Featured(
        "Description", [], FeaturedStyle.medium); //TODO: more than 1 narrator

    const backImageBlur = 24.0;

    final items = [
      const SizedBox(height: _headersAdditionalTopPadding),
      RepaintBoundary(
        child: SizedBox(
          width: screenWidth,
          height: screenWidth -
              2 * coverHorizontalPadding +
              ((book.expirationTimerDays(context.read<SharedPreferences>()) !=
                      null)
                  ? bookCover.expirationTimerSettings.height
                  : 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!newProduct)
                Container(
                  margin:
                      EdgeInsets.symmetric(horizontal: coverHorizontalPadding),
                  child: Center(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: backImageBlur,
                        sigmaY: backImageBlur,
                        tileMode: TileMode.decal,
                      ),
                      child: bookCover,
                    ),
                  ),
                ),
              Container(
                // decoration: BoxDecoration(
                //     borderRadius: const BorderRadius.all(Radius.circular(10)),
                //     border: Border.all(width: 2, color: Colors.white)),
                margin:
                    EdgeInsets.symmetric(horizontal: coverHorizontalPadding),
                child: bookCover,
              ),
              // if (newProduct)
              //   Container(
              //     margin:
              //         EdgeInsets.symmetric(horizontal: coverHorizontalPadding),
              //     child: BorderGradient(
              //       strokeWidth: 0.5,
              //       radius: 10,
              //       gradient: LinearGradient(
              //         colors: [
              //           Colors.transparent,
              //           Colors.white.withOpacity(0.5)
              //         ],
              //         begin: Alignment.topCenter,
              //         end: Alignment.bottomCenter,
              //       ),
              //     ),
              //   ),
              Visibility(
                visible: topChips,
                child: Positioned(
                  top: -24,
                  right: compensationHorizontalPadding + 1,
                  height: 24,
                  child: _TopChips(book),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        color:
            debugColorListenButtonPositions ? Colors.red : Colors.transparent,
        height: _tropes2linesHeight,
        // padding: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ProductTropes(book),
        ),
      ),
      SizedBox(height: newProduct ? 8 : 6),
      SeriesButton(book),
      SpecialPriceContainer(book),
      Container(
        margin: EdgeInsets.only(top: (true) ? 40 : 0),
        color:
            debugColorListenButtonPositions ? Colors.pink : Colors.transparent,
        padding: const EdgeInsets.only(top: 18, bottom: 16 - 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          if (newProduct) const SizedBox(width: 30),
          if (newProduct) SampleButton.newProduct(book),
          if (!newProduct) SampleButton.normal(book),
          if (newProduct) MyListButton.newProduct(book),
          if (!newProduct) MyListButton.normal(book),
          ShareButton(
            book,
            from: "book_page",
            ajustColor: false,
          ),
          if (newProduct) const SizedBox(width: 30),
        ]),
      ),
      if (newProduct) const CustomDivider(),
      if (newProduct) const SizedBox(height: 12),
      AuthorsAndNarrators(book),
      const SizedBox(height: 16),
      RatingEndDuration(book),
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: DescriptionTextWidget(book.description),
      ),
      // Visibility(
      //   visible: !book.isSharingEmotionsEnabled,
      //   child: featuredMoreLikeThis == null
      //       ? const FeaturedSmallSceleton()
      //       : Placement.named(featuredMoreLikeThis?.title ?? "",
      //           child: FeaturedBooks(featuredMoreLikeThis)),
      // ),
      Visibility(
        visible: !book.isSharingEmotionsEnabled,
        child: Placement.named(featuredMoreByThisAuthor.title,
            child: FeaturedBooks(featuredMoreByThisAuthor)),
      ),
      Visibility(
        visible: !book.isSharingEmotionsEnabled,
        child: Placement.named(featuredMoreByThisNarrator.title,
            child: FeaturedBooks(featuredMoreByThisNarrator)),
      ),
      const MiniPlayerPlaceholder(),
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      itemCount: items.length,
      controller: scrollController,
      cacheExtent: 1000,
      itemBuilder: ((context, index) => items[index]),
    );
  }

  bool _commonNarrators(Book a, Book b) {
    final narratorsA =
        a.actors.where((it) => !it.isAuthor).map((it) => it.id).toSet();
    final narratorsB =
        b.actors.where((it) => !it.isAuthor).map((it) => it.id).toSet();
    return narratorsA.intersection(narratorsB).isNotEmpty;
  }
}

class RatingEndDuration extends StatelessWidget {
  final Book book;
  const RatingEndDuration(this.book, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: screenWidth - 30,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Opacity(
            opacity: newProduct ? 0.5 : 1,
            child: Image.asset(
              'assets/images/icons/smallClockIcon.png',
              width: 18,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () {},
            child: Text(
              book.totalDuration.hoursAndMinutes,
              style: ThemeTextStyle.s15w500.copyWith(
                color:
                    newProduct ? Colors.white.withOpacity(0.5) : Colors.white,
              ),
            ),
          ),
          if (RemoteConfig.isBookPeppersEnabled) const DividerLine(),
          if (RemoteConfig.isBookPeppersEnabled) BookPeppers(book: book),
        ],
      ),
    );
  }
}

class DividerLine extends StatelessWidget {
  const DividerLine({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 2,
      height: newProduct ? 10 : 16,
      color: newProduct ? Colors.white.withOpacity(0.5) : Colors.white,
    );
  }
}

class ProductTropes extends StatelessWidget {
  final Book book;
  const ProductTropes(this.book, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const tropesCount = 7;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: newProduct ? 30 : 16),
      child: DisplayFixOverflowTropes(
        book: book,
        tropesCount: tropesCount,
      ),
    );
  }
}

class DisplayFixOverflowTropes extends StatelessWidget {
  const DisplayFixOverflowTropes({
    Key? key,
    required this.book,
    required this.tropesCount,
  }) : super(key: key);

  final Book book;
  final int tropesCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        size,
      ) {
        final textSpan = TextSpan(
          text: book.tropes(tropesCount),
          style: tropesStyle(),
        );

        // Use a textpainter to determine if it will exceed max lines
        final textPainter = TextPainter(
          maxLines: 2,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          text: textSpan,
        );
        // trigger it to layout
        textPainter.layout(maxWidth: size.maxWidth);
        // whether the text overflowed or not
        final tropesOverflowDetected = textPainter.didExceedMaxLines;

        if (tropesOverflowDetected) {
          // recurcive Widget, reduce Tropes count by 1 if there is an overflow detected
          return DisplayFixOverflowTropes(
            book: book,
            tropesCount: tropesCount - 1,
          );
        } else {
          return Text(
            book.tropes(tropesCount),
            textAlign: TextAlign.center,
            style: tropesStyle(),
          );
        }
      },
    );
  }

  TextStyle tropesStyle() {
    return newProduct
        ? ThemeTextStyle.s15w400.copyWith(color: const Color(0xB3FFFFFF))
        : ThemeTextStyle.s14w400.copyWith(
            color: const Color(0xB3FFFFFF),
          );
  }
}

class SpecialPriceContainer extends StatelessWidget {
  final Book book;
  const SpecialPriceContainer(this.book, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool showSpecialPriceLabel = true;

    if (Experiments.resolveListenButtonSubtitle(context, book) != null) {
      showSpecialPriceLabel = true;
    }

    return SizedBox(
      height: PressButton.height + 8 + 16 + (showSpecialPriceLabel ? 11 : 0),
      child: showSpecialPriceLabel
          ? SpecialPriceOff(book)
          : const SizedBox.shrink(),
    );
  }
}

class SpecialPriceOff extends StatelessWidget {
  final Book book;
  const SpecialPriceOff(this.book, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String text = Experiments.resolveListenButtonSubtitle(context, book) ?? "";

    if (text.isEmpty) {
      // final monetizationState = context.read<MonetizationState>();
      final originalPriceString = "1.99";
      final offerPriceString = "0.99";

      final originalPriceDouble = doublePrice(originalPriceString);
      final offerPriceDouble = doublePrice(offerPriceString);

      if (originalPriceDouble == 0) {
        return const SizedBox.shrink();
      }

      int percent =
          (100 * (originalPriceDouble - offerPriceDouble) / originalPriceDouble)
              .round();

      text = "$percent% off original price $originalPriceString";
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Text(
        text,
        style: ThemeTextStyle.s14w500.copyWith(
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  double doublePrice(String priceWithCurrency) {
    if (priceWithCurrency.isEmpty) {
      return 0; //price for free
    }

    final digits = priceWithCurrency.replaceAll(RegExp(r"\D"), "");
    return (double.tryParse(digits) ?? 0) / 100.0;
  }
}

class _TopChips extends StatelessWidget {
  final Book book;
  const _TopChips(this.book, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.read<ProductState>().setColorTextChips(book);
    final bool topChips = context.watch<ProductState>().topChips;
    final String textChips = context.read<ProductState>().textChips;
    final String placeChips = context.read<ProductState>().placeChips;
    final Color colorChips = context.read<ProductState>().colorChips;

    return Container(
      height: 24,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      decoration: BoxDecoration(
          color: colorChips,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4.0),
            bottomRight: Radius.circular(0.0),
            topLeft: Radius.circular(4.0),
            bottomLeft: Radius.circular(0.0),
          )),
      child: Row(
        children: [
          if (topChips)
            Text(
              'TOP #$placeChips',
              style: ThemeTextStyle.s12w600.copyWith(
                color: Colors.white,
              ),
            ),
          if (topChips)
            Text(
              ' in $textChips',
              style: ThemeTextStyle.s12w400.copyWith(
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
