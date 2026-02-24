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

  String _selectedType = 'lost'; // default value – always 'lost' or 'found'

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _categoryController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  String? _reporterName;
  String? _reporterPhone;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Debug: print initial selected type
    print('🔍 INITIAL selected type: $_selectedType');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Debug: print when dependencies change
    print('🔍 DID CHANGE selected type: $_selectedType');
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getUser();
      if (user != null && mounted) {
        setState(() {
          _reporterName = user['full_name'] as String?;
          _reporterPhone = user['phone'] as String?;
        });
        print('✅ User data loaded: $_reporterName / $_reporterPhone');
      } else {
        print('⚠️ No user data found');
        if (mounted) {
          setState(() {
            _errorMessage = 'Please login to report items';
          });
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
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
        
        print('📸 Selected image: ${pickedFile.name}');
        print('📊 Image size: ${fileSizeMB.toStringAsFixed(2)} MB');

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
      print('❌ Error picking image: $e');
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
  // Hide keyboard
  FocusScope.of(context).unfocus();

  // Debug: Print current state before validation
  print('=' * 50);
  print('🔍 CURRENT STATE BEFORE SUBMISSION');
  print('=' * 50);
  print('_selectedType variable: "$_selectedType"');
  print('_selectedType length: ${_selectedType.length}');
  print('_selectedType runtimeType: ${_selectedType.runtimeType}');
  print('_selectedType code units: ${_selectedType.runes.toList()}');
  
  // FIX: Ensure we have a valid type
  String typeToSend = _selectedType.trim().toLowerCase();
  
  // Double-check if it's empty and set default if needed
  if (typeToSend.isEmpty) {
    print('⚠️ CRITICAL: typeToSend is empty! Setting to default "lost"');
    typeToSend = 'lost';
    // Also update the state to fix the UI
    setState(() {
      _selectedType = 'lost';
    });
  }
  
  // Final validation
  if (typeToSend != 'lost' && typeToSend != 'found') {
    print('❌ Invalid type detected: "$typeToSend" - forcing to "lost"');
    typeToSend = 'lost';
    setState(() {
      _selectedType = 'lost';
    });
  }
  
  print('✅ FINAL type to send: "$typeToSend"');

  // Validate form
  if (!_formKey.currentState!.validate()) {
    return;
  }

  // Check reporter info
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

  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
  });

  // Print all data being sent
  print('=' * 50);
  print('📤 SUBMITTING REPORT FROM PAGE');
  print('=' * 50);
  print('Type: "$typeToSend"');
  print('Title: "${_titleController.text.trim()}"');
  print('Description: "${_descriptionController.text.trim()}"');
  print('Location: "${_locationController.text.trim()}"');
  print('Category: "${_categoryController.text.trim()}"');
  print('Reporter Name: "$_reporterName"');
  print('Reporter Phone: "$_reporterPhone"');
  print('Has Image: ${_selectedImage != null}');

  try {
    print('⏳ Calling ApiService.reportItem with type: "$typeToSend"');
    
    final result = await ApiService.reportItem(
      type: typeToSend,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty 
          ? null 
          : _locationController.text.trim(),
      category: _categoryController.text.trim().isEmpty 
          ? 'other' 
          : _categoryController.text.trim(),
      imageFile: _selectedImage,
      reporterName: _reporterName!.trim(),
      reporterPhone: _reporterPhone!.trim(),
    );

    print('📥 API Response in page: $result');

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
        _categoryController.clear();
        setState(() {
          _selectedType = 'lost';
          _selectedImage = null;
        });

        // Clear success message after 3 seconds
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
        
        // Show error in snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    print('❌ Exception during submission: $e');
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
    // Show error screen if reporter info is missing
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

                // Item Type Selection - FIXED SEGMENTED BUTTON
                Text(
                  'Item Type *',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Debug: Show current selected type
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Text(
                    'Debug - Selected: "$_selectedType"',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

               Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Lost'),
              selected: _selectedType == 'lost',
              onSelected: (selected) {
                if (selected) {
                  print('🔘 Lost chip selected - setting type to "lost"');
                  setState(() {
                    _selectedType = 'lost';
                  });
                  // Force a rebuild and print the new value
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    print('✅ After setState, _selectedType = "$_selectedType"');
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
                  print('🔘 Found chip selected - setting type to "found"');
                  setState(() {
                    _selectedType = 'found';
                  });
                  // Force a rebuild and print the new value
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    print('✅ After setState, _selectedType = "$_selectedType"');
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
                  ),
                ),
                const SizedBox(height: 16),

                // Category Field
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                ),
                const SizedBox(height: 24),

                // Photo Section
                Text(
                  'Photo (optional)',
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

                // Error/Success Messages
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
    _categoryController.dispose();
    super.dispose();
  }
}