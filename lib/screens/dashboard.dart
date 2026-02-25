import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'add_lost_found.dart';
import '../services/auth_service.dart';
import 'report_individual.dart';
import 'notification.dart';
import 'profile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  int _notificationCount = 0;
  Timer? _notificationTimer;

  List<dynamic> lostItems = [];
  List<dynamic> foundItems = [];
  
  bool isLoading = true;
  String? errorMessage;
  int? currentUserId;
  String? currentUserName;
  String? currentUserPhone;
  
  Set<int> requestedItems = {};
  Set<int> approvedItems = {};
  Map<int, String> requestStatus = {};
  String? currentUserStringId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

Future<void> _loadUserData() async {
  final user = await AuthService.getUser();
  if (user != null && mounted) {
    setState(() {
      currentUserId = user['id'];
      currentUserStringId = user['user_string_id']; 
      currentUserName = user['full_name'];
      currentUserPhone = user['phone'];
    });
    
    await Future.wait([
      _loadRequestedItems(),
      _loadNotificationCount(),
    ]);
    await _loadItems();
    
    _startNotificationTimer();
  } else {
    if (mounted) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please login to continue';
      });
    }
  }
}

bool _isItemFounder(dynamic item) {
  if (currentUserStringId == null || currentUserStringId!.isEmpty) {
    return false;
  }
  if (item['user_string_id'] != null) {
    String itemUserStringId = item['user_string_id'].toString();
    if (itemUserStringId == currentUserStringId) {
      return true;
    }
  }
  
  String itemReporterName = (item['reporter_name'] ?? '').toString().trim().toLowerCase();
  String currentName = (currentUserName ?? '').trim().toLowerCase();
  
  if (itemReporterName.isNotEmpty && 
      itemReporterName != 'hidden' && 
      itemReporterName == currentName) {
    return true;
  }
  return false;
}
  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (currentUserId != null && mounted) {
        _loadNotificationCount();
      }
    });
  }

Future<void> _loadNotificationCount() async {
  if (currentUserStringId == null || !mounted) return;
  
  try {
    final result = await NotificationService.getNotifications(
      userId: currentUserStringId!,
    );
    
    if (result['success'] == true && mounted) {
      setState(() {
        _notificationCount = result['unread_count'] ?? 0;
      });
    }
  } catch (e) {
    // 
  }
}
Future<void> _loadRequestedItems() async {
  if (currentUserStringId == null || !mounted) return;
  
  try {
    final result = await ApiService.getUserRequests(userStringId: currentUserStringId!); 
    
    if (result['success'] == true && result['requests'] != null && mounted) {
      setState(() {
        requestedItems.clear();
        approvedItems.clear();
        requestStatus.clear();
        
        for (var req in result['requests']) {
          int itemId = req['item_id'] is String 
              ? int.parse(req['item_id']) 
              : req['item_id'];
          String status = req['status'] ?? 'pending';
          
          requestStatus[itemId] = status;
          
          if (status == 'approved') {
            approvedItems.add(itemId);
          } else if (status == 'pending') {
            requestedItems.add(itemId);
          }
        }
      });
    }
  } catch (e) {
    // 
  }
}
Future<void> _loadItems() async {
  if (!mounted) return;
  
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final lostResult = await ApiService.getLostItems();
    final foundResult = await ApiService.getFoundItems(userStringId: currentUserStringId);
    if (mounted) {
      setState(() {
        isLoading = false;

        if (lostResult['success'] == true) {
          lostItems = lostResult['items'] ?? [];
        }

        if (foundResult['success'] == true) {
          foundItems = foundResult['items'] ?? [];
          approvedItems.clear();
          requestedItems.clear();
          requestStatus.clear();
          
          for (var item in foundItems) {
            int itemId = item['id'] is String ? int.parse(item['id']) : item['id'];
            
            bool isFounder = _isItemFounder(item);
            
            if (isFounder) {
              approvedItems.add(itemId);
              requestStatus[itemId] = 'approved';
            } else {
              String accessLevel = item['access_level'] ?? 'restricted';
              
              if (accessLevel == 'accessible') {
                approvedItems.add(itemId);
                requestStatus[itemId] = 'approved';
              } else if (accessLevel == 'pending') {
                requestedItems.add(itemId);
                requestStatus[itemId] = 'pending';
              }
            }
          }
        }
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load items: $e';
      });
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: AuthService.getUserName(),
          builder: (context, snapshot) {
            if (!mounted) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lost & Found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
                Text(
                  'Welcome, ${snapshot.data ?? 'User'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                ),
              ],
            );
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ).then((_) => _loadNotificationCount());
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _notificationCount > 9 ? '9+' : '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lost Items', icon: Icon(Icons.search_off)),
            Tab(text: 'Found Items', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLostItemsList(),
                    _buildFoundItemsList(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportItemScreen()),
          ).then((_) => _loadItems());
        },
        icon: const Icon(Icons.add),
        label: const Text('Report Item'),
      ),
    );
  }
  
  Widget _buildLostItemsList() {
    if (lostItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No lost items reported', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: lostItems.length,
        itemBuilder: (context, index) {
          final item = lostItems[index];
          return _buildLostItemCard(item);
        },
      ),
    );
  }

Widget _buildLostItemCard(dynamic item) {
  final bool isFounder = _isItemFounder(item);
  
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: () => _showLostItemDetails(item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: item['image_path'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _getImageUrl(item['image_path']),
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                        errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, color: Colors.red),
                      ),
                    )
                  : Icon(Icons.search_off, color: Colors.red, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title'] ?? 'No title',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      // Founder badge
                      if (isFounder)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 10, color: Colors.blue[700]),
                              const SizedBox(width: 2),
                              Text(
                                'YOU',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('LOST', style: TextStyle(color: Colors.red, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['description'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['location'] ?? 'Unknown',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ),
                      if (isFounder)
                        Text(
                          ' • You reported this',
                          style: TextStyle(color: Colors.blue[400], fontSize: 10, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showLostItemDetails(dynamic item) {
  // Don't create TextEditingController here anymore
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              if (item['image_path'] != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _getImageUrl(item['image_path']),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('LOST ITEM', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Text(
                item['title'] ?? 'No title',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 16),
              
              if (_isItemFounder(item))
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text(
                        'You reported this item',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailSection('Description', item['description'] ?? 'No description'),
                    _buildDetailSection('Location', item['location'] ?? 'Unknown'),
                    _buildDetailSection('Category', item['category'] ?? 'Other'),
                    _buildDetailSection('Lost By', '${item['reporter_name']} • ${item['reporter_phone']}'),
                    _buildDetailSection('Date Lost', _formatDate(item['created_at'])),
                    
                    const SizedBox(height: 20),
                    
                    if (!_isItemFounder(item))
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'Did you find this item?',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click below to report that you found this item. '
                                'You can provide photos and details to help verify ownership.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context); // Close bottom sheet
                                    
                                    // Navigate to the new report screen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReportFoundMatchScreen(
                                          lostItemId: item['item_string_id'] ?? item['id'].toString(),
                                          lostItemTitle: item['title'] ?? 'Unknown Item',
                                          lostItemImage: item['image_path'] != null 
                                              ? _getImageUrl(item['image_path']) 
                                              : null,
                                          userStringId: currentUserStringId!,
                                          userName: currentUserName!,
                                          userPhone: currentUserPhone ?? '',
                                        ),
                                      ),
                                    ).then((reported) {
                                      if (reported == true) {
                                        _loadItems(); // Refresh items if report was successful
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.navigate_next),
                                  label: const Text('Continue to Report Form'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
  Widget _buildFoundItemsList() {
    if (foundItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No found items reported', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: foundItems.length,
        itemBuilder: (context, index) {
          final item = foundItems[index];
          return _buildFoundItemCard(item);
        },
      ),
    );
  }

Widget _buildFoundItemCard(dynamic item) {
  int itemId = item['id'] is String ? int.parse(item['id']) : item['id'];
  
  final bool isFounder = _isItemFounder(item);
  final String accessLevel = isFounder ? 'accessible' : (item['access_level'] ?? 'restricted');
  final bool isClaimed = item['status'] == 'claimed';
  
  final bool hasApproved = isFounder || 
                          accessLevel == 'accessible' || 
                          approvedItems.contains(itemId);
  
  final bool hasPending = !isFounder && (
                         accessLevel == 'pending' || 
                         requestedItems.contains(itemId) ||
                         requestStatus[itemId] == 'pending');
  
  final bool isRejected = !isFounder && requestStatus[itemId] == 'rejected';

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: () {
        if (hasApproved) {
          _showFoundItemDetails(item);
        } else if (hasPending) {
          _showPendingDialog();
        } else if (isRejected) {
          _showRejectedDialog();
        } else if (!isClaimed) {
          _showRequestAccessDialog(item);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item['image_path'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _getImageUrl(item['image_path']),
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.green),
                          ),
                        )
                      : Icon(Icons.check_circle, color: Colors.green, size: 40),
                ),
                if (!hasApproved && !isFounder)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                
                if (!hasApproved && !isFounder)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Center(
                        child: Icon(
                          isRejected ? Icons.block : Icons.lock,
                          color: isRejected ? Colors.red : Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                
                if (hasApproved)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                  ),

                if (isFounder)
                  const Positioned(
                    top: 4,
                    left: 4,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title'] ?? 'No title',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: hasApproved ? Colors.black : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (isFounder)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'FOUNDER',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isClaimed 
                              ? Colors.orange.withOpacity(0.1)
                              : hasApproved
                                  ? Colors.green.withOpacity(0.1)
                                  : hasPending
                                      ? Colors.blue.withOpacity(0.1)
                                      : isRejected
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isClaimed 
                              ? 'CLAIMED'
                              : hasApproved
                                  ? 'ACCESSIBLE'
                                  : hasPending
                                      ? 'PENDING'
                                      : isRejected
                                          ? 'REJECTED'
                                          : 'FOUND',
                          style: TextStyle(
                            color: isClaimed 
                                ? Colors.orange
                                : hasApproved
                                    ? Colors.green
                                    : hasPending
                                        ? Colors.blue
                                        : isRejected
                                            ? Colors.red
                                            : Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['location'] ?? 'Unknown',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  
                  if (hasApproved) ...[
                    const SizedBox(height: 8),
                    Text(
                      item['description'] ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reported by: ${item['reporter_name'] ?? 'Anonymous'}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  
                  if (isFounder)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 12, color: Colors.blue[400]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'You found this item',
                              style: TextStyle(
                                color: Colors.blue[400],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (!isClaimed && !hasApproved && !isFounder)
                    Align(
                      alignment: Alignment.centerRight,
                      child: hasPending
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Awaiting Review',
                                style: TextStyle(color: Colors.blue, fontSize: 11),
                              ),
                            )
                          : isRejected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Request Rejected',
                                    style: TextStyle(color: Colors.red, fontSize: 11),
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: () => _showRequestAccessDialog(item),
                                  icon: const Icon(Icons.lock_open, size: 16),
                                  label: const Text('This is my item!'),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.green[50],
                                    foregroundColor: Colors.green[800],
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
 
void _showRequestAccessDialog(dynamic item) {
    final TextEditingController messageController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Claim This Item'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide details to prove this item belongs to you:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item: ${item['title']}', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Found at: ${item['location']}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Describe unique features, when you lost it, or any proof:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'e.g., serial number, color, scratches, when/where you lost it...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide some details';
                  }
                  if (value.length < 10) {
                    return 'Please provide more details (min 10 characters)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context);
                int itemId = item['id'] is String ? int.parse(item['id']) : item['id'];
                await _submitAccessRequest(itemId, messageController.text);
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Submit Claim'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

Future<void> _submitAccessRequest(int itemId, String message) async {
  if (message.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please provide details about your item'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  if (currentUserStringId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must be logged in'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() => isLoading = true);

  try {
    final result = await ApiService.requestItemAccess(
      userStringId: currentUserStringId!, 
      itemId: itemId,
      message: message,
    );

    if (result['success'] == true) {
      setState(() {
        requestedItems.add(itemId);
        requestStatus[itemId] = 'pending';
      });
      
      _showSuccessDialog(
        'Claim submitted successfully!', 
        'Admin will review your request. You will be notified once approved.'
      );
      
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to submit claim'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => isLoading = false);
  }
}

void _showFoundItemDetails(dynamic item) {
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                if (item['image_path'] != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _getImageUrl(item['image_path']),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'FOUND ITEM',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACCESS GRANTED',
                        style: TextStyle(color: Colors.blue, fontSize: 11),
                      ),
                    ),
                  ],
                ),

if (_isItemFounder(item))
  Container(
    margin: const EdgeInsets.only(top: 8, bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.blue.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person, color: Colors.blue[700], size: 18),
        const SizedBox(width: 8),
        Text(
          'You found this item',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    ),
  ),
                const SizedBox(height: 8),
                
                Text(
                  item['title'] ?? 'No title',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                                if (_isItemFounder(item))
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          'You found this item',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetailSection('Description', item['description'] ?? 'No description'),
                      _buildDetailSection('Location', item['location'] ?? 'Unknown'),
                      _buildDetailSection('Category', item['category'] ?? 'Other'),
                      _buildDetailSection('Reported By', '${item['reporter_name'] ?? 'Anonymous'} • ${item['reporter_phone'] ?? 'No phone'}'),
                      _buildDetailSection('Date Found', _formatDate(item['created_at'])),
                      
                      const SizedBox(height: 20),
                      
                      Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'You have access to this item',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Contact the finder to arrange return',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        // TODO: Implement call
                                      },
                                      icon: const Icon(Icons.phone),
                                      label: const Text('Call'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        // TODO: Implement message
                                      },
                                      icon: const Icon(Icons.message),
                                      label: const Text('Message'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
 
 
  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Request Pending'),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 40, color: Colors.orange),
              SizedBox(height: 12),
              Text(
                'Your request is pending admin approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'You will be notified once admin reviews your claim.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Request Rejected'),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 40, color: Colors.red),
              SizedBox(height: 12),
              Text(
                'Your request was rejected by the admin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'The details provided did not match the item.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(8),
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


Future<void> _reportFoundMatch(String lostItemStringId, String message , currentUserStringId) async {
  if (message.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please describe where and when you found it'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  if (currentUserName == null || currentUserName!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your name is missing. Please login again.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() => isLoading = true);

  try {
    print('📤 Reporting found match for lost item: $lostItemStringId');
    
    final result = await ApiService.reportFoundMatch(
      lostItemStringId: lostItemStringId, 
      finderName: currentUserName!,
      finderPhone: currentUserPhone ?? '',
      finderMessage: message,
      userStringId: currentUserStringId.toString(),
    );

    print('📥 Result: $result');

    if (result['success'] == true) {
      Navigator.pop(context); 
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Report submitted successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
      _loadItems();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to submit report'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('❌ Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => isLoading = false);
  }
}
  
  
Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(content),
          ),
        ],
      ),
    );
  }


String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute}';
    } catch (e) {
      return dateString;
    }
  }
  
Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadItems, 
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://astufindit.x10.mx/index/$path';
  }
}