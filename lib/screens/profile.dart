import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login.dart';
import 'package:intl/intl.dart';

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

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        _user = user;
        _nameController.text = user['full_name'] ?? '';
        _phoneController.text = user['phone'] ?? '';
      });
      _loadUserHistory();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _loadUserHistory() async {
    if (_user == null) return;

    final result = await ProfileService.getUserHistory(
      userId: _user!['id'],
    );

    if (result['success'] == true) {
      setState(() {
        _history = result['history'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (_user == null) return;

    setState(() => _isLoading = true);

    final result = await ProfileService.updateUserProfile(
      userId: _user!['id'],
      fullName: _nameController.text,
      phone: _phoneController.text,
    );

    if (result['success'] == true) {
      setState(() {
        _user!['full_name'] = _nameController.text;
        _user!['phone'] = _phoneController.text;
        _isEditing = false;
        _isLoading = false;
      });
      
      // Update local storage
      await AuthService.saveUser(
        id: _user!['id'],
        email: _user!['email'],
        fullName: _nameController.text,
        phone: _phoneController.text,
        role: _user!['role'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to update profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
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
      body: TabBarView(
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
                          ? null
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
                          ? null
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
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
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
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}