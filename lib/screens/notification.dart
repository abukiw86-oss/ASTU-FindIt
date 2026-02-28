// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lost_found_app/services/auth_service.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {

  const NotificationsScreen({
    super.key,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationService _service;
  String? _currentUserId;
  bool _isLoadingUser = true;

  List<Map<String, dynamic>> notifications = [];
  int unreadCount = 0;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndNotifications();
    _service = NotificationService();
    _loadNotifications();
    AuthService.getUserStringId();
  }
  Future<void> _loadUserIdAndNotifications() async {
      final userId = await AuthService.getUserStringId();
      
      if (userId == null || userId.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoadingUser = false);
       return;
      }

      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _isLoadingUser = false;
      });
      await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _service.getNotifications(_currentUserId);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (result['success'] == true) {
        notifications = List<Map<String, dynamic>>.from(result['notifications'] ?? []);
        unreadCount = result['unread_count'] ?? 0;
      } else {
        errorMessage = result['message'] ?? 'Failed to load notifications';
      }
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      return DateFormat('d MMM yyyy • HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

String _getFirstImageUrl(String? imagesStr) {
  if (imagesStr == null || imagesStr.trim().isEmpty) return '';
  final first = imagesStr.split('|').first.trim();
  String path = first.replaceAll(RegExp(r"^'+|'+\$"), '');

  path = path.replaceAll(r'\', '');
  path = path.replaceAll('//', '/');
  if (path.isEmpty) return '';
  return 'https://astufindit.x10.mx/index/$path';
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Badge(
                  label: Text('$unreadCount'),
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.notifications),
                ),
              ),
            ),
          if (notifications.isNotEmpty && unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed:(){},
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? _buildErrorView()
                : notifications.isEmpty
                    ? _buildEmptyView()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final n = notifications[index];
                          final isRead = n['is_read'] == true;
                          final type = n['type'] ?? 'unknown';
                          final title = n['title'] ?? 'Notification';
                          final message = n['message'] ?? '';
                          final time = _formatDate(n['created_at']);
                          final item = n['item_details'] as Map<String, dynamic>?;
                          final hasImage = item != null &&
                              item['image'] != null &&
                              (item['image'] as String).isNotEmpty;
                          return Dismissible(
                            key: Key(n['id'].toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.green.shade700,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.done, color: Colors.white),
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: isRead ? 1 : 3,
                              color: isRead ? null : Colors.blue.withOpacity(0.04),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {},
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: _getTypeColor(type).withOpacity(0.15),
                                        child: Icon(
                                          _getTypeIcon(type),
                                          color: _getTypeColor(type),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                if (!isRead)
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.blue,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              message,
                                              style: TextStyle(
                                                color: Colors.grey.shade800,
                                                height: 1.3,
                                              ),
                                            ),
                                            if (item != null) ...[
                                              const SizedBox(height: 12),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (hasImage)
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: SizedBox(
                                                        width: 70,
                                                        height: 70,
                                                        child: Image.network (
                                                           _getFirstImageUrl(item['image']),
                                                          fit: BoxFit.cover,
                                                          ),
                                                      ),
                                                    ),
                                                  if (hasImage) const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          item['title'] ?? 'Item',
                                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          '${(item['type'] ?? '').toUpperCase()} • ${(item['status'] ?? '').toUpperCase()}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Text(
                                              time,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'You’ll be notified when something new happens',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'item_review':       return Icons.check_circle_outline;
      case 'match_found':       return Icons.link;
      case 'claim_approved':    return Icons.thumb_up;
      case 'claim_rejected':    return Icons.thumb_down;
      case 'item_claimed':      return Icons.inventory_2;
      case 'admin_message':     return Icons.person;
      default:                  return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'claim_approved':
      case 'item_review':       return Colors.green.shade700;
      case 'claim_rejected':    return Colors.red.shade700;
      case 'match_found':       return Colors.blue.shade700;
      default:                  return Colors.grey.shade700;
    }
  }
}