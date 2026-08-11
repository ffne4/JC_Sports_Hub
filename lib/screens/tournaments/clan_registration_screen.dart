import 'package:flutter/material.dart';
import '../../data/inter_clan_games_constants.dart';
import '../../models/tournament_model.dart';
import '../../services/tournament_service.dart';
import '../../utils/constants.dart';

/// Admin-facing version of the workbook Registration sheet.
class TribeRegistrationScreen extends StatefulWidget {
  final TournamentModel tournament;
  const TribeRegistrationScreen({super.key, required this.tournament});

  @override
  State<TribeRegistrationScreen> createState() => _TribeRegistrationScreenState();
}

class _TribeRegistrationScreenState extends State<TribeRegistrationScreen> {
  final _service = TournamentService();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tribe registrations')),
        body: StreamBuilder<List<TribeRegistration>>(
          stream: _service.getTribeRegistrations(widget.tournament.id),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const <TribeRegistration>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Registration window: 10–17 Aug 2026',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                ...InterClanGames2026.clans.map((tribe) {
                  final entry =
                      entries.where((e) => e.tribe == tribe).firstOrNull;
                  return Card(
                    child: ListTile(
                      title: Text(tribe),
                      subtitle: Text(entry?.captainName.isNotEmpty == true
                          ? '${entry!.captainName} • ${entry.phoneContact}'
                          : 'Not registered'),
                      trailing: Icon(entry?.isRegistered == true
                          ? Icons.check_circle
                          : Icons.edit),
                      onTap: () => _edit(entry ??
                          TribeRegistration(
                              id: tribe,
                              tournamentId: widget.tournament.id,
                              tribe: tribe)),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      );

  Future<void> _edit(TribeRegistration entry) async {
    final captain = TextEditingController(text: entry.captainName);
    final phone = TextEditingController(text: entry.phoneContact);
    final football = TextEditingController(text: entry.footballSquadNumber);
    final netball = TextEditingController(text: entry.netballSquadNumber);
    final volleyball = TextEditingController(text: entry.volleyballSquadNumber);
    final chess = TextEditingController(text: entry.chessPlayers);
    final scrabble = TextEditingController(text: entry.scrabblePlayers);
    final ludo = TextEditingController(text: entry.ludoPlayers);
    final matatu = TextEditingController(text: entry.matatuPlayers);
    var registered = entry.isRegistered;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(entry.tribe),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(captain, 'Captain name'),
              _field(phone, 'Phone contact'),
              _field(football, 'Football squad #'),
              _field(netball, 'Netball squad #'),
              _field(volleyball, 'Volleyball squad #'),
              _field(chess, 'Chess players'),
              _field(scrabble, 'Scrabble players'),
              _field(ludo, 'Ludo players'),
              _field(matatu, 'Matatu players'),
              SwitchListTile(
                  value: registered,
                  title: const Text('Registered'),
                  onChanged: (v) => setDialogState(() => registered = v)),
            ],
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () async {
                  try {
                    await _service.updateTribeRegistration(
                        widget.tournament.id,
                        TribeRegistration(
                          id: entry.id,
                          tournamentId: entry.tournamentId,
                          tribe: entry.tribe,
                          captainName: captain.text.trim(),
                          phoneContact: phone.text.trim(),
                          footballSquadNumber: football.text.trim(),
                          netballSquadNumber: netball.text.trim(),
                          volleyballSquadNumber: volleyball.text.trim(),
                          chessPlayers: chess.text.trim(),
                          scrabblePlayers: scrabble.text.trim(),
                          ludoPlayers: ludo.text.trim(),
                          matatuPlayers: matatu.text.trim(),
                          isRegistered: registered,
                          registeredAt: registered ? DateTime.now() : null,
                        ));
                    if (mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save')),
          ],
        ),
      ),
    );
    for (final controller in [
      captain,
      phone,
      football,
      netball,
      volleyball,
      chess,
      scrabble,
      ludo,
      matatu
    ]) {
      controller.dispose();
    }
  }

  Widget _field(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label)),
      );
}
