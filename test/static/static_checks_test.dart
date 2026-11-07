@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The project's own static checks: rules no general linter knows, read
/// straight from the source. Run with the analyzer and the formatter by
/// tool/static_checks.ps1.
///
/// Each check says what it protects, so a failure reads as a reason, not a
/// regex.
void main() {
  String read(String path) => File(path).readAsStringSync();

  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rel(File f) => f.path.replaceAll(r'\', '/');

  /// String literals in [source], single- and double-quoted, one line each.
  final quoted = RegExp(
    r"'((?:[^'\\\n]|\\.)*)'" '|' r'"((?:[^"\\\n]|\\.)*)"',
  );
  Iterable<String> literals(String source) =>
      quoted.allMatches(source).map((m) => m.group(1) ?? m.group(2) ?? '');

  final arabic = RegExp('[؀-ۿ]');

  group('layers', () {
    // The journey's rules are plain Dart, so they run in any test and the
    // app and the dashboard rank, count and schedule the same way.
    const pure = [
      'lib/data/journey/journey_engine.dart',
      'lib/data/journey/journey_models.dart',
      'lib/data/journey/journey_points.dart',
      'lib/data/journey/journey_copy.dart',
      'lib/data/journey/memorization.dart',
      'lib/data/journey/weekly_board.dart',
      'lib/data/journey/reading_tracker.dart',
      'lib/data/services/notification_planner.dart',
    ];

    test('the journey rules import no Flutter and no Firebase', () {
      for (final path in pure) {
        final imports = RegExp(r"^import '([^']+)'", multiLine: true)
            .allMatches(read(path))
            .map((m) => m.group(1)!);
        for (final import in imports) {
          expect(
            import.startsWith('package:flutter/') ||
                import.startsWith('package:cloud_firestore') ||
                import.startsWith('package:firebase_'),
            isFalse,
            reason: '$path imports $import',
          );
        }
      }
    });

    test('the journey rules never read the clock themselves', () {
      // A rule that reads DateTime.now() cannot be tested for a given day,
      // and two phones could disagree about one.
      for (final path in pure) {
        expect(read(path), isNot(contains('DateTime.now(')), reason: path);
      }
    });

    test('the journey and memorization screens never touch Firestore', () {
      for (final file in [
        ...dartFiles('lib/features/journey'),
        ...dartFiles('lib/features/memorize'),
      ]) {
        expect(
          read(file.path),
          isNot(contains('package:cloud_firestore')),
          reason: '${rel(file)} should go through the repository',
        );
      }
    });

    test('the app never ships an emulator address', () {
      for (final file in dartFiles('lib')) {
        final source = read(file.path);
        for (final host in ['10.0.2.2', 'localhost', '127.0.0.1']) {
          expect(source, isNot(contains(host)), reason: rel(file));
        }
      }
    });
  });

  group('words readers see', () {
    // From the voice the user asked for: written by a person, so no
    // exclamation marks and no emoji; and points measure activity in the
    // app, never reward, so no talk of حسنات.
    final readerFacing = [
      File('lib/data/journey/journey_copy.dart'),
      ...dartFiles('lib/features/journey'),
      ...dartFiles('lib/features/memorize'),
      File('lib/features/hadith/hadith_detail_screen.dart'),
    ];
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}]',
      unicode: true,
    );

    test('no exclamation marks', () {
      for (final file in readerFacing) {
        for (final text in literals(read(file.path))) {
          if (!arabic.hasMatch(text)) continue;
          // Code inside an interpolation is not words: `${due!}` is Dart.
          final words = text.replaceAll(RegExp(r'\$\{[^}]*\}'), '');
          expect(
            words.contains('!') || words.contains('！'),
            isFalse,
            reason: '${rel(file)}: $text',
          );
        }
      }
    });

    test('no emoji', () {
      for (final file in readerFacing) {
        for (final text in literals(read(file.path))) {
          expect(emoji.hasMatch(text), isFalse, reason: '${rel(file)}: $text');
        }
      }
    });

    test('points are never called a reward', () {
      for (final file in readerFacing) {
        for (final text in literals(read(file.path))) {
          expect(text, isNot(contains('حسنات')), reason: rel(file));
        }
      }
    });

    test('every icon button can be named by a screen reader', () {
      for (final file in dartFiles('lib')) {
        final source = read(file.path);
        for (final match
            in RegExp(r'\bIconButton(\.\w+)?\(').allMatches(source)) {
          var depth = 0;
          var end = match.end - 1;
          for (var i = match.end - 1; i < source.length; i++) {
            if (source[i] == '(') depth++;
            if (source[i] == ')' && --depth == 0) {
              end = i;
              break;
            }
          }
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          expect(
            source.substring(match.start, end),
            contains('tooltip:'),
            reason: '${rel(file)}:$line',
          );
        }
      }
    });

    test('journey screens take their colours from the theme', () {
      // The posters are the exception: they are always the light treatment,
      // whatever mode the reader is in, so they carry fixed colours.
      final raw = RegExp(r'(^|[^A-Za-z])(Color\(0x|Colors\.(?!transparent)\w)');
      for (final file in [
        ...dartFiles('lib/features/journey'),
        ...dartFiles('lib/features/memorize'),
      ]) {
        if (rel(file).endsWith('journey_posters.dart')) continue;
        final lines = read(file.path).split('\n');
        var inPosterColours = false;
        for (var i = 0; i < lines.length; i++) {
          // The tree drawn on a poster: the same fixed light treatment.
          if (lines[i].contains('factory TreeColors.poster(')) {
            inPosterColours = true;
          }
          if (inPosterColours) {
            if (lines[i].trim() == ');') inPosterColours = false;
            continue;
          }
          if (lines[i].trimLeft().startsWith('//')) continue;
          expect(
            raw.hasMatch(lines[i]),
            isFalse,
            reason: '${rel(file)}:${i + 1}: ${lines[i].trim()}',
          );
        }
      }
    });
  });

  group('firestore.rules', () {
    final rules = read('firestore.rules').replaceAll('\r\n', '\n');

    test('ends by denying everything not matched above', () {
      final last = rules.lastIndexOf('match /{document=**}');
      expect(last, greaterThan(0));
      expect(rules.substring(last), contains('allow read, write: if false'));
    });

    test('nothing can be written by anyone', () {
      for (final verb in ['write', 'create', 'update', 'delete']) {
        expect(
          RegExp('allow [a-z, ]*$verb[a-z, ]*: if true').hasMatch(rules),
          isFalse,
          reason: 'an open $verb',
        );
      }
    });

    test('only public content is readable without an account', () {
      final open = <String>[];
      final matches = RegExp(r'match (/[^ ]+) \{').allMatches(rules).toList();
      for (final read in RegExp('allow read: if true').allMatches(rules)) {
        final owner = matches.lastWhere((m) => m.start < read.start);
        open.add(owner.group(1)!);
      }
      expect(
        open,
        unorderedEquals([
          '/hadiths/{hadithId}',
          '/dailyMessages/{messageId}',
          // The reminder pool a guest's reminders are drawn from.
          '/notificationMessages/{messageId}',
          '/settings/{settingId}',
          '/usernames/{nameKey}',
        ]),
      );
    });

    test('every collection the app uses has its own rules', () {
      final used = <String>{};
      for (final file in dartFiles('lib')) {
        used.addAll(
          RegExp(r"collection\('([A-Za-z]+)'\)")
              .allMatches(read(file.path))
              .map((m) => m.group(1)!),
        );
      }
      for (final name in used) {
        expect(rules, contains('match /$name/'), reason: name);
      }
    });

    test("a reader's journey is theirs alone", () {
      for (final path in [
        'match /journey/{docId}',
        'match /journeyYears/{year}',
      ]) {
        final start = rules.indexOf(path);
        final block =
            rules.substring(start, rules.indexOf('}\n', start + path.length));
        expect(block, contains('request.auth.uid == uid'), reason: path);
        expect(block, isNot(contains('isModerator')), reason: path);
      }
    });

    test('the board is bounded where the phone could inflate it', () {
      expect(rules, contains('d.device <= 300'));
      expect(rules, contains('d.memo <= 210'));
      expect(rules, contains('d.points.size() <= 10'));
    });

    test('the indexes file is valid and names only ruled collections', () {
      final indexes = jsonDecode(read('firestore.indexes.json')) as Map;
      for (final index in [
        ...(indexes['indexes'] as List? ?? const []),
        ...(indexes['fieldOverrides'] as List? ?? const []),
      ]) {
        final group = (index as Map)['collectionGroup'] as String;
        expect(rules, contains('match /$group/'), reason: group);
      }
    });
  });

  group('privacy', () {
    test('the hosted policy has every section the app has', () {
      final inApp = RegExp(r'\*\*([^*]+?)\*\*')
          .allMatches(read('lib/core/legal/legal_documents.dart'))
          .map((m) => m.group(1)!)
          .toSet();
      final hosted = RegExp('<strong>([^<]+)</strong>')
          .allMatches(read('web/privacy-policy.html'))
          .map((m) => m.group(1)!)
          .toSet();
      expect(hosted, containsAll(inApp));
    });

    test('everything the journey stores is named in the policy', () {
      final policy = read('lib/core/legal/legal_documents.dart');
      for (final phrase in ['رحلتك', 'لوحة الأسبوع', 'ما حفظته', 'فاعل خير']) {
        expect(policy, contains(phrase));
      }
    });

    test('the deletion page lists the journey, the board and memorizing', () {
      final page = read('web/delete-account.html');
      for (final phrase in ['رحلتك في القراءة', 'لوحة الأسبوع', 'ما حفظته']) {
        expect(page, contains(phrase));
      }
    });

    test('deleting an account removes everything the journey stores', () {
      final source = read('lib/data/services/account_deletion_service.dart');
      for (final part in [
        "collection('journey')",
        "collection('journeyYears')",
        "collection('scores')",
        "collection('favorites')",
      ]) {
        expect(source, contains(part));
      }
    });

    test('no secret is committed', () async {
      final tracked = await Process.run('git', ['ls-files']);
      expect(tracked.exitCode, 0);
      final files = (tracked.stdout as String)
          .split('\n')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty);
      for (final path in files) {
        expect(
          path.toLowerCase(),
          isNot(contains('service-account')),
          reason: path,
        );
        final file = File(path);
        if (!file.existsSync() || file.lengthSync() > 2000000) continue;
        String text;
        try {
          text = file.readAsStringSync();
        } on FileSystemException {
          continue; // not text
        }
        // Joined here so this file, once committed, is not its own match.
        expect(text, isNot(contains('-----BEGIN ' 'PRIVATE KEY')),
            reason: path);
        expect(text, isNot(contains('"private' '_key"')), reason: path);
      }
    });
  });

  group('the project holds together', () {
    test('every asset the code names exists and is bundled', () {
      final declared = RegExp(r'^\s+- (assets/[^\s#]*)', multiLine: true)
          .allMatches(read('pubspec.yaml'))
          .map((m) => m.group(1)!)
          .toList();
      for (final file in dartFiles('lib')) {
        for (final m
            in RegExp(r"'(assets/[^'$]+)'").allMatches(read(file.path))) {
          final path = m.group(1)!;
          expect(
            File(path).existsSync(),
            isTrue,
            reason: '${rel(file)}: $path',
          );
          expect(declared.any(path.startsWith), isTrue, reason: path);
        }
      }
    });

    test('every shared suite runs on the host and on a device', () {
      for (final suite
          in Directory('test/suites').listSync().whereType<File>()) {
        final name = suite.uri.pathSegments.last;
        bool importedFrom(String dir) => dartFiles(dir).any(
              (f) =>
                  f.path != suite.path && read(f.path).contains('suites/$name'),
            );
        expect(importedFrom('test'), isTrue, reason: '$name has no host entry');
        expect(
          importedFrom('integration_test'),
          isTrue,
          reason: '$name has no device entry',
        );
      }
    });

    test('notification payloads cannot be mistaken for one another', () {
      final planner = read('lib/data/services/notification_planner.dart');
      final prefixes = RegExp(r"const _\w+Prefix = '([^']+)'")
          .allMatches(planner)
          .map((m) => m.group(1)!)
          .toList();
      expect(prefixes, containsAll(['hadith:', 'review:']));
      for (final a in prefixes) {
        for (final b in prefixes) {
          if (a != b) expect(a.startsWith(b), isFalse, reason: '$a vs $b');
        }
      }
    });
  });
}
