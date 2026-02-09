import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/deck_provider.dart';
import '../scheduler/deck_options.dart';

class DeckOptionsScreen extends ConsumerStatefulWidget {
  final int deckId;

  const DeckOptionsScreen({super.key, required this.deckId});

  @override
  ConsumerState<DeckOptionsScreen> createState() => _DeckOptionsScreenState();
}

class _DeckOptionsScreenState extends ConsumerState<DeckOptionsScreen> {
  DeckOptions? _options;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final options = await ref
        .read(deckListProvider.notifier)
        .getDeckOptions(widget.deckId);
    if (mounted) {
      setState(() {
        _options = options;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_options == null) return;
    await ref
        .read(deckListProvider.notifier)
        .updateDeckOptions(widget.deckId, _options!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Deck Options'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: _loading || _options == null
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                children: [
                  CupertinoListSection.insetGrouped(
                    header: const Text('NEW CARDS'),
                    children: [
                      _StepperTile(
                        title: 'New cards/day',
                        value: _options!.maxNewPerDay,
                        onChanged: (v) => setState(
                            () => _options = _options!.copyWith(maxNewPerDay: v)),
                      ),
                      _TextInputTile(
                        title: 'Learning steps (min)',
                        value: _options!.learnSteps.join(', '),
                        onChanged: (v) {
                          final steps = v
                              .split(RegExp(r'[,\s]+'))
                              .where((s) => s.isNotEmpty)
                              .map((s) => int.tryParse(s))
                              .whereType<int>()
                              .toList();
                          if (steps.isNotEmpty) {
                            setState(() => _options =
                                _options!.copyWith(learnSteps: steps));
                          }
                        },
                      ),
                      _StepperTile(
                        title: 'Graduating interval (days)',
                        value: _options!.graduatingInterval,
                        onChanged: (v) => setState(() =>
                            _options = _options!.copyWith(graduatingInterval: v)),
                      ),
                      _StepperTile(
                        title: 'Easy interval (days)',
                        value: _options!.easyInterval,
                        onChanged: (v) => setState(() =>
                            _options = _options!.copyWith(easyInterval: v)),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: const Text('REVIEWS'),
                    children: [
                      _StepperTile(
                        title: 'Max reviews/day',
                        value: _options!.maxReviewsPerDay,
                        step: 10,
                        onChanged: (v) => setState(() => _options =
                            _options!.copyWith(maxReviewsPerDay: v)),
                      ),
                      _StepperTile(
                        title: 'Starting ease (%)',
                        value: _options!.startingEase ~/ 10,
                        step: 5,
                        min: 130,
                        max: 500,
                        onChanged: (v) => setState(() =>
                            _options = _options!.copyWith(startingEase: v * 10)),
                      ),
                      _StepperTile(
                        title: 'Max interval (days)',
                        value: _options!.maxInterval,
                        step: 365,
                        max: 99999,
                        onChanged: (v) => setState(() =>
                            _options = _options!.copyWith(maxInterval: v)),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: const Text('LAPSES'),
                    children: [
                      _TextInputTile(
                        title: 'Relearning steps (min)',
                        value: _options!.relearningSteps.join(', '),
                        onChanged: (v) {
                          final steps = v
                              .split(RegExp(r'[,\s]+'))
                              .where((s) => s.isNotEmpty)
                              .map((s) => int.tryParse(s))
                              .whereType<int>()
                              .toList();
                          setState(() => _options =
                              _options!.copyWith(relearningSteps: steps));
                        },
                      ),
                      _StepperTile(
                        title: 'New interval (%)',
                        value: (_options!.newIntervalMultiplier * 100).round(),
                        step: 5,
                        min: 0,
                        max: 100,
                        onChanged: (v) => setState(() => _options =
                            _options!.copyWith(
                                newIntervalMultiplier: v / 100.0)),
                      ),
                      _StepperTile(
                        title: 'Minimum interval (days)',
                        value: _options!.minInterval,
                        onChanged: (v) => setState(() =>
                            _options = _options!.copyWith(minInterval: v)),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _StepperTile extends StatelessWidget {
  final String title;
  final int value;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperTile({
    required this.title,
    required this.value,
    this.step = 1,
    this.min = 0,
    this.max = 99999,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minimumSize: const Size(28, 28),
            onPressed: value > min ? () => onChanged(value - step) : null,
            child: const Icon(CupertinoIcons.minus_circle, size: 22),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minimumSize: const Size(28, 28),
            onPressed: value < max ? () => onChanged(value + step) : null,
            child: const Icon(CupertinoIcons.plus_circle, size: 22),
          ),
        ],
      ),
    );
  }
}

class _TextInputTile extends StatelessWidget {
  final String title;
  final String value;
  final ValueChanged<String> onChanged;

  const _TextInputTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      title: Text(title),
      trailing: SizedBox(
        width: 120,
        child: CupertinoTextField(
          controller: TextEditingController(text: value),
          textAlign: TextAlign.right,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onSubmitted: onChanged,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
