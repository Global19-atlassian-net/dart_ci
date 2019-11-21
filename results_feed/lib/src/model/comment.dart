// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:firebase/firestore.dart' show DocumentSnapshot;

class Comment {
  final String id;
  final String author;
  final DateTime created;
  final String comment;
  final String link;
  final bool approved;
  final List<String> results;
  final List<String> tryResults;
  final String baseComment;
  final int blamelistStartIndex;
  final int blamelistEndIndex;
  final int pinnedIndex;
  final int gerritChange;
  final int patchset;

  Comment(
      this.id,
      this.author,
      this.created,
      this.comment,
      this.link,
      this.approved,
      List _results,
      List _tryResults,
      this.baseComment,
      this.blamelistStartIndex,
      this.blamelistEndIndex,
      this.pinnedIndex,
      this.gerritChange,
      this.patchset)
      : results = List<String>.from(_results),
        tryResults = List<String>.from(_tryResults);

  Comment.fromDocument(DocumentSnapshot document)
      : id = document.id,
        author = document.get('author'),
        created = document.get('created'),
        comment = document.get('comment'),
        link = document.get('link'),
        approved = document.get('approved'),
        results = List<String>.from(document.get('results') ?? []),
        tryResults = List<String>.from(document.get('tryResults') ?? []),
        baseComment = document.get('base_comment'),
        blamelistStartIndex = document.get('blamelist_start_index'),
        blamelistEndIndex = document.get('blamelist_start_index'),
        pinnedIndex = document.get('pinned_index'),
        gerritChange = document.get('gerrit_change'),
        patchset = document.get('patchset');
}