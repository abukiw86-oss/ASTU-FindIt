import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _currentUserId;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        _currentUserId = user['user_string_id'];
      });
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);

    final result = await NotificationService.getNotifications(
      userId: _currentUserId!,
    );

    if (result['success'] == true) {
      setState(() {
        _notifications = result['notifications'] ?? [];
        _unreadCount = result['unread_count'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    if (_currentUserId == null) return;

    await NotificationService.markAsRead(
      notificationId: notificationId,
      userId: _currentUserId!,
    );

    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      }
    });
  }

  Future<void> _markAllAsRead() async {
    if (_currentUserId == null) return;

    await NotificationService.markAllAsRead(userId: _currentUserId!);

    setState(() {
      for (var n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
    });
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'claim_approved':
        return Icons.check_circle;
      case 'claim_rejected':
        return Icons.cancel;
      case 'match_found':
        return Icons.link;
      case 'item_claimed':
        return Icons.verified;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'claim_approved':
        return Colors.green;
      case 'claim_rejected':
        return Colors.red;
      case 'match_found':
        return Colors.blue;
      case 'item_claimed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ll be notified when your claims are reviewed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final bool isRead = notification['is_read'] == true;
                    final icon = _getNotificationIcon(notification['type']);
                    final color = _getNotificationColor(notification['type']);

                    return Dismissible(
                      key: Key(notification['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.green,
                        child: const Icon(
                          Icons.done,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) {
                        _markAsRead(notification['id']);
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        color: isRead ? null : Colors.blue[50],
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(
                              icon,
                              color: color,
                            ),
                          ),
                          title: Text(
                            notification['title'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(notification['message'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                _timeAgo(notification['created_at']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          trailing: isRead
                              ? null
                              : Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          onTap: () {
                            if (!isRead) {
                              _markAsRead(notification['id']);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}