// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:core';

// import 'package:angular/angular.dart';
import 'package:dart_results_feed/src/filter_service.dart';
import 'package:firebase/firestore.dart' as firestore;

int compareList(Iterable<Comparable> aList, Iterable bList) {
  final a = aList.iterator;
  final b = bList.iterator;
  while (true) {
    if (!a.moveNext()) return b.moveNext() ? -1 : 0;
    if (!b.moveNext()) return 1;
    final comp = a.current.compareTo(b.current);
    if (comp != 0) return comp;
  }
}

/// Groups a list into sublists of all elements that agree on groupBy.
List<List<T>> grouped<T>(List<T> list, dynamic groupBy(T t)) {
  if (list.isEmpty) return <List<T>>[];
  var previous = list.first;
  final result = [
    [previous]
  ];
  for (final current in list.skip(1)) {
    if (groupBy(previous) == groupBy(current)) {
      result.last.add(current);
    } else {
      result.add([current]);
    }
    previous = current;
  }
  return result;
}

class Commit {
  String hash;
  String author;
  String title;
  DateTime created;
  int index;
  List<List<List<Change>>> changesByConfigsByResult;

  Commit(this.hash, this.author, this.title, this.created, this.index);

  Commit.fromDocument(firestore.DocumentSnapshot document) {
    hash = document.id;
    author = document.get('author');
    title = document.get('title');
    created = document.get('created');
    index = document.get('index');
    changesByConfigsByResult = [];
  }

  void addChanges(List<Change> changes) {
    if (changes == null) return;
    changes.sort();
    this.changesByConfigsByResult = grouped(
        grouped(changes, (Change change) => change.changesText),
        (group) => group.first.configurationsText);
  }

  bool show(FilterService filter) {
    if (filter.showAllCommits) return true;
    if (changesByConfigsByResult.isEmpty) return false;
    bool configurationEnabled(configuration) =>
        filter.enabledBuilderGroups.any(configuration.startsWith);
    if (changesByConfigsByResult.any((configGroup) => configGroup
        .first.first.configurations.configurations
        .any(configurationEnabled))) return true;
    return false;
  }

  String toString() => "$index $hash $author $created $title";
}

/// A list of configurations affected by a result change.
/// The list is canonicalized, and configurations are grouped into
/// summaries of similar configurations.
class Configurations {
  static final _instances = <String, Configurations>{};
  List<String> configurations;
  String text;
  Map<String, List<String>> summaries;

  Configurations._(List<dynamic> configurations)
      : configurations = List<String>.from(configurations),
        text = configurations.join(),
        summaries = _summarize(configurations);

  factory Configurations(List configs) {
    configs.sort();
    return _instances.putIfAbsent(
        configs.join(' '), () => Configurations._(configs.toList()));
  }

  static Map<String, List<String>> _summarize(List<dynamic> configurations) {
    final groups = <String, List<String>>{};
    for (final String configuration in configurations) {
      groups
          .putIfAbsent(configuration.split('-').first, () => <String>[])
          .add(configuration);
    }
    // Sorts the values as a side effect, while changing their keys.
    return SplayTreeMap.fromIterable(groups.values,
        key: (list) => (list..sort).length == 1
            ? list.first
            : list.first.split('-').first + '...');
  }
}

class Change implements Comparable {
  Change._(
      this.name,
      this.configurations,
      this.result,
      this.previousResult,
      this.expected,
      this.blamelistStartIndex,
      this.blamelistEndIndex,
      this.trivialBlamelist)
      : changesText = '$previousResult -> $result (expected $expected)',
        configurationsText = configurations.text;
  Change.fromDocument(firestore.DocumentSnapshot document)
      : this._(
            document.get('name'),
            Configurations(document.get('configurations')),
            document.get('result'),
            document.get('previous_result'),
            document.get('expected'),
            document.get('blamelist_start_index'),
            document.get('blamelist_end_index'),
            document.get('trivial_blamelist'));
  final String name;
  final Configurations configurations;
  final String result;
  final String previousResult;
  final String expected;
  int blamelistStartIndex;
  int blamelistEndIndex;
  bool trivialBlamelist;
  final String configurationsText;
  final String changesText;

  int compareTo(other) => compareList([configurationsText, changesText, name],
      [other.configurationsText, other.changesText, other.name]);
  String resultStyle() => result == expected ? 'success' : 'failure';
}
