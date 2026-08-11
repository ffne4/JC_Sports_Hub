import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/match_service.dart';
import '../../../data/inter_clan_fixture_seed.dart';
import '../../../utils/constants.dart';

class ImportFixturesButton extends StatefulWidget {
  const ImportFixturesButton({super.key});

  @override
  State<ImportFixturesButton> createState() => _ImportFixturesButtonState();
}

class _ImportFixturesButtonState extends State<ImportFixturesButton> {
  bool _isImporting = false;

  Future<void> _importFixtures() async {
    setState(() => _isImporting = true);
    try {
      final fixtures = InterClanFixtureSeed.build('inter-tribe-2026');
      final fixtureMaps = fixtures.map((f) => f.toMap()).toList();
      final result = await MatchService().replaceAllFixtures(fixtureMaps);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isImporting ? null : _importFixtures,
        icon: _isImporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.import_export),
        label: Text(_isImporting ? 'Importing...' : 'Import Verified Tournament Fixtures'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          ),
        ),
      ),
    );
  }
}
