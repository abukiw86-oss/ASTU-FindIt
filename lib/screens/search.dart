import 'package:flutter/material.dart';
import 'package:lost_found_app/services/serach_service.dart';
import '../services/auth_service.dart';

class SearchFilterPage extends StatefulWidget {
  const SearchFilterPage({super.key});

  @override
  State<SearchFilterPage> createState() => _SearchFilterPageState();
}
class _SearchFilterPageState extends State<SearchFilterPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'all'; 
  bool _isLoading = false;
  
  List<dynamic> _searchResults = [];
  String? _errorMessage;
  
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

Future<void> _loadUserData() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        _currentUserId = user['user_string_id'];
      });
    }
  }

Future<void> _performSearch() async {
  if (_searchController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter something to search'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final result = await search.simpleSearch(
      query: _searchController.text.trim(),
      type: _selectedType,
      userId: _currentUserId,
    );

    if (result['success'] == true) {
      setState(() {
        _searchResults = result['items'] ?? [];
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Search failed';
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Network error. Please try again.';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _selectedType = 'all';
    });
  }

  @override
Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Items'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearSearch,
            tooltip: 'Clear search',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by title, description...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedType == 'all',
                        onSelected: (_) => setState(() => _selectedType = 'all'),
                        backgroundColor: Colors.grey[100],
                        selectedColor: Colors.blue.withOpacity(0.2),
                        checkmarkColor: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Lost Items'),
                        selected: _selectedType == 'lost',
                        onSelected: (_) => setState(() => _selectedType = 'lost'),
                        backgroundColor: Colors.red[50],
                        selectedColor: Colors.red.withOpacity(0.2),
                        checkmarkColor: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Found Items'),
                        selected: _selectedType == 'found',
                        onSelected: (_) => setState(() => _selectedType = 'found'),
                        backgroundColor: Colors.green[50],
                        selectedColor: Colors.green.withOpacity(0.2),
                        checkmarkColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Found ${_searchResults.length} items',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 50,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _performSearch,
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 70,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No items found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try searching with different keywords',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return _buildItemCard(item);
                      },
                    ),
         ),
        ],
      ),
    );
  }

Widget _buildItemCard(Map<String, dynamic> item) {
  final isLost = item['type'] == 'lost';
  final isFounder = item['user_string_id'] == _currentUserId;
  
  final List<dynamic> imageList = item['image_list'] ?? [];
  final bool hasMultipleImages = imageList.length > 1;
  final String? firstImage = imageList.isNotEmpty ? imageList.first : null;

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: isLost ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        width: 0.5,
      ),
    ),
    child: InkWell(
      onTap: () => _showItemDetails(item),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: (isLost ? Colors.red : Colors.green).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: firstImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            'https://astufindit.x10.mx/index/$firstImage',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              isLost ? Icons.search_off : Icons.check_circle,
                              color: isLost ? Colors.red : Colors.green,
                              size: 35,
                            ),
                          ),
                        )
                      : Icon(
                          isLost ? Icons.search_off : Icons.check_circle,
                          color: isLost ? Colors.red : Colors.green,
                          size: 35,
                        ),
                ),
                if (hasMultipleImages)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '+${imageList.length - 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFounder)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['description'] ?? 'No description',
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
                      Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['location'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
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
                          color: (isLost ? Colors.red : Colors.green).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['type']?.toUpperCase() ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isLost ? Colors.red : Colors.green,
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
      ),
    ),
  );
}

void _showItemDetails(Map<String, dynamic> item) {
  final List<dynamic> imageList = item['image_list'] ?? [];
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['title'] ?? 'Item Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            
            if (imageList.isNotEmpty) ...[
              Container(
                height: 200,
                child: PageView.builder(
                  itemCount: imageList.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _showFullScreenImage(imageList, index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage('https://astufindit.x10.mx/index/${imageList[index]}'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '1 / ${imageList.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ], 
            _buildDetailRow('Type', item['type'] ?? 'Unknown'),
            _buildDetailRow('Description', item['description'] ?? 'No description'),
            _buildDetailRow('Location', item['location'] ?? 'Unknown'),
            _buildDetailRow('Category', item['category'] ?? 'Other'),
            _buildDetailRow('Reported by', item['reporter_name'] ?? 'Anonymous'),
            _buildDetailRow('Contact', item['reporter_phone'] ?? 'No phone'),
            
            const SizedBox(height: 16), 
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    ),
  );
}

void _showFullScreenImage(List<dynamic> images, int initialIndex) {
  final PageController pageController = PageController(initialPage: initialIndex);
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [ 
          PageView.builder(
            controller: pageController,
            itemCount: images.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.network(
                  'https://astufindit.x10.mx/index//${images[index]}',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                  ),
                ),
              );
            },
          ),
           
          Positioned(
            top: 40,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${initialIndex + 1} / ${images.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}