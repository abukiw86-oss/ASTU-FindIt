import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _user;
  List<dynamic> _history = [];

  bool _isLoading = true;
  bool _isEditingProfile = false;
  bool _isSavingItem = false;

  // Profile editing
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Item editing
  String? _editingItemId;
  final _editTitleController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  final _editLocationController = TextEditingController();
  String _editCategory = 'electronics';

  List<String> _currentImagePaths = [];
  List<XFile> _newImages = [];
  List<String> _removedImagePaths = [];

  final ImagePicker _picker = ImagePicker();

  // Categories
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

  // ────────────────────────────────────────────────
  // Load data
  // ────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getUser();
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
        return;
      }

      if (mounted) {
        setState(() {
          _user = user;
          _nameController.text = user['full_name'] ?? '';
          _phoneController.text = user['phone'] ?? '';
        });
        await _loadUserHistory();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error loading profile', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserHistory() async {
    if (_user == null) return;

    try {
      final result = await ProfileService.getUserHistory(
        userId: _user!['user_string_id'] as String,
      );

      if (mounted && result['success'] == true) {
        setState(() {
          _history = result['history'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to load history', Colors.orange);
    }
  }


  Future<void> _updateProfile() async {
    if (_user == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await ProfileService.updateUserProfile(
        userId: _user!['user_string_id'] as String,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _user!['full_name'] = _nameController.text.trim();
          _user!['phone'] = _phoneController.text.trim();
          _isEditingProfile = false;
        });

        await AuthService.saveUser(
          userStringId: _user!['user_string_id'],
          student_id: _user!['student_id'],
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _user!['role'],
        );

        _showSnackBar('Profile updated', Colors.green);
      } else {
        _showSnackBar(result['message'] ?? 'Update failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEditing(dynamic item) {
    final string_id = item['item_string_id']?.toString();
    if (string_id == null) return;

    setState(() {
      _editingItemId = string_id;
      _editTitleController.text = item['title'] ?? '';
      _editDescriptionController.text = item['description'] ?? '';
      _editLocationController.text = item['location'] ?? '';
      _editCategory = item['category'] ?? 'other';

      _currentImagePaths = _parseImagePaths(item['image_path']);
      _newImages = [];
      _removedImagePaths = [];
    });

    _showEditBottomSheet();
  }

  Future<void> _pickEditImages() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (images != null && images.isNotEmpty && mounted) {
        setState(() => _newImages.addAll(images));
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e', Colors.red);
    }
  }

  void _removeExistingImage(String path) {
    setState(() {
      _currentImagePaths.remove(path);
      _removedImagePaths.add(path);
    });
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _saveItemChanges() async {
    if (_editingItemId == null) return;

    final title = _editTitleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Title is required', Colors.orange);
      return;
    }
    setState(() => _isSavingItem = true);
    try {
      final result = await ProfileService.updateItem( 
        itemId: _editingItemId!,
        userStringId: await AuthService.getUserStringId() ?? '',
        title: title,
        description: _editDescriptionController.text.trim(),
        location: _editLocationController.text.trim(),
        category: _editCategory,
        keptImagePaths: _currentImagePaths,
        removedImagePaths: _removedImagePaths,
        newImages: _newImages.map((xfile) => File(xfile.path)).toList(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnackBar('Item updated successfully', Colors.green);
        Navigator.pop(context); 
        await _loadUserHistory(); 
      } else {
        _showSnackBar(result['message'] ?? 'Update failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Failed to save: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSavingItem = false);
    }
  }

  void _showEditBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[350],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue[700], size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Edit Item',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Images section
                      const Text('Images', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),

                      if (_currentImagePaths.isNotEmpty) ...[
                        const Text('Current images', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        _buildImageList(_currentImagePaths, isNew: false),
                        const SizedBox(height: 20),
                      ],

                      if (_newImages.isNotEmpty) ...[
                        const Text('New images', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        _buildImageList(_newImages.map((e) => e.path).toList(), isNew: true),
                        const SizedBox(height: 20),
                      ],

                      OutlinedButton.icon(
                        onPressed: _pickEditImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(_newImages.isEmpty ? 'Add images' : 'Add more'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Max 8 images recommended • jpg, png, webp',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Form fields
                      TextFormField(
                        controller: _editTitleController,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.title),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _editDescriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _editLocationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSavingItem ? null : _saveItemChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isSavingItem
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text('Save Changes'),
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

  Widget _buildImageList(List<String> paths, {required bool isNew}) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        itemBuilder: (context, index) {
          final path = paths[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isNew
                      ? Image.file(
                          File(path),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          _getImageUrl(path),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      if (isNew) {
                        _removeNewImage(index);
                      } else {
                        _removeExistingImage(path);
                      }
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.close, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteItem(String itemId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "$title" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteItem(itemId);
    }
  }

Future<void> _deleteItem(String itemId) async {
    setState(() => _isLoading = true);

    try {
      final result = await ProfileService.deleteItem(
        itemId: itemId,
        userId: _user?['user_string_id'] ?? '',
      );

      if (result['success'] == true) {
        _showSnackBar('Item deleted', Colors.green);
        await _loadUserHistory();
      } else {
        _showSnackBar(result['message'] ?? 'Delete failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor, duration: const Duration(seconds: 3)),
    );
  }

String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://astufindit.x10.mx/index/$path';
  }

List<String> _parseImagePaths(dynamic imagePath) {
    if (imagePath == null) return [];

    String str = imagePath.toString().trim();

    if (str.startsWith("'") && str.endsWith("'")) {
      str = str.substring(1, str.length - 1);
    }

    if (str.isEmpty || str == 'NULL' || str == 'null') return [];

    return str.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

bool _canEditItem(dynamic item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    final isOwner = item['user_string_id'] == (_user?['user_string_id'] ?? '');
    return isOwner && status == 'open' || status == 'admin_approval' ;
  }
  @override
Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditingProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditingProfile = true),
            ),
          if (_isEditingProfile)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditingProfile = false;
                  _nameController.text = _user?['full_name'] ?? '';
                  _phoneController.text = _user?['phone'] ?? '';
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
    if (_user == null) return const SizedBox();

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
              gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15)],
            ),
            child: Center(
              child: Text(
                (_user!['full_name']?[0] ?? '?').toUpperCase(),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: _user!['student_id'],
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'student id',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    readOnly: !_isEditingProfile,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    readOnly: !_isEditingProfile,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  if (_isEditingProfile)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _updateProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                await AuthService.logout();
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No history yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Your reported and claimed items will appear here', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final isLost = item['type'] == 'lost';
        final canEdit = _canEditItem(item);
        final images = _parseImagePaths(item['image_path']);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLost ? Colors.red[100] : Colors.green[100],
                  child: Icon(isLost ? Icons.search_off : Icons.check_circle, color: isLost ? Colors.red : Colors.green),
                ),
                title: Text(item['title'] ?? 'No title', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_formatDate(item['created_at']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('Status - ${item['status']}', style: const TextStyle(fontWeight: FontWeight.bold))
                  ],
                ),
              ),
              if (images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _getImageUrl(images[i]),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              if (canEdit)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _startEditing(item),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _confirmDeleteItem(
                          item['item_string_id'].toString(),
                          item['title'] ?? 'this item',
                        ),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
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
}