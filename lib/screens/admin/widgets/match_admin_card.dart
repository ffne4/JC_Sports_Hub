import 'package:flutter/material.dart';
import '../../../services/match_service.dart';
import '../../../models/match_model.dart';
import '../../../utils/constants.dart';

class MatchAdminCard extends StatefulWidget {
  final MatchModel match;
  const MatchAdminCard({super.key, required this.match});

  @override
  State<MatchAdminCard> createState() => _MatchAdminCardState();
}

class _MatchAdminCardState extends State<MatchAdminCard> {
  late TextEditingController _scoreAController;
  late TextEditingController _scoreBController;
  late TextEditingController _oddsAController;
  late TextEditingController _oddsBController;
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _scoreAController =
        TextEditingController(text: widget.match.scoreA.toString());
    _scoreBController =
        TextEditingController(text: widget.match.scoreB.toString());
    _oddsAController =
        TextEditingController(text: widget.match.oddsA.toStringAsFixed(2));
    _oddsBController =
        TextEditingController(text: widget.match.oddsB.toStringAsFixed(2));
    _currentStatus = widget.match.status;
  }

  @override
  void dispose() {
    _scoreAController.dispose();
    _scoreBController.dispose();
    _oddsAController.dispose();
    _oddsBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSizes.radiusMedium),
              topRight: Radius.circular(AppSizes.radiusMedium),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.match.teamA} vs ${widget.match.teamB}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.fontMedium)),
                    Text('${widget.match.venue} | ${widget.match.sport}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                  ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.error, size: 18),
              onPressed: () async =>
                  await MatchService().deleteMatch(widget.match.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Odds: ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontSmall)),
              Expanded(
                  child: TextField(
                controller: _oddsAController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: widget.match.teamA,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                controller: _oddsBController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: widget.match.teamB,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final a = double.tryParse(_oddsAController.text) ??
                      widget.match.oddsA;
                  final b = double.tryParse(_oddsBController.text) ??
                      widget.match.oddsB;
                  await MatchService().updateOdds(widget.match.id, a, b);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Odds updated!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSmall))),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _scoreAController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: widget.match.teamA,
                    prefixIcon: const Icon(Icons.score, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _scoreBController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: widget.match.teamB,
                    prefixIcon: const Icon(Icons.score, color: Colors.orange),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating
                      ? null
                      : () async {
                          final scoreA = int.tryParse(_scoreAController.text) ?? 0;
                          final scoreB = int.tryParse(_scoreBController.text) ?? 0;
                          setState(() => _isUpdating = true);
                          final result = await MatchService().updateScore(
                            matchId: widget.match.id,
                            scoreA: scoreA,
                            scoreB: scoreB,
                            status: _currentStatus,
                          );
                          setState(() => _isUpdating = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(result['message']),
                              backgroundColor: result['success']
                                  ? Colors.green
                                  : AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Update Score'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSmall))),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await MatchService().deleteMatch(widget.match.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Match deleted'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSmall))),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
