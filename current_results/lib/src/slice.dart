// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:grpc/grpc.dart';

import 'package:current_results/src/result.dart';
import 'package:current_results/src/generated/query.pb.dart' as query_api;
import 'package:current_results/src/generated/result.pb.dart' as api;

int compareNames(Result a, Result b) => a.name.compareTo(b.name);

int compareNamesPrefixMatchesBelow(Result a, Result b) =>
    a.name.compareTo(b.name) < 0 || a.name.startsWith(b.name) ? -1 : 1;

/// Holds the test results for all configurations.
/// Answers queries about the test results.
/// Used for holding the current test results in memory.
/// Can also be used to hold a snapshot of results data at a past time.
class Slice {
  /// The current results, stored separately for each configuration in a
  /// list sorted by test name.
  final _stored = <String, List<Result>>{};

  /// A sorted list of all test names seen. Names are not removed from this list.
  List<String> testNames = [];
  int _size = 0;

  int get size => _size;

  void add(List<String> lines) {
    if (lines.isEmpty) return;
    final results = lines.map((line) => Result.fromApi(api.Result()
      ..mergeFromProto3Json(json.decode(line),
          supportNamesWithUnderscores: true)));
    final configuration = results.first.configuration;
    if (results.any((result) => result.configuration != configuration)) {
      print('Loaded results list with multiple configurations: '
          'first result: ${results.first}');
      return;
    }
    final sorted = results.toList()..sort(compareNames);
    _size -= _stored[configuration]?.length ?? 0;
    _stored[configuration] = sorted;
    _size += sorted.length;
    testNames = _mergeIfNeeded(testNames, sorted);
    print('latest results of $configuration: ${sorted.length} results '
        '(total: $_size)');
  }

  static List<String> _mergeIfNeeded(List<String> names, List<Result> sorted) {
    var i = 0;
    var j = 0;
    while (i < names.length && j < sorted.length) {
      final compare = names[i].compareTo(sorted[j].name);
      if (compare < 0) {
        i++;
      } else if (compare == 0) {
        i++;
        j++;
      } else
        break;
    }
    if (j == sorted.length) return names;

    // J points to the first unfound element in sorted.
    // I points to the first element in names greater than the unfound name.
    final result = names.sublist(0, i);
    while (i < names.length && j < sorted.length) {
      final compare = names[i].compareTo(sorted[j].name);
      if (compare <= 0) {
        result.add(names[i++]);
        if (compare == 0) j++;
      } else {
        result.add(sorted[j++].name);
      }
    }
    if (i < names.length) {
      result.addAll(names.getRange(i, names.length));
    }
    while (j < sorted.length) {
      result.add(sorted[j++].name);
    }
    print('Added ${result.length - names.length} new test names '
        '(total ${result.length})');
    return result;
  }

  query_api.GetResultsResponse query(query_api.GetResultsRequest query) {
    final response = query_api.GetResultsResponse();
    final configurations =
        query.configurations.isEmpty ? _stored.keys : query.configurations;
    if (query.names.isEmpty) {
      for (final configuration in configurations) {
        response.results.addAll(_stored[configuration].map(Result.toApi));
      }
      return response;
    }
    for (final configuration in configurations) {
      final sorted = _stored[configuration];
      if (sorted == null) {
        throw GrpcError.notFound(
            "Results for configuration $configuration not found");
      }
      for (final testNamePrefix in query.names) {
        final prefixResult =
            Result(testNamePrefix, null, null, null, null, null, null);
        final start =
            lowerBound<Result>(sorted, prefixResult, compare: compareNames);
        if (start < sorted.length &&
            sorted[start].name.startsWith(testNamePrefix)) {
          var end = start + 1;
          if (end < sorted.length &&
              sorted[end].name.startsWith(testNamePrefix)) {
            end = lowerBound<Result>(sorted, prefixResult,
                compare: compareNamesPrefixMatchesBelow);
          }
          response.results
              .addAll(sorted.getRange(start, end).map(Result.toApi));
        }
      }
    }
    return response;
  }
}
