import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/features/dashboard/dashboard_refresh.dart';

class _Page extends StatefulWidget {
  const _Page({required this.loads, this.gate});

  final List<int> loads;
  final Completer<void>? Function()? gate;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with DashboardAutoRefresh {
  @override
  Set<String> get watchedCollections => const {'dailyMessages'};

  @override
  Future<void> loadData() async {
    widget.loads.add(widget.loads.length);
    await widget.gate?.call()?.future;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget _host(List<int> loads, {required bool visible, Completer<void>? Function()? gate}) =>
    TickerMode(enabled: visible, child: _Page(loads: loads, gate: gate));

void main() {
  testWidgets('a visible tab reloads once for a burst of changes', (tester) async {
    final loads = <int>[];
    await tester.pumpWidget(_host(loads, visible: true));
    expect(loads, hasLength(1)); // initial load

    DashboardRefresh.markChanged(const ['dailyMessages']);
    DashboardRefresh.markChanged(const ['dailyMessages']);
    DashboardRefresh.markChanged(const ['dailyMessages']);
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(2));
  });

  testWidgets('unrelated collections are ignored', (tester) async {
    final loads = <int>[];
    await tester.pumpWidget(_host(loads, visible: true));
    DashboardRefresh.markChanged(const ['users']);
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(1));
  });

  testWidgets('a hidden tab waits until it is shown', (tester) async {
    final loads = <int>[];
    await tester.pumpWidget(_host(loads, visible: false));
    expect(loads, hasLength(1));

    DashboardRefresh.markChanged(const ['dailyMessages']);
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(1));

    await tester.pumpWidget(_host(loads, visible: true));
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(2));

    // Shown again with nothing new and fresh data: no extra request.
    await tester.pumpWidget(_host(loads, visible: false));
    await tester.pumpWidget(_host(loads, visible: true));
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(2));
  });

  testWidgets('a change mid-load queues one follow-up, not overlapping loads',
      (tester) async {
    final loads = <int>[];
    Completer<void>? pending;
    await tester.pumpWidget(
      _host(loads, visible: true, gate: () => pending = Completer<void>()),
    );
    pending!.complete();
    await tester.pump();

    DashboardRefresh.markChanged(const ['dailyMessages']);
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(2)); // second load now in flight

    DashboardRefresh.markChanged(const ['dailyMessages']);
    DashboardRefresh.markChanged(const ['dailyMessages']);
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(2)); // still waiting on the in-flight one

    pending!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(3)); // exactly one follow-up
    pending!.complete();
    await tester.pump();
  });
}
