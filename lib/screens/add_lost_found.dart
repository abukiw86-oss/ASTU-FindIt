import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedType = 'lost';
  String _selectedCategory = 'electronics'; // Default category

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  String? _reporterName;
  String? _reporterPhone;

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
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getUser();
      if (user != null && mounted) {
        setState(() {
          _reporterName = user['full_name'] as String?;
          _reporterPhone = user['phone'] as String?;
        });
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Please login to report items';
          });
        }
      }
    } catch (e) {
      // 
    }
  }

  Future<void> _pickImage() async {
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
        final fileSizeMB = fileSize / (1024 * 1024);

        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image is too large (${fileSizeMB.toStringAsFixed(1)}MB). Please choose an image under 5MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (await file.exists()) {
          if (mounted) {
            setState(() {
              _selectedImage = file;
            });
          }
        }
      }
    } catch (e) {
      // 
    }
  }

  void _removeImage() {
    if (mounted) {
      setState(() {
        _selectedImage = null;
      });
    }
  }

Future<void> _submit() async {
  FocusScope.of(context).unfocus();

  String typeToSend = _selectedType.trim().toLowerCase();
  
  if (typeToSend.isEmpty) {
    typeToSend = 'lost';
    setState(() {
      _selectedType = 'lost';
    });
  }
  
  if (typeToSend != 'lost' && typeToSend != 'found') {
    typeToSend = 'lost';
    setState(() {
      _selectedType = 'lost';
    });
  }
  
  if (!_formKey.currentState!.validate()) {
    return;
  }

  if (_reporterName == null || _reporterName!.trim().isEmpty) {
    setState(() {
      _errorMessage = 'Your name is missing. Please login again.';
    });
    return;
  }

  if (_reporterPhone == null || _reporterPhone!.trim().isEmpty) {
    setState(() {
      _errorMessage = 'Your phone number is missing. Please login again.';
    });
    return;
  }

  if (typeToSend == 'found' && _selectedImage == null) {
    setState(() {
      _errorMessage = 'Photo is required for found items';
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
  });
  
  try {
  final user = await AuthService.getUser();
  String? userStringId = user?['user_string_id'];
  
  // CRITICAL: Check if user_string_id exists
  if (userStringId == null || userStringId.isEmpty) {
    // Try to refresh user data
    final refreshedUser = await AuthService.getUser();
    userStringId = refreshedUser?['user_string_id'];
    
    if (userStringId == null || userStringId.isEmpty) {
      setState(() {
        _errorMessage = 'User ID not found. Please login again.';
        _isLoading = false;
      });
      return;
    }
  }
  
  print('✅ Using user_string_id: $userStringId');
  
  final result = await ApiService.reportItem(
    type: typeToSend,
    title: _titleController.text.trim(),
    description: _descriptionController.text.trim(),
    location: _locationController.text.trim().isEmpty 
        ? null 
        : _locationController.text.trim(),
    category: _selectedCategory,
    imageFile: _selectedImage,
    reporterName: _reporterName!.trim(),
    reporterPhone: _reporterPhone!.trim(),
    userStringId: userStringId, 
  );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        setState(() {
          _successMessage = result['message'] ?? 'Item reported successfully!';
        });

        _showSuccessDialog();

        // Reset form
        _titleController.clear();
        _descriptionController.clear();
        _locationController.clear();
        setState(() {
          _selectedType = 'lost';
          _selectedCategory = 'electronics';
          _selectedImage = null;
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to report item';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    // 
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }
}
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(_successMessage ?? 'Item reported successfully'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && (_reporterName == null || _reporterPhone == null)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Report Item'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 18, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Lost / Found Item'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reporter info card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: const Icon(Icons.person, color: Colors.blue),
                    ),
                    title: Text(
                      _reporterName ?? 'Loading...',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Phone: ${_reporterPhone ?? 'Loading...'}'),
                  ),
                ),

                Text(
                  'Item Type *',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Lost'),
                      selected: _selectedType == 'lost',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedType = 'lost';
                          });
                        }
                      },
                      selectedColor: Colors.red[100],
                      labelStyle: TextStyle(
                        color: _selectedType == 'lost' ? Colors.red[900] : Colors.black,
                        fontWeight: _selectedType == 'lost' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Found'),
                      selected: _selectedType == 'found',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedType = 'found';
                          });
                        }
                      },
                      selectedColor: Colors.green[100],
                      labelStyle: TextStyle(
                        color: _selectedType == 'found' ? Colors.green[900] : Colors.black,
                        fontWeight: _selectedType == 'found' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.title),
                    hintText: 'e.g., Blue Backpack',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                    hintText: 'Describe the item in detail...',
                  ),
                  maxLines: 5,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Description is required';
                    }
                    if (v.trim().length < 10) {
                      return 'Please provide more details (min 10 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location Field
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.location_on),
                    hintText: 'e.g., Library, Cafeteria, Room 203',
                  ),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                Text(
                  'Category *',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.arrow_drop_down),
                    elevation: 16,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue!;
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

                const SizedBox(height: 24),

                // Photo Section
             Text(
                  _selectedType == 'lost' 
                      ? 'Photo (optional)' 
                      : 'Photo (required for found items)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: Text(_selectedImage == null 
                            ? 'No image selected' 
                            : 'Image selected'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedImage != null)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _removeImage,
                              ),
                            IconButton(
                              icon: const Icon(Icons.add_photo_alternate),
                              onPressed: _isLoading ? null : _pickImage,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedImage != null)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),

                if (_successMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green[900]),
                    ),
                  ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _selectedType == 'lost' 
                                ? Icons.warning_amber 
                                : Icons.check_circle,
                          ),
                    label: Text(
                      _isLoading 
                          ? 'Submitting...' 
                          : 'Submit ${_selectedType == 'lost' ? 'Lost' : 'Found'} Report',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedType == 'lost' 
                          ? Colors.red[700] 
                          : Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}