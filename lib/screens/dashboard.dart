import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'add_lost_found.dart';
import '../services/auth_service.dart';
import 'login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _featuredPageController;

  List<Map<String, dynamic>> lostItems = [];
  List<Map<String, dynamic>> foundItems = [];
  List<Map<String, dynamic>> recentItems = [];
  Set<int> pinnedItems = {};

  bool isLoading = true;
  String? errorMessage;
  int _currentFeaturedPage = 0;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _featuredPageController = PageController(viewportFraction: 0.85);
    _initializeData();
    
    _featuredPageController.addListener(() {
      setState(() {
        _currentFeaturedPage = _featuredPageController.page?.round() ?? 0;
      });
    });
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _loadPinnedItems();
    await _loadItems();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getUser();
      if (user != null && mounted) {
        setState(() {
          // Safely convert id to int
          currentUserId = _safeParseInt(user['id']);
        });
        print('✅ User ID loaded: $currentUserId');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  // Safe integer parsing helper
  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }

  // Safe string parsing helper
  String _safeParseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  // Check if item belongs to current user
  bool _isMyItem(Map<String, dynamic> item) {
    if (currentUserId == null) return false;
    
    final dynamic itemUserId = item['user_id'];
    final int? parsedItemUserId = _safeParseInt(itemUserId);
    
    return parsedItemUserId != null && parsedItemUserId == currentUserId;
  }

  Future<void> _loadPinnedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinnedList = prefs.getStringList('pinned_items') ?? [];
      
      setState(() {
        pinnedItems = pinnedList
            .map((e) => int.tryParse(e) ?? 0)
            .where((id) => id > 0)
            .toSet();
      });
      print('📌 Loaded pinned items: $pinnedItems');
    } catch (e) {
      print('❌ Error loading pinned items: $e');
      pinnedItems = {};
    }
  }

  Future<void> _togglePinItem(int itemId) async {
    if (itemId <= 0) return;
    
    try {
      setState(() {
        if (pinnedItems.contains(itemId)) {
          pinnedItems.remove(itemId);
        } else {
          pinnedItems.add(itemId);
        }
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'pinned_items',
        pinnedItems.map((e) => e.toString()).toList(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pinnedItems.contains(itemId) 
                  ? 'Item pinned' 
                  : 'Item unpinned',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling pin: $e');
    }
  }

  bool _isItemPinned(int itemId) {
    return pinnedItems.contains(itemId);
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final lostResult = await ApiService.getItems(type: 'lost');
      final foundResult = await ApiService.getItems(type: 'found');

      if (mounted) {
        setState(() {
          isLoading = false;

          // Safely parse lost items
          if (lostResult['success'] == true && lostResult['items'] != null) {
            lostItems = _parseItems(lostResult['items']);
          } else {
            errorMessage = _safeParseString(lostResult['message']);
          }

          // Safely parse found items
          if (foundResult['success'] == true && foundResult['items'] != null) {
            foundItems = _parseItems(foundResult['items']);
          } else if (errorMessage == null) {
            errorMessage = _safeParseString(foundResult['message']);
          }

          // Combine and sort recent items
          _updateRecentItems();
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

  List<Map<String, dynamic>> _parseItems(dynamic items) {
    if (items == null) return [];
    
    try {
      if (items is List) {
        return items.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            // Convert Map<dynamic, dynamic> to Map<String, dynamic>
            return item.map((key, value) => MapEntry(key.toString(), value));
          }
          return <String, dynamic>{};
        }).toList();
      }
    } catch (e) {
      print('❌ Error parsing items: $e');
    }
    return [];
  }

  void _updateRecentItems() {
    recentItems = [...lostItems, ...foundItems];
    recentItems.sort((a, b) {
      final String aDate = _safeParseString(a['created_at']);
      final String bDate = _safeParseString(b['created_at']);
      
      try {
        final DateTime aDateTime = DateTime.parse(aDate);
        final DateTime bDateTime = DateTime.parse(bDate);
        return bDateTime.compareTo(aDateTime);
      } catch (e) {
        return 0;
      }
    });
    
    if (recentItems.length > 10) {
      recentItems = recentItems.sublist(0, 10);
    }
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://astufindit.x10.mx/index/$path';
  }

  void _showFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                 _getImageUrl(imagePath),
                fit: BoxFit.contain,
                // placeholder: (context, url) => const Center(
                //   child: CircularProgressIndicator(color: Colors.white),
                // ),
                // errorWidget: (context, url, error) => Column(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     const Icon(Icons.error, color: Colors.white, size: 50),
                //     const SizedBox(height: 16),
                //     Text(
                //       'Failed to load image',
                //       style: TextStyle(color: Colors.grey[400]),
                //     ),
                //   ],
                // ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: FutureBuilder<String?>(
          future: AuthService.getUserName(),
          builder: (context, snapshot) {
            final String? userName = snapshot.data;
            if (userName != null && userName.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lost & Found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  ),
                  Text(
                    'Welcome, $userName',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                  ),
                ],
              );
            }
            return const Text('Lost & Found Dashboard');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
            tooltip: 'Refresh',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: _showPinnedItems,
                tooltip: 'Pinned Items',
              ),
              if (pinnedItems.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${pinnedItems.length}',
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.blue,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Lost Items', icon: Icon(Icons.search_off)),
                  Tab(text: 'Found Items', icon: Icon(Icons.check_circle)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorView()
              : Column(
                  children: [
                    if (recentItems.isNotEmpty) _buildRecentCarousel(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildItemList(lostItems, 'No lost items reported yet', Colors.red),
                          _buildItemList(foundItems, 'No found items reported yet', Colors.green),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportItemScreen()),
          ).then((_) {
            _loadItems();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Report Item'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showPinnedItems() {
    final pinnedList = recentItems.where((item) {
      final int? itemId = _safeParseInt(item['id']);
      return itemId != null && pinnedItems.contains(itemId);
    }).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 16),
                const Text(
                  'Pinned Items',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  pinnedList.isEmpty 
                      ? 'No pinned items yet' 
                      : '${pinnedList.length} item${pinnedList.length > 1 ? 's' : ''} pinned',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: pinnedList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.push_pin, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No pinned items yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the pin icon on items to save them',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: pinnedList.length,
                          itemBuilder: (context, index) {
                            final item = pinnedList[index];
                            return _buildPinnedItem(item);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinnedItem(Map<String, dynamic> item) {
    final String type = _safeParseString(item['type']);
    final bool isLost = type == 'lost';
    final Color color = isLost ? Colors.red : Colors.green;
    final int? itemId = _safeParseInt(item['id']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isLost ? Icons.search_off : Icons.check_circle,
            color: color,
          ),
        ),
        title: Text(_safeParseString(item['title'], defaultValue: 'No title')),
        subtitle: Text(_safeParseString(item['location'], defaultValue: 'Unknown location')),
        trailing: IconButton(
          icon: const Icon(Icons.push_pin, color: Colors.blue),
          onPressed: () {
            if (itemId != null) {
              _togglePinItem(itemId);
              Navigator.pop(context);
            }
          },
        ),
        onTap: () => _showItemDetails(item),
      ),
    );
  }
  Widget _buildRecentCarousel() {
    return Container(
      height: 240,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_currentFeaturedPage + 1}/${recentItems.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _featuredPageController,
              itemCount: recentItems.length,
              itemBuilder: (context, index) {
                final item = recentItems[index];
                return _buildRecentItemCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItemCard(Map<String, dynamic> item) {
    final String type = _safeParseString(item['type']);
    final bool isLost = type == 'lost';
    final Color color = isLost ? Colors.red : Colors.green;
    final String imagePath = _safeParseString(item['image_path']);
    final bool hasImage = imagePath.isNotEmpty;
    final int? itemId = _safeParseInt(item['id']);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

// With this:
if (hasImage)
  GestureDetector(
    onTap: () => _showFullScreenImage(imagePath),
    child: Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Image.network(
          _getImageUrl(imagePath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 120,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Image error in recent card: $error');
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey[400],
                  size: 40,
                ),
              ),
            );
          },
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
        ),
      ),
    ),
  )
              else
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Icon(
                      isLost ? Icons.search_off : Icons.check_circle,
                      color: color,
                      size: 40,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _safeParseString(item['title'], defaultValue: 'No title'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isLost ? 'LOST' : 'FOUND',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _safeParseString(item['description']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _safeParseString(item['location'], defaultValue: 'Unknown location'),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (itemId != null)
            Positioned(
              top: hasImage ? 8 : 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  _isItemPinned(itemId) ? Icons.push_pin : Icons.push_pin_outlined,
                  color: _isItemPinned(itemId) ? Colors.blue : Colors.grey,
                  size: 20,
                ),
                onPressed: () => _togglePinItem(itemId),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadItems,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemList(List<Map<String, dynamic>> items, String emptyMessage, Color color) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              color == Colors.red ? Icons.search_off : Icons.check_circle,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      color: color,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildListItem(item, color);
        },
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item, Color color) {
    final bool isLost = color == Colors.red;
    final String imagePath = _safeParseString(item['image_path']);
    final bool hasImage = imagePath.isNotEmpty;
    final int? itemId = _safeParseInt(item['id']);
    final bool isPinned = itemId != null && _isItemPinned(itemId);
    final bool isMyItem = _isMyItem(item);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showItemDetails(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
// Replace the image section:
GestureDetector(
  onTap: hasImage ? () => _showFullScreenImage(imagePath) : null,
  child: Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      color: hasImage ? Colors.transparent : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: hasImage
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _getImageUrl(imagePath),
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              errorBuilder: (context, error, stackTrace) {
                print('❌ Image error in list item: $error');
                return Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey[400],
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / 
                              loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        : Icon(
            isLost ? Icons.search_off : Icons.check_circle,
            color: color,
            size: 40,
          ),
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
                            _safeParseString(item['title'], defaultValue: 'No title'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyItem)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MY ITEM',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getTimeAgo(item['created_at']),
                            style: TextStyle(
                              fontSize: 10,
                              color: color.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _safeParseString(item['description']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _safeParseString(item['location'], defaultValue: 'Unknown location'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (itemId != null)
                          IconButton(
                            icon: Icon(
                              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                              color: isPinned ? Colors.blue : Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => _togglePinItem(itemId),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
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

  void _showItemDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildItemDetailsSheet(item),
    );
  }

  Widget _buildItemDetailsSheet(Map<String, dynamic> item) {
    final String type = _safeParseString(item['type']);
    final bool isLost = type == 'lost';
    final Color color = isLost ? Colors.red : Colors.green;
    final String imagePath = _safeParseString(item['image_path']);
    final bool hasImage = imagePath.isNotEmpty;
    final int? itemId = _safeParseInt(item['id']);
    final bool isPinned = itemId != null && _isItemPinned(itemId);
    final bool isMyItem = _isMyItem(item);
    
    return DraggableScrollableSheet(
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
              
// Replace the image section:
if (hasImage)
  GestureDetector(
    onTap: () {
      Navigator.pop(context);
      _showFullScreenImage(imagePath);
    },
    child: Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.network(
              _getImageUrl(imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                print('❌ Image error in details: $error');
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Tap to view fullscreen',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
              if (hasImage) const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isLost ? 'LOST ITEM' : 'FOUND ITEM',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (isMyItem) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'MY ITEM',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _safeParseString(item['title'], defaultValue: 'No title'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (itemId != null)
                    IconButton(
                      icon: Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: isPinned ? Colors.blue : Colors.grey,
                        size: 28,
                      ),
                      onPressed: () {
                        _togglePinItem(itemId);
                        setState(() {});
                      },
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailSection(
                      'Description',
                      _safeParseString(item['description'], defaultValue: 'No description provided'),
                      Icons.description,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Location',
                      _safeParseString(item['location'], defaultValue: 'Unknown location'),
                      Icons.location_on,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Category',
                      _safeParseString(item['category'], defaultValue: 'Other'),
                      Icons.category,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Reported By',
                      '${_safeParseString(item['reporter_name'], defaultValue: 'Anonymous')} • ${_safeParseString(item['reporter_phone'], defaultValue: 'No phone')}',
                      Icons.person,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Date Reported',
                      _formatDate(item['created_at']),
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Status',
                      _safeParseString(item['status'], defaultValue: 'Open'),
                      Icons.info,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final phone = _safeParseString(item['reporter_phone']);
                              if (phone.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Calling $phone...')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No phone number available')),
                                );
                              }
                            },
                            icon: const Icon(Icons.phone),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Messaging feature coming soon')),
                              );
                            },
                            icon: const Icon(Icons.message),
                            label: const Text('Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(dynamic dateString) {
    final String dateStr = _safeParseString(dateString);
    if (dateStr.isEmpty) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()}y ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()}mo ago';
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
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  String _formatDate(dynamic dateString) {
    final String dateStr = _safeParseString(dateString);
    if (dateStr.isEmpty) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _featuredPageController.dispose();
    super.dispose();
  }
}