import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womanly_mobile/domain/entities/book.dart';

class Placement {
  final String name;
  final String subplacement;

  Placement(this.name, [this.subplacement = ""]);

  static Provider<Placement> namedUndefined1(String name,
      {Widget? child, WidgetBuilder? builder}) {
    assert(child != null || builder != null);

    Widget inner() => (builder != null)
        ? LayoutBuilder(builder: (context, _) => builder(context))
        : child!;

    final modifiedName = name
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z_\s]"), '')
        .replaceAll(' ', '_');
    return Provider<Placement>(
        create: (_) => Placement(modifiedName + "_UNDEFINED"), child: inner());
  }

  static Provider<Placement> named(String name,
      {String subplacement = "", Widget? child, WidgetBuilder? builder}) {
    assert(child != null || builder != null);

    Widget inner() => (builder != null)
        ? LayoutBuilder(builder: (context, _) => builder(context))
        : child!;

    return Provider<Placement>(
        create: (_) => Placement(name, subplacement), child: inner());
  }

  static void setLastPlacementForBook(BuildContext context, Book book) {
    final prefs = context.read<SharedPreferences>();
    if (prefs.getString(_keyLastPlacementForBook(book)) != null) {
      //skip
      return;
    }
    prefs.setString(
        _keyLastPlacementForBook(book), context.read<Placement>().name);
  }

  static String getLastPlacementForBook(BuildContext context, Book book) {
    final prefs = context.read<SharedPreferences>();
    String? value = prefs.getString(_keyLastPlacementForBook(book));
    if (value == null) {
      setLastPlacementForBook(context, book);
      value = context.read<Placement>().name;
    }
    return value;
  }

  static String _keyLastPlacementForBook(Book book) =>
      "initialPlacementForBook_${book.id}";
}

const keyPlacementSearchTropes = "search_tropes";
const keyPlacementSearchTropesAlsoCheck = "also_check";
const keyPlacementSearchAuthors = "search_authors";
