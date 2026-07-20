import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../models/match_model.dart';
import '../../models/wallet_model.dart';
import '../../services/post_service.dart';
import '../../services/match_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/constants.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PostService _postService = PostService();
  final TextEditingController _announcementController = TextEditingController();
  bool _isPostingAnnouncement = false;
  final String _adminId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _announcementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Admin Panel',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending Posts'),
            Tab(text: 'Announcements'),
            Tab(text: 'Suggestions'),
            Tab(text: 'Matches'),
            Tab(text: 'Wallet'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingPostsTab(),
          _buildAnnouncementsTab(),
          _buildSuggestionsTab(),
          _MatchesTabWidget(adminId: _adminId),
          _buildWalletTab(),
        ],
      ),
    );
  }

  Widget _buildPendingPostsTab() {
    return StreamBuilder<List<PostModel>>(
      stream: _postService.getPendingPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.check_circle_outline,
                    size: 60, color: Colors.green.shade300),
                const SizedBox(height: 16),
                const Text('No pending posts!',
                    style: TextStyle(
                        fontSize: AppSizes.fontLarge,
                        fontWeight: FontWeight.bold)),
              ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildPendingPostCard(posts[index]),
        );
      },
    );
  }

  Widget _buildPendingPostCard(PostModel post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppSizes.radiusMedium),
              topRight: Radius.circular(AppSizes.radiusMedium),
            ),
          ),
          child: Row(children: [
            const Icon(Icons.pending, color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            Expanded(
                child: Text(post.userName + ' - ' + post.userType,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontSmall))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('PENDING',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.content,
                style: const TextStyle(fontSize: AppSizes.fontSmall)),
            if (post.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                child: Image.network(post.imageUrl,
                    height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _postService.approvePost(post.id);
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Post approved!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmReject(post.id),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _confirmReject(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Post'),
        content:
            const Text('Are you sure you want to reject and delete this post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _postService.deletePost(postId);
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Post rejected.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Post Announcement',
            style: TextStyle(
                fontSize: AppSizes.fontLarge, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _announcementController,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Type your announcement here...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isPostingAnnouncement ? null : _postAnnouncement,
            icon: _isPostingAnnouncement
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.campaign),
            label: const Text('Post Announcement'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMedium))),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text('Past Announcements',
            style: TextStyle(
                fontSize: AppSizes.fontMedium, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<List<PostModel>>(
          stream: _postService.getAnnouncements(),
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];
            if (list.isEmpty)
              return Text('No announcements yet.',
                  style: TextStyle(color: Colors.grey.shade500));
            return Column(
                children: list
                    .map((a) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusMedium),
                              border: Border.all(color: Colors.grey.shade200)),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.campaign,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(a.content,
                                        style: const TextStyle(
                                            fontSize: AppSizes.fontSmall))),
                                IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.error, size: 18),
                                    onPressed: () =>
                                        _postService.deletePost(a.id),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints()),
                              ]),
                        ))
                    .toList());
          },
        ),
      ]),
    );
  }

  void _postAnnouncement() async {
    if (_announcementController.text.trim().isEmpty) return;
    setState(() => _isPostingAnnouncement = true);
    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': 'admin',
        'userName': 'Admin',
        'userType': 'admin',
        'content': _announcementController.text.trim(),
        'imageUrl': '',
        'status': 'approved',
        'isAnnouncement': true,
        'likeCount': 0,
        'likedBy': [],
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'sport': 'General',
      });
      setState(() => _isPostingAnnouncement = false);
      _announcementController.clear();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Announcement posted!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
    } catch (e) {
      setState(() => _isPostingAnnouncement = false);
    }
  }

  Widget _buildSuggestionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('suggestions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
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
                const Text('No suggestions yet',
                    style: TextStyle(
                        fontSize: AppSizes.fontLarge,
                        fontWeight: FontWeight.bold)),
              ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildSuggestionCard(docs[index].id, data);
          },
        );
      },
    );
  }

  Widget _buildSuggestionCard(String docId, Map<String, dynamic> data) {
    final replyController =
        TextEditingController(text: data['adminReply'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(data['userName'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (data['adminReply'] != null &&
              data['adminReply'].toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Replied',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 8),
        Text(data['content'] ?? '',
            style: const TextStyle(fontSize: AppSizes.fontSmall)),
        const SizedBox(height: 12),
        TextField(
          controller: replyController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Type your reply...',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('suggestions')
                  .doc(docId)
                  .update({'adminReply': replyController.text.trim()});
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Reply sent!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ));
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Reply'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall))),
          ),
        ),
      ]),
    );
  }

  Widget _buildWalletTab() {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: Colors.white,
          child: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Deposits'), Tab(text: 'Withdrawals')],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            StreamBuilder<List<WalletTransaction>>(
              stream: WalletService().getPendingDeposits(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                final deposits = snapshot.data ?? [];
                if (deposits.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.check_circle_outline,
                            size: 60, color: Colors.green.shade300),
                        const SizedBox(height: 16),
                        const Text('No pending deposits',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.fontLarge)),
                      ]));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: deposits.length,
                  itemBuilder: (context, index) =>
                      _DepositCard(tx: deposits[index]),
                );
              },
            ),
            StreamBuilder<List<WalletTransaction>>(
              stream: WalletService().getPendingWithdrawals(),
              builder: (context, snapshot) {
                final withdrawals = snapshot.data ?? [];
                if (withdrawals.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.check_circle_outline,
                            size: 60, color: Colors.green.shade300),
                        const SizedBox(height: 16),
                        const Text('No pending withdrawals',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.fontLarge)),
                      ]));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: withdrawals.length,
                  itemBuilder: (context, index) =>
                      _WithdrawalCard(tx: withdrawals[index]),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── DEPOSIT CARD ──────────────────────────────────────────────────────────

class _DepositCard extends StatefulWidget {
  final WalletTransaction tx;
  const _DepositCard({required this.tx});
  @override
  State<_DepositCard> createState() => _DepositCardState();
}

class _DepositCardState extends State<_DepositCard> {
  late TextEditingController _amountController;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.tx.amount.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => m[1]! + ',');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(widget.tx.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(_fmt(widget.tx.amount) + ' UGX',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: AppSizes.fontMedium)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.phone, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text('From: ' + widget.tx.userMomoNumber,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: AppSizes.fontSmall)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.tag, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text('Ref: ' + widget.tx.reference,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.fontSmall,
                  color: AppColors.dark,
                  letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Actual amount received (UGX)',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isConfirming
                  ? null
                  : () async {
                      final actual = int.tryParse(_amountController.text) ?? 0;
                      if (actual <= 0) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Enter the actual amount received'),
                          backgroundColor: AppColors.error,
                        ));
                        return;
                      }
                      setState(() => _isConfirming = true);
                      final result = await WalletService().confirmDeposit(
                          widget.tx,
                          actualAmountReceived: actual);
                      setState(() => _isConfirming = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(result['message']),
                          backgroundColor: result['success']
                              ? Colors.green
                              : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
              icon: _isConfirming
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Confirm Payment'),
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
              await WalletService().rejectDeposit(widget.tx.id);
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Deposit rejected'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
            },
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall))),
          ),
        ]),
      ]),
    );
  }
}

// ── WITHDRAWAL CARD ───────────────────────────────────────────────────────

class _WithdrawalCard extends StatelessWidget {
  final WalletTransaction tx;
  const _WithdrawalCard({required this.tx});

  String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => m[1]! + ',');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(tx.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt(tx.netAmount) + ' UGX',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: AppSizes.fontMedium)),
            Text('(after 12% fee)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.send_to_mobile, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SEND THIS AMOUNT TO:',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold)),
              Text(tx.userMomoNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontMedium,
                      color: AppColors.dark)),
              Text(_fmt(tx.netAmount) + ' UGX',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontLarge,
                      color: Colors.green)),
            ]),
          ]),
        ),
        const SizedBox(height: 4),
        Text(
            'Requested: ' +
                _fmt(tx.amount) +
                ' UGX | Fee: ' +
                _fmt(tx.fee) +
                ' UGX',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await WalletService().confirmWithdrawal(tx);
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Withdrawal confirmed for ' + tx.userName),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ));
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark as Sent'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSmall))),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () async {
              await WalletService().rejectWithdrawal(tx);
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Withdrawal rejected. Amount refunded.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
            },
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall))),
          ),
        ]),
      ]),
    );
  }
}

// ── MATCHES TAB ───────────────────────────────────────────────────────────

class _MatchesTabWidget extends StatefulWidget {
  final String adminId;
  const _MatchesTabWidget({required this.adminId});
  @override
  State<_MatchesTabWidget> createState() => _MatchesTabWidgetState();
}

class _MatchesTabWidgetState extends State<_MatchesTabWidget> {
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
    'Basketball',
    'Volleyball',
    'Athletics',
    'Other'
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

  String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => m[1]! + ',');

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Schedule a Match',
            style: TextStyle(
                fontSize: AppSizes.fontLarge, fontWeight: FontWeight.bold)),
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

        // ODDS FIELDS
        const Text('Set Odds',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: AppSizes.fontSmall)),
        const SizedBox(height: 4),
        Text('Example: Team A = 1.5x means a 1000 UGX bet wins 1500 UGX',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _oddsAController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Team A Odds (e.g. 1.5)',
                prefixIcon:
                    const Icon(Icons.trending_up, color: AppColors.primary),
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
        ]),
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
              if (time != null)
                setState(() {
                  _selectedDate = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute);
                });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: Colors.grey.shade300)),
            child: Row(children: [
              const Icon(Icons.calendar_today,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year} at '
                '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: AppSizes.fontSmall),
              ),
            ]),
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
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text('Manage Matches & Accountability',
            style: TextStyle(
                fontSize: AppSizes.fontMedium, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<List<MatchModel>>(
          stream: MatchService().getAllMatches(),
          builder: (context, snapshot) {
            final matches = snapshot.data ?? [];
            if (matches.isEmpty)
              return Text('No matches yet.',
                  style: TextStyle(color: Colors.grey.shade500));
            return Column(
                children: matches
                    .map((m) =>
                        _MatchAdminCard(match: m, adminId: widget.adminId))
                    .toList());
          },
        ),
      ]),
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

// ── MATCH ADMIN CARD with accountability ─────────────────────────────────

class _MatchAdminCard extends StatefulWidget {
  final MatchModel match;
  final String adminId;
  const _MatchAdminCard({required this.match, required this.adminId});
  @override
  State<_MatchAdminCard> createState() => _MatchAdminCardState();
}

class _MatchAdminCardState extends State<_MatchAdminCard> {
  late TextEditingController _scoreAController;
  late TextEditingController _scoreBController;
  late TextEditingController _oddsAController;
  late TextEditingController _oddsBController;
  late String _currentStatus;
  bool _showBets = false;

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

  String _fmt(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => m[1]! + ',');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // MATCH HEADER
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
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
                    Text(widget.match.teamA + ' vs ' + widget.match.teamB,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.fontMedium)),
                    Text(widget.match.venue + ' | ' + widget.match.sport,
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ODDS UPDATE
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
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Odds updated!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('Set',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),

            const SizedBox(height: 12),

            // STATUS + SCORE
            Row(children: [
              const Text('Status: ',
                  style: TextStyle(fontSize: AppSizes.fontSmall)),
              DropdownButton<String>(
                value: _currentStatus,
                isDense: true,
                items: [
                  MatchStatus.upcoming,
                  MatchStatus.live,
                  MatchStatus.completed
                ]
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.toUpperCase(),
                            style:
                                const TextStyle(fontSize: AppSizes.fontSmall))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _currentStatus = val);
                },
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _scoreAController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: widget.match.teamA,
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))))),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20))),
              Expanded(
                  child: TextField(
                      controller: _scoreBController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: widget.match.teamB,
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await MatchService().updateScore(
                    matchId: widget.match.id,
                    scoreA: int.tryParse(_scoreAController.text) ?? 0,
                    scoreB: int.tryParse(_scoreBController.text) ?? 0,
                    status: _currentStatus,
                  );
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Score updated!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child:
                    const Text('Update', style: TextStyle(color: Colors.white)),
              ),
            ]),

            const SizedBox(height: 12),

            // ACCOUNTABILITY - show bets
            GestureDetector(
              onTap: () => setState(() => _showBets = !_showBets),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.people, color: Colors.blue, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.match.bets.length} bets | Pool: ${_fmt(widget.match.totalPool)} UGX',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontSmall,
                        color: Colors.blue),
                  ),
                  const Spacer(),
                  Icon(_showBets ? Icons.expand_less : Icons.expand_more,
                      color: Colors.blue, size: 18),
                ]),
              ),
            ),

            // BETS LIST - accountability dashboard
            if (_showBets) ...[
              const SizedBox(height: 8),
              if (widget.match.bets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('No bets placed yet.',
                      style: TextStyle(color: Colors.grey.shade500)),
                )
              else ...[
                // Summary
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SUMMARY',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(widget.match.teamA + ' bettors',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '${widget.match.votesA} bets | ${_fmt(widget.match.bets.values.where((b) => b['team'] == 'A').fold(0, (s, b) => s + (b['amount'] as int? ?? 0)))} UGX',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11)),
                              ])),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(widget.match.teamB + ' bettors',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '${widget.match.votesB} bets | ${_fmt(widget.match.bets.values.where((b) => b['team'] == 'B').fold(0, (s, b) => s + (b['amount'] as int? ?? 0)))} UGX',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11)),
                              ])),
                        ]),
                        const SizedBox(height: 6),
                        // Liability
                        Builder(builder: (context) {
                          int liabilityA = widget.match.bets.values
                              .where((b) => b['team'] == 'A')
                              .fold(
                                  0,
                                  (s, b) =>
                                      s +
                                      (b['potentialWinnings'] as int? ?? 0));
                          int liabilityB = widget.match.bets.values
                              .where((b) => b['team'] == 'B')
                              .fold(
                                  0,
                                  (s, b) =>
                                      s +
                                      (b['potentialWinnings'] as int? ?? 0));
                          int profitA = widget.match.totalPool - liabilityA;
                          int profitB = widget.match.totalPool - liabilityB;
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(height: 12),
                                Text(
                                    'If ${widget.match.teamA} wins: Pay ${_fmt(liabilityA)} UGX | Your profit: ${profitA >= 0 ? '+' : ''}${_fmt(profitA)} UGX',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: profitA >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                    'If ${widget.match.teamB} wins: Pay ${_fmt(liabilityB)} UGX | Your profit: ${profitB >= 0 ? '+' : ''}${_fmt(profitB)} UGX',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: profitB >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold)),
                              ]);
                        }),
                      ]),
                ),

                const SizedBox(height: 8),

                // Individual bets list
                ...widget.match.bets.entries.map((entry) {
                  final bet = entry.value as Map<String, dynamic>;
                  final isTeamA = bet['team'] == 'A';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isTeamA
                          ? AppColors.primary.withOpacity(0.05)
                          : Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isTeamA
                              ? AppColors.primary.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isTeamA ? AppColors.primary : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(bet['userName'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(bet['userMomoNumber'] ?? '',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 11)),
                            Text('Bet on: ' + (bet['teamName'] ?? bet['team']),
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 11)),
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_fmt(bet['amount'] as int? ?? 0) + ' UGX',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(
                                'Odds: ' +
                                    (bet['oddsAtPlacement'] ?? 1.5)
                                        .toStringAsFixed(2) +
                                    'x',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 11)),
                            Text(
                                'Wins: ' +
                                    _fmt(
                                        bet['potentialWinnings'] as int? ?? 0) +
                                    ' UGX',
                                style: TextStyle(
                                    color: isTeamA
                                        ? AppColors.primary
                                        : Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ]),
                    ]),
                  );
                }).toList(),
              ],
            ],

            // DISTRIBUTE WINNINGS
            if (widget.match.status == MatchStatus.completed &&
                !widget.match.winnersDistributed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDistributeDialog(context),
                  icon: const Icon(Icons.emoji_events, size: 16),
                  label: const Text('Distribute Winnings'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],

            if (widget.match.winnersDistributed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text('Winnings distributed',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  void _showDistributeDialog(BuildContext context) {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Distribute Winnings'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Match ID: ${widget.match.id}',
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Type the match ID above to confirm:',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: confirmController,
            decoration: const InputDecoration(
                hintText: 'Paste match ID here',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 16),
          const Text('Which team won?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await WalletService().distributeWinnings(
                  matchId: widget.match.id,
                  winnerTeam: 'A',
                  adminId: widget.adminId,
                  confirmationText: confirmController.text.trim(),
                );
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message']),
                    backgroundColor:
                        result['success'] ? Colors.green : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 6),
                  ));
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(widget.match.teamA,
                  style: const TextStyle(color: Colors.white)),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await WalletService().distributeWinnings(
                  matchId: widget.match.id,
                  winnerTeam: 'B',
                  adminId: widget.adminId,
                  confirmationText: confirmController.text.trim(),
                );
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message']),
                    backgroundColor:
                        result['success'] ? Colors.green : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 6),
                  ));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(widget.match.teamB,
                  style: const TextStyle(color: Colors.white)),
            )),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await WalletService().distributeWinnings(
                  matchId: widget.match.id,
                  winnerTeam: 'CANCELLED',
                  adminId: widget.adminId,
                  confirmationText: confirmController.text.trim(),
                );
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message']),
                    backgroundColor:
                        result['success'] ? Colors.green : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
              },
              child: const Text('Match Cancelled - Refund All'),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))
        ],
      ),
    );
  }
}
