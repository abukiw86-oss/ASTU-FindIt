import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'add_lost_found.dart';
import '../services/auth_service.dart';
import 'search.dart';
import '../widget/appbar.dart';
import 'notification.dart';
import 'profile.dart';
import '../widget/full_screen_image_viewer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;


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
    _tabController.dispose();
    super.dispose();
  }

Future<void> _loadUserData() async {
  final user = await AuthService.getUser();
  if (user != null && mounted) {
    setState(() {
      currentUserStringId = user['user_string_id']; 
      currentUserName = user['full_name'];
      currentUserPhone = user['phone'];
    });
    
    await Future.wait([
      _loadRequestedItems(),
    
    ]);
    await _loadItems();
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
  return false;
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
      appBar: LostFoundAppBar(
        tabController: _tabController,
        onRefresh: _loadItems,
        showTabs: true,
        
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
                bottomNavigationBar: Container(
  height: 96,
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 16,
        offset: const Offset(0, -4),
      )
    ],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
            IconButton(
        iconSize: 28,
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const  NotificationsScreen()),
            );
         },
      ),
      IconButton(onPressed: (){
        Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const  SearchFilterPage()),
            );
            },
             icon:const Icon(Icons.search),
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.search_off_rounded, size: 20),
                label: const Text('Lost', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed:(){ Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportItemOrMatchScreen(initialType: 'lost'),
                  ),
                );
                }
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text('Found', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed:(){ Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportItemOrMatchScreen(initialType: 'found'),
                  ),
                );
                }
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Report Item",
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),


      IconButton(
        iconSize: 28,
        icon: const Icon(Icons.person_outline),
        onPressed: () {              
          Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );},
      ),
    ],
  ),
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

  String? firstImageUrl;

  var rawImagePath = item['image_path']?.toString()?.trim();

  if (rawImagePath != null && rawImagePath != 'NULL' && rawImagePath.isNotEmpty) {
    if (rawImagePath.startsWith("'") && rawImagePath.endsWith("'")) {
      rawImagePath = rawImagePath.substring(1, rawImagePath.length - 1).trim();
    } 
    final paths = rawImagePath.split('|');
    if (paths.isNotEmpty) {
      final firstPath = paths.first.trim();
      if (firstPath.isNotEmpty) {
        firstImageUrl = _getImageUrl(firstPath);
      }
    }
  }
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
              child: firstImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        firstImageUrl,
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            color: Colors.red,
                            size: 40,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.search_off,
                      color: Colors.red,
                      size: 40,
                    ),
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
                      if (isFounder) _owner(),
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) { 
        List<String> imageUrls = [];

        var rawPath = item['image_path']?.toString()?.trim();

        if (rawPath != null && rawPath != 'NULL' && rawPath.isNotEmpty) { 
          if (rawPath.startsWith("'") && rawPath.endsWith("'")) {
            rawPath = rawPath.substring(1, rawPath.length - 1).trim();
          } 
          final paths = rawPath.split('|');
          imageUrls = paths.map<String>((String p) {
            final cleanPath = p.trim();
            return _getImageUrl(cleanPath);
          }).where((url) => url.isNotEmpty).toList();
        } 
        final _pageController = PageController();

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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (imageUrls.isNotEmpty)
                Expanded(
                  flex: 1,
                  child: Stack(
                    
                    children: [
                  PageView.builder(
                    controller: _pageController, 
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageViewer(
                                images: imageUrls,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 260,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 60, color: Colors.red),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                                      
                      if (imageUrls.length > 1)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [ 
                                IconButton(
                                  icon: const Icon(Icons.arrow_left, color: Colors.white),
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_right, color: Colors.white),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                  ),
                ),

              const SizedBox(height: 20),
 
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LOST ITEM',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 8),
              
              Text(
                item['title']  ?? 'No title  ',
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
                    _buildDetailSection('Lost By', '${item['reporter_name'] ?? 'Unknown'} • ${item['reporter_phone'] ?? '—'}'),
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
                                    Navigator.pop(context);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReportItemOrMatchScreen(
                                          lostItemId: item['item_string_id'] ,
                                          lostItemTitle: item['title'] ?? 'Unknown Item',
                                          lostItemImage: imageUrls.isNotEmpty ? imageUrls.first : null,
                                        ),
                                      ),
                                    ).then((reported) {
                                      if (reported == true) {
                                        _loadItems();
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
 
  String? firstImageUrl;
  int imageCount = 0;
  
  var rawImagePath = item['image_path']?.toString()?.trim();

  if (rawImagePath != null && rawImagePath != 'NULL' && rawImagePath != 'null' && rawImagePath.isNotEmpty) {
 
    if (rawImagePath.startsWith("'") && rawImagePath.endsWith("'")) {
      rawImagePath = rawImagePath.substring(1, rawImagePath.length - 1).trim();
    } 
    final paths = rawImagePath.split('|');
    imageCount = paths.length;
     
    if (paths.isNotEmpty) {
      final firstPath = paths.first.trim();
      if (firstPath.isNotEmpty && firstPath != 'NULL' && firstPath != 'null') {
        firstImageUrl = _getImageUrl(firstPath);
      }
    }
  }

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
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: firstImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            firstImageUrl,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.green[300], size: 30),
                                const Text(
                                  'Error',
                                  style: TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[300], size: 30),
                            const Text(
                              'No image',
                              style: TextStyle(fontSize: 8, color: Colors.grey),
                            ),
                          ],
                        ),
                ), 
                if (imageCount > 1 && hasApproved)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library, color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            '$imageCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                 
                if (!hasApproved && !isFounder)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
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
                    left: 4,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                            'YOU',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                       
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                              child:const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time, size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Awaiting Review',
                                    style: TextStyle(color: Colors.blue, fontSize: 11),
                                  ),
                                ],
                              ),
                            )
                          : isRejected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.block, size: 12, color: Colors.red),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Request Rejected',
                                        style: TextStyle(color: Colors.red, fontSize: 11),
                                      ),
                                    ],
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
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController lostLocationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<XFile> _selectedImages = []; 
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking images: $e")),
      );
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }
  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.accessible_sharp, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Text('Claim This Item'),
              ],
            ),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? 'Unknown Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Found at: ${item['location'] ?? '—'}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Where and when did you lose this item?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: lostLocationController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Bole Road, Addis Ababa - around Jan 15, 2026',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please tell us where you lost it';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Describe unique features or proof of ownership',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Serial number, color, scratches, purchase receipt details, when/where you got it, distinctive marks...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide some proof details';
                        }
                        if (value.trim().length < 20) {
                          return 'Please add more information (at least 20 characters)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Add photos (optional but strongly recommended)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Add Photos'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_selectedImages.isNotEmpty)
                          Text(
                            '${_selectedImages.length} selected',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            final file = _selectedImages[index];
                            return Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(file.path),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.red,
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 8),
                    const Text(
                      'Photos of the item from when you owned it help admins verify your claim faster.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext);

                    final claimData = {
                      'item_id': item['id'] is String
                          ? int.tryParse(item['id']) ?? 0
                          : item['id'],
                      'description': descriptionController.text.trim(),
                      'lost_location': lostLocationController.text.trim(),
                      'image_paths': _selectedImages.map((f) => f.path).toList(),
                    };

                    await _submitAccessRequest(claimData);
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Submit Claim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      );
    },
  );
}

Future<void> _submitAccessRequest(Map<String, dynamic> claimData) async {
  try {
    final uri = Uri.parse('${ApiService.baseUrl}?action=submit-item-claim');

    var request = http.MultipartRequest('POST', uri);

    request.fields['item_id']         = claimData['item_id'].toString();
    request.fields['user_string_id']  = await AuthService.getUserStringId() ?? '';
    request.fields['description']     = claimData['description'];
    request.fields['lost_location']   = claimData['lost_location'];

    for (String path in claimData['image_paths']) {
      var file = await http.MultipartFile.fromPath('images[]', path);
      request.files.add(file);
    }

    final response = await request.send();

    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final json = jsonDecode(respStr);

      if (json['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(json['message'] ?? 'Claim submitted!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception(json['message'] ?? 'Server rejected the claim');
      }
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to submit claim: $e'), backgroundColor: Colors.red),
    );
  }
}

void _showFoundItemDetails(dynamic item) {
  List<String> imageUrls = [];

  var rawPath = item['image_path']?.toString()?.trim();

  if (rawPath != null && rawPath != 'NULL' && rawPath != 'null' && rawPath.isNotEmpty) {
    if (rawPath.startsWith("'") && rawPath.endsWith("'")) {
      rawPath = rawPath.substring(1, rawPath.length - 1).trim();
    }
    final paths = rawPath.split('|');
    imageUrls = paths
        .map<String>((String p) {
          final cleanPath = p.trim();
          if (cleanPath.isEmpty || cleanPath == 'NULL' || cleanPath == 'null') return '';
          return _getImageUrl(cleanPath);
        })
        .where((url) => url.isNotEmpty)
        .toList();
  }
  final _pageController = PageController();

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
              if (imageUrls.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageViewer(
                                    images: imageUrls,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                imageUrls[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 220,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 60, color: Colors.red),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_pageController.hasClients ? _pageController.page?.toInt() ?? 1 : 1}/${imageUrls.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),

                      if (imageUrls.length > 1)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_left, color: Colors.white, size: 24),
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_right, color: Colors.white, size: 24),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
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
                  if (_isItemFounder(item))
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item['status'] == 'approved' || item['access_level'] == 'accessible')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            'ACCESS GRANTED',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                item['title'] ?? 'No title',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailSection('Description', item['description'] ?? 'No description'),
                    _buildDetailSection('Location', item['location'] ?? 'Unknown'),
                    _buildDetailSection('Category', item['category'] ?? 'Other'),
                    _buildDetailSection('Reported By', 
                        '${item['reporter_name'] ?? 'Anonymous'} • ${item['reporter_phone'] ?? 'No phone'}'),
                    _buildDetailSection('Date Found', _formatDate(item['created_at'])),
                    
                    if (item['found_item_property'] != null && item['found_item_property'].toString().isNotEmpty)
                      _buildDetailSection('Item Property', item['found_item_property']),
                    
                    if (item['when_lost'] != null && item['when_lost'].toString().isNotEmpty)
                      _buildDetailSection('When Lost', item['when_lost']),
                    
                    const SizedBox(height: 20),
                    if (!_isItemFounder(item) && (item['status'] == 'approved' || item['access_level'] == 'accessible'))
                      Card(
                        color: Colors.green[50],
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 48),
                              const SizedBox(height: 8),
                              const Text(
                                'You have access to this item',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Contact the finder to arrange return',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Text(
                                          item['reporter_name'] ?? 'Anonymous',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Text(item['reporter_phone'] ?? 'No phone provided'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _launchPhone(item['reporter_phone']);
                                      },
                                      icon: const Icon(Icons.phone, size: 18),
                                      label: const Text('Call'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _launchSMS(item['reporter_phone']);
                                      },
                                      icon: const Icon(Icons.message, size: 18),
                                      label: const Text('Message'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_isItemFounder(item) && item['status'] == 'pending')
                      Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.access_time, color: Colors.orange, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'Access Pending',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your request to access this item is pending approval',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_isItemFounder(item) && 
                        item['status'] != 'approved' && 
                        item['status'] != 'pending' && 
                        item['access_level'] != 'accessible')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton.icon(
                          onPressed: () =>_showRequestAccessDialog(item),
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Request Access to View Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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

void _launchPhone(String? phone) async {
  if (phone == null || phone.isEmpty) return;
  final Uri launchUri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  } else {
    throw 'Could not launch $phone';
  }
}

void _launchSMS(String? phone) async {
  if (phone == null || phone.isEmpty) return;
  final Uri launchUri = Uri(
    scheme: 'sms',
    path: phone,
    queryParameters: {'body': 'Hello, I am interested in the item you found...'},
  );
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  } else {
    throw 'Could not launch SMS';
  }
}

Widget _owner(){
  return Container(
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
        'You post this item ',
        style: TextStyle(
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    ],
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