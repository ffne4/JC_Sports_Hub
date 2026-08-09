import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});
  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  final TextEditingController _suggestionController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isSubmitting = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUserId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .get();
    if (doc.exists && mounted) {
      setState(() => _userData = doc.data() as Map<String, dynamic>);
    }
  }

  @override
  void dispose() {
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _submitSuggestion() async {
    if (_suggestionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please write your suggestion first'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('suggestions').add({
        'userId': _currentUserId ?? 'guest',
        'userName': _userData?['fullName'] ?? 'Guest',
        'userType': _userData?['userType'] ?? 'guest',
        'content': _suggestionController.text.trim(),
        'adminReply': '',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      setState(() => _isSubmitting = false);
      _suggestionController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Suggestion submitted! Admin will review it.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
        // SUBMIT FORM
        Container(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          color: Colors.white,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Share Your Idea',
                style: TextStyle(
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                'Suggest improvements, activities or anything for JC Sports Hub',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: AppSizes.fontSmall)),
            const SizedBox(height: 12),
            TextField(
              controller: _suggestionController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Type your suggestion here...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitSuggestion,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Submit Suggestion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMedium)),
                ),
              ),
            ),
          ]),
        ),

        const Divider(height: 1),

        // MY SUGGESTIONS LIST
        Expanded(
          child: _currentUserId == null
              ? Center(
                  child: Text('Log in to see your suggestions',
                      style: TextStyle(color: Colors.grey.shade400)))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('suggestions')
                      .where('userId', isEqualTo: _currentUserId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No suggestions yet',
                                  style: TextStyle(
                                      fontSize: AppSizes.fontLarge,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Be the first to share an idea!',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: AppSizes.fontSmall)),
                            ]),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildSuggestionCard(data);
                      },
                    );
                  },
                ),
              ),
        ]);
  }

  Widget _buildSuggestionCard(Map<String, dynamic> data) {
    final bool hasReply =
        data['adminReply'] != null && data['adminReply'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // YOUR SUGGESTION
        Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  _userData?['fullName'] != null
                      ? (_userData!['fullName'] as String)[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_userData?['fullName'] ?? 'You',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontSmall)),
                Text('Your suggestion',
                    style:
                        TextStyle(color: Colors.grey.shade400, fontSize: 10)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      hasReply ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasReply ? 'Replied' : 'Pending',
                  style: TextStyle(
                    color: hasReply ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              ),
              child: Text(data['content'] ?? '',
                  style: const TextStyle(
                      fontSize: AppSizes.fontSmall, height: 1.4)),
            ),
          ]),
        ),

        // ADMIN REPLY
        if (hasReply) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
              border: Border.all(color: Colors.green.shade200),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.admin_panel_settings, color: Colors.green, size: 14),
                SizedBox(width: 6),
                Text('Admin replied:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: AppSizes.fontSmall)),
              ]),
              const SizedBox(height: 6),
              Text(data['adminReply'],
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: AppSizes.fontSmall,
                      height: 1.4)),
            ]),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text('Admin will review and reply soon.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ),
        ],
      ]),
    );
  }
}
