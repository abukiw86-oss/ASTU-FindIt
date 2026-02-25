import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import 'login.dart';
import 'add_lost_found.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  Map<String, dynamic>? _user;
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isEditing = false;
  int? _editingItemId; 
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Edit item controllers
  final _editTitleController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  final _editLocationController = TextEditingController();
  String _editCategory = 'electronics';
  File? _editSelectedImage;
  final ImagePicker _picker = ImagePicker();

  // Predefined categories list
  final List<Map<String, dynamic>> _categories = [
    {'value': 'electronics', 'label': '📱 Electronics', 'icon': Icons.phone_android},
    {'value': 'clothing', 'label': '👕 Clothing', 'icon': Icons.checkroom},
    {'value': 'accessories', 'label': '⌚ Accessories', 'icon': Icons.watch},
    {'value': 'books', 'label': '📚 Books', 'icon': Icons.menu_book},
    {'value': 'documents', 'label': '📄 Documents', 'icon': Icons.description},
    {'value': 'keys', 'label': '🔑 Keys', 'icon': Icons.vpn_key},
    {'value': 'bags', 'label': '🎒 Bags', 'icon': Icons.backpack},
    {'value': 'wallets', 'label': '👛 Wallets', 'icon': Icons.account_balance_wallet},
    {'value': 'phones', 'label': '📱 Phones', 'icon': Icons.phone_iphone},
    {'value': 'laptops', 'label': '💻 Laptops', 'icon': Icons.laptop},
    {'value': 'id_cards', 'label': '🪪 ID Cards', 'icon': Icons.credit_card},
    {'value': 'jewelry', 'label': '💍 Jewelry', 'icon': Icons.diamond},
    {'value': 'toys', 'label': '🧸 Toys', 'icon': Icons.toys},
    {'value': 'sports', 'label': '⚽ Sports Equipment', 'icon': Icons.sports_soccer},
    {'value': 'other', 'label': '📦 Other', 'icon': Icons.category},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _editTitleController.dispose();
    _editDescriptionController.dispose();
    _editLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getUser();
      if (user != null && mounted) {
        setState(() {
          _user = user;
          _nameController.text = user['full_name'] ?? '';
          _phoneController.text = user['phone'] ?? '';
        });
        await _loadUserHistory();
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading profile', Colors.red);
      }
    }
  }

  Future<void> _loadUserHistory() async {
    if (_user == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = await ProfileService.getUserHistory(
        userId: _user!['user_string_id'], // Make sure this matches your API parameter name
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _history = result['history'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          _showSnackBar(result['message'] ?? 'Failed to load history', Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading history', Colors.red);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_user == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = await ProfileService.updateUserProfile(
        userId: _user!['user_string_id'], 
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _user!['full_name'] = _nameController.text;
            _user!['phone'] = _phoneController.text;
            _isEditing = false;
            _isLoading = false;
          });
          
          // Update local storage
          await AuthService.saveUser(
            userStringId: _user!['user_string_id'],
            email: _user!['email'],
            fullName: _nameController.text,
            phone: _phoneController.text,
            role: _user!['role'],
          );

          _showSnackBar('Profile updated successfully', Colors.green);
        } else {
          setState(() => _isLoading = false);
          _showSnackBar(result['message'] ?? 'Failed to update profile', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error updating profile', Colors.red);
      }
    }
  }

  void _startEditing(dynamic item) {
    setState(() {
      _editingItemId = int.parse(item['id'].toString());
      _editTitleController.text = item['title'] ?? '';
      _editDescriptionController.text = item['description'] ?? '';
      _editLocationController.text = item['location'] ?? '';
      _editCategory = item['category'] ?? 'electronics';
      _editSelectedImage = null;
    });
    
    _showEditBottomSheet(item);
  }

  void _showEditBottomSheet(dynamic item) {
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
                
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Item',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Current image preview
                      if (item['image_path'] != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(_getImageUrl(item['image_path'])),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // New image picker
                      const Text('Change Image (optional):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: Text(_editSelectedImage == null 
                              ? 'Tap to select new image' 
                              : 'New image selected'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_editSelectedImage != null)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: _removeEditImage,
                                ),
                              IconButton(
                                icon: const Icon(Icons.add_photo_alternate),
                                onPressed: _pickEditImage,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_editSelectedImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _editSelectedImage!,
                              height: 100,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Title field
                      TextFormField(
                        controller: _editTitleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.title),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Description field
                      TextFormField(
                        controller: _editDescriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.description),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Location field
                      TextFormField(
                        controller: _editLocationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Category dropdown
                      const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _editCategory,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.arrow_drop_down),
                          elevation: 16,
                          style: const TextStyle(color: Colors.black, fontSize: 16),
                          onChanged: (String? newValue) {
                            setState(() {
                              _editCategory = newValue!;
                            });
                          },
                          items: _categories.map<DropdownMenuItem<String>>((Map<String, dynamic> category) {
                            return DropdownMenuItem<String>(
                              value: category['value'],
                              child: Row(
                                children: [
                                  Icon(category['icon'], size: 20, color: Colors.grey[700]),
                                  const SizedBox(width: 12),
                                  Text(category['label']),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveItemChanges(int.parse(item['id'].toString())),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Save Changes'),
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
      ),
    );
  }

  Future<void> _pickEditImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        
        if (fileSize > 5 * 1024 * 1024) {
          _showSnackBar('Image too large (max 5MB)', Colors.red);
          return;
        }

        if (await file.exists()) {
          setState(() {
            _editSelectedImage = file;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  void _removeEditImage() {
    setState(() {
      _editSelectedImage = null;
    });
  }

  Future<void> _saveItemChanges(int itemId) async {
    if (_editTitleController.text.isEmpty) {
      _showSnackBar('Title is required', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    Navigator.pop(context); // Close bottom sheet

    try {
      final result = await ApiService.updateItem(
        itemId: itemId,
        title: _editTitleController.text.trim(),
        description: _editDescriptionController.text.trim(),
        location: _editLocationController.text.trim(),
        category: _editCategory,
        imageFile: _editSelectedImage,
        userStringId: _user!['user_string_id'],
      );

      if (mounted) {
        if (result['success'] == true) {
          _showSnackBar('Item updated successfully', Colors.green);
          await _loadUserHistory(); // Refresh history
        } else {
          _showSnackBar(result['message'] ?? 'Failed to update item', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _editingItemId = null;
        });
      }
    }
  }

  // ==================== ITEM DELETE FUNCTIONS ====================

  Future<void> _confirmDeleteItem(int itemId, String title) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(itemId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(int itemId) async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.deleteItem(
        itemId: itemId,
        userStringId: _user!['user_string_id'],
      );

      if (mounted) {
        if (result['success'] == true) {
          _showSnackBar('Item deleted successfully', Colors.green);
          await _loadUserHistory(); // Refresh history
        } else {
          _showSnackBar(result['message'] ?? 'Failed to delete item', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==================== HELPER FUNCTIONS ====================

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://astufindit.x10.mx/index/$path';
  }

  String _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'resolved':
        return '🟢';
      case 'pending':
        return '🟡';
      case 'rejected':
        return '🔴';
      default:
        return '⚪';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  bool _canEditItem(dynamic item) {
    // Can edit if item is pending and user is the reporter
    return item['status'] == 'pending' && item['history_type'] == 'reported';
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null && !_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameController.text = _user!['full_name'];
                  _phoneController.text = _user!['phone'] ?? '';
                });
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile', icon: Icon(Icons.person)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _user!['full_name'][0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Profile Info
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Email (read-only)
                  TextFormField(
                    initialValue: _user!['email'],
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Name (editable)
                  TextFormField(
                    controller: _nameController,
                    readOnly: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _isEditing
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _nameController.clear(),
                            )
                          : const Icon(Icons.lock, size: 16, color: Colors.grey),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Phone (editable)
                  TextFormField(
                    controller: _phoneController,
                    readOnly: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.phone),
                      suffixIcon: _isEditing
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _phoneController.clear(),
                            )
                          : const Icon(Icons.lock, size: 16, color: Colors.grey),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Save button when editing
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _updateProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Stats Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Your Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Items Reported',
                        _history.where((item) => item['history_type'] == 'reported').length.toString(),
                        Icons.report,
                        Colors.blue,
                      ),
                      _buildStatItem(
                        'Claims Made',
                        _history.where((item) => item['history_type'] == 'claimed').length.toString(),
                        Icons.handshake,
                        Colors.orange,
                      ),
                      _buildStatItem(
                        'Resolved',
                        _history.where((item) => item['status'] == 'resolved').length.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () async {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Your reported items and claims will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final isReported = item['history_type'] == 'reported';
        final isLost = item['type'] == 'lost';
        final canEdit = _canEditItem(item);
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLost ? Colors.red[100] : Colors.green[100],
                  child: Icon(
                    isLost ? Icons.search_off : Icons.check_circle,
                    color: isLost ? Colors.red : Colors.green,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item['status'] == 'resolved'
                            ? Colors.green.withOpacity(0.1)
                            : item['status'] == 'pending'
                                ? Colors.orange.withOpacity(0.1)
                                : item['status'] == 'approved'
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_getStatusColor(item['status'])} ${item['status']?.toUpperCase() ?? ''}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item['status'] == 'resolved'
                              ? Colors.green
                              : item['status'] == 'pending'
                                  ? Colors.orange
                                  : item['status'] == 'approved'
                                      ? Colors.blue
                                      : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      item['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isReported ? Icons.report : Icons.handshake,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isReported ? 'You reported this' : 'You claimed this',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item['created_at']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (item['image_path'] != null && isReported) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showFullScreenImage(item['image_path']),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(_getImageUrl(item['image_path'])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                isThreeLine: true,
              ),
              
              // Edit/Delete buttons for reported items that are pending
              if (isReported && canEdit)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _startEditing(item),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _confirmDeleteItem(int.parse(item['id'].toString()), item['title']),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Show message for non-editable items
              if (isReported && !canEdit && item['status'] != 'resolved')
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Cannot edit - ${item['status']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
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
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 50),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}