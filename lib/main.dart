import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resize/resize.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:womanly_mobile/data/common_prefs.dart';
import 'package:womanly_mobile/data/impl/data_repository_impl.dart';
import 'package:womanly_mobile/data/impl/storage_manager_impl.dart';
import 'package:womanly_mobile/data/models/book_model.dart';
import 'package:womanly_mobile/data/storage_manager.dart';
import 'package:womanly_mobile/domain/audio_player.dart';
import 'package:womanly_mobile/domain/data_repository.dart';
import 'package:womanly_mobile/domain/impl/audio_player_impl.dart';
import 'package:womanly_mobile/domain/impl/library_manager_prefs_impl.dart';
import 'package:womanly_mobile/domain/impl/library_state_impl.dart';
import 'package:womanly_mobile/domain/library_manager.dart';
import 'package:womanly_mobile/domain/library_state.dart';
import 'package:womanly_mobile/presentation/misc/analytics/session_manager.dart';
import 'package:womanly_mobile/presentation/misc/log.dart';
import 'package:womanly_mobile/presentation/screens/product/product_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:womanly_mobile/presentation/theme/theme_colors.dart';
import 'package:womanly_mobile/test_data/json_test_book.dart';
import 'package:womanly_mobile/test_data/json_test_books.dart';
import 'package:womanly_mobile/test_data/json_test_series.dart';
import 'package:womanly_mobile/test_data/json_test_tropes.dart';

import 'presentation/common/widgets/debug_space_devourer.dart';
import 'presentation/misc/analytics/event_measure_load_time.dart';

late SharedPreferences sharedPreferences;
late SessionManager sessionManager;
late FirebaseApp firebaseApp;

const kEnvironment = String.fromEnvironment("ENVIRONMENT",
    defaultValue: "PROD"); //'TEST' or 'PROD'

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    sharedPreferences = await SharedPreferences.getInstance();
    EventMeasureLoadTime.reset(EventMeasureLoadTime.totalWithRetries);
    sessionManager = SessionManager(sharedPreferences);
    runApp(HomePage());
  }, (error, stack) {
    Log.errorMainZonedGuarded(error, stack);
  });
}

class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);

  final testBook = BookModel.fromJson(jsonDecode(jsonTestBook2))!;

  @override
  Widget build(BuildContext context) {
    return ProvidersWrapper(
      child: Resize(
        allowtextScaling: false,
        size: const Size(375, 812),
        builder: () => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ShowCaseWidget(
            disableMovingAnimation: true,
            disableScaleAnimation: true,
            builder: Builder(
              builder: (context) => Scaffold(
                backgroundColor: ThemeColors.accentBackground,
                body: DebugSpaceDevourer(
                  child: ProductScreen(
                    testBook,
                    placement: "test_task",
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProvidersWrapper extends StatefulWidget {
  final Widget child;
  const ProvidersWrapper({
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  State<ProvidersWrapper> createState() => _ProvidersWrapperState();
}

class _ProvidersWrapperState extends State<ProvidersWrapper> {
  late StorageManager storageManager;
  late DataRepository dataRepository;

  bool isReady = false;

  @override
  void initState() {
    super.initState();

    storageManager = StorageManagerImpl(
      featuredJson: "[]",
      booksJson: jsonTestBooks,
      seriesJson: jsonTestSeries,
      tropesJson: jsonTestTropes,
      prefs: sharedPreferences,
    );
    dataRepository = DataRepositoryImpl(storageManager);
    dataRepository.load().then((_) {
      if (mounted) {
        setState(() {
          isReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isReady) {
      return Container(
        color: ThemeColors.accentBackground,
      );
    }

    return MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: sharedPreferences),
        Provider<StorageManager>.value(value: storageManager),
        Provider<DataRepository>.value(value: dataRepository),
        Provider<LibraryManager>(
            create: (context) => LibraryManagerPrefsImpl(
                context.read<SharedPreferences>(),
                context.read<DataRepository>()),
            lazy: false),
        ChangeNotifierProvider<LibraryState>(
            create: (context) =>
                LibraryStateImpl(context.read<LibraryManager>())),
        ChangeNotifierProvider<AudioPlayer>(
            create: (context) => AudioPlayerImpl(
                  context.read<LibraryState>(),
                )),
      ],
      child: widget.child,
    );
  }
}

bool isTestEnvironment() => kDebugMode || (kEnvironment == "TEST");
