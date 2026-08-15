import 'package:flutter/material.dart';
import '../../../services/match_service.dart';
import '../../../utils/constants.dart';

class ScheduleMatchForm extends StatefulWidget {
  const ScheduleMatchForm({super.key});

  @override
  State<ScheduleMatchForm> createState() => _ScheduleMatchFormState();
}

class _ScheduleMatchFormState extends State<ScheduleMatchForm> {
  final _teamAController = TextEditingController();
  final _teamBController = TextEditingController();
  final _venueController = TextEditingController();
  final _notesController = TextEditingController();
  final _oddsAController = TextEditingController(text: '1.5');
  final _oddsBController = TextEditingController(text: '2.0');
  String _selectedSport = 'Football';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isScheduling = false;

  final List<String> _sports = [
    'Football',
    'Netball',
    'Volleyball',
    'Chess',
    'Scrabble',
    'Ludo',
    'Matatu',
  ];

  @override
  void dispose() {
    _teamAController.dispose();
    _teamBController.dispose();
    _venueController.dispose();
    _notesController.dispose();
    _oddsAController.dispose();
    _oddsBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule a Match',
          style: TextStyle(
            fontSize: AppSizes.fontLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Sport', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _sports.map((sport) {
              final bool isSelected = _selectedSport == sport;
              return GestureDetector(
                onTap: () => setState(() => _selectedSport = sport),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300),
                  ),
                  child: Text(sport,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _field(_teamAController, 'Team A Name', Icons.group),
        const SizedBox(height: 12),
        _field(_teamBController, 'Team B Name', Icons.group),
        const SizedBox(height: 12),
        _field(_venueController, 'Venue', Icons.location_on),
        const SizedBox(height: 12),
        const Text('Set Odds',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: AppSizes.fontSmall)),
        const SizedBox(height: 4),
        Text(
            'Example: Team A = 1.5x means a 1000 UGX bet wins 1500 UGX',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _oddsAController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Team A Odds (e.g. 1.5)',
                  prefixIcon: const Icon(Icons.trending_up, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _oddsBController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Team B Odds (e.g. 2.0)',
                  prefixIcon: const Icon(Icons.trending_up, color: Colors.orange),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                      borderSide:
                          const BorderSide(color: Colors.orange, width: 2)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)));
            if (date != null) {
              final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_selectedDate));
              if (time != null) {
                setState(() {
                  _selectedDate = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute);
                });
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} at '
                  '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: AppSizes.fontSmall),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Admin Notes (optional)',
            prefixIcon: const Icon(Icons.notes, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isScheduling ? null : _scheduleMatch,
            icon: _isScheduling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sports_soccer),
            label: const Text('Schedule Match'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMedium))),
          ),
        ),
      ],
  );
}

  Future<void> _scheduleMatch() async {
    if (_teamAController.text.trim().isEmpty ||
        _teamBController.text.trim().isEmpty ||
        _venueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: AppColors.error));
      return;
    }
    final oddsA = double.tryParse(_oddsAController.text) ?? 1.5;
    final oddsB = double.tryParse(_oddsBController.text) ?? 2.0;
    if (oddsA < 1.01 || oddsB < 1.01) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Odds must be at least 1.01'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isScheduling = true);
    final result = await MatchService().scheduleMatch(
      sport: _selectedSport,
      teamA: _teamAController.text.trim(),
      teamB: _teamBController.text.trim(),
      venue: _venueController.text.trim(),
      matchDate: _selectedDate,
      oddsA: oddsA,
      oddsB: oddsB,
      adminNotes: _notesController.text.trim(),
    );
    setState(() => _isScheduling = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      if (result['success']) {
        _teamAController.clear();
        _teamBController.clear();
        _venueController.clear();
        _notesController.clear();
        _oddsAController.text = '1.5';
        _oddsBController.text = '2.0';
      }
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }
}
