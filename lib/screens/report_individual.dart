import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ReportFoundMatchScreen extends StatefulWidget {
  final String lostItemId;
  final String lostItemTitle;
  final String? lostItemImage;
  final String userStringId;
  final String userName;
  final String userPhone;

  const ReportFoundMatchScreen({
    super.key,
    required this.lostItemId,
    required this.lostItemTitle,
    this.lostItemImage,
    required this.userStringId,
    required this.userName,
    required this.userPhone,
  });

  @override
  State<ReportFoundMatchScreen> createState() => _ReportFoundMatchScreenState();
}

class _ReportFoundMatchScreenState extends State<ReportFoundMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  
  // Selected category
  String _selectedCategory = 'electronics';
  
  // Images
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  // Date and time found
  DateTime? _foundDate;
  TimeOfDay? _foundTime;
  
  // Properties checkboxes
  bool _hasSerialNumber = false;
  bool _hasDistinctiveMark = false;
  bool _hasReceipt = false;
  bool _hasPackaging = false;
  
  bool _isLoading = false;

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
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (pickedFiles != null) {
        for (var pickedFile in pickedFiles) {
          final file = File(pickedFile.path);
          final fileSize = await file.length();
          
          if (fileSize > 5 * 1024 * 1024) {
            _showSnackBar('Image ${pickedFile.name} is too large (max 5MB)', Colors.red);
            continue;
          }

          if (await file.exists()) {
            setState(() {
              _selectedImages.add(file);
            });
          }
        }
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e', Colors.red);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _foundDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _foundTime = picked;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImages.isEmpty) {
      _showSnackBar('Please add at least one photo of the found item', Colors.orange);
      return;
    }

    if (_foundDate == null) {
      _showSnackBar('Please select when you found the item', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Compile properties
      Map<String, dynamic> properties = {
        'hasSerialNumber': _hasSerialNumber,
        'hasDistinctiveMark': _hasDistinctiveMark,
        'hasReceipt': _hasReceipt,
        'hasPackaging': _hasPackaging,
        'foundDate': _foundDate?.toIso8601String(),
        'foundTime': _foundTime?.format(context),
        'additionalInfo': _additionalInfoController.text,
      };

      // For multiple images, you might need to send them one by one or compress them
      // This example sends the first image (you may need to modify your API to handle multiple images)
      final result = await ApiService.reportFoundMatch(
        lostItemStringId: widget.lostItemId,
        finderName: widget.userName,
        finderPhone: widget.userPhone,
        finderMessage: '''
Location: ${_locationController.text}
Description: ${_descriptionController.text}
Found Date: ${_foundDate?.day}/${_foundDate?.month}/${_foundDate?.year}
Found Time: ${_foundTime?.format(context)}
Properties: ${properties.toString()}
Additional Info: ${_additionalInfoController.text}
        ''',
        userStringId: widget.userStringId,
        imageFile: _selectedImages.isNotEmpty ? _selectedImages.first : null, // Send first image
      );

      if (result['success'] == true) {
        _showSnackBar('Report submitted successfully!', Colors.green);
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        _showSnackBar(result['message'] ?? 'Failed to submit report', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Found Item'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Original lost item info
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (widget.lostItemImage != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.lostItemImage!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'You are reporting:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    widget.lostItemTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Photos section
                    const Text(
                      'Photos of Found Item *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Take clear photos of the item from different angles',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // Image grid
                    if (_selectedImages.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImages[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 12),

                    // Add photo button
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Photos'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Description field
                    const Text(
                      'Description *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe the item in detail...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Description is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Location field
                    const Text(
                      'Where did you find it? *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Library, Cafeteria, Room 203',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Location is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Category dropdown
                    const Text(
                      'Category *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                          });
                        },
                        items: _categories.map((category) {
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

                    const SizedBox(height: 20),

                    // Date and time found
                    const Text(
                      'When did you find it? *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _foundDate == null
                                  ? 'Select Date'
                                  : '${_foundDate!.day}/${_foundDate!.month}/${_foundDate!.year}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _foundTime == null
                                  ? 'Select Time'
                                  : _foundTime!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Properties section
                    const Text(
                      'Properties of the Item',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: const Text('Has Serial Number'),
                              value: _hasSerialNumber,
                              onChanged: (value) {
                                setState(() {
                                  _hasSerialNumber = value ?? false;
                                });
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Has Distinctive Mark/Scratch'),
                              value: _hasDistinctiveMark,
                              onChanged: (value) {
                                setState(() {
                                  _hasDistinctiveMark = value ?? false;
                                });
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Has Receipt/Proof of Purchase'),
                              value: _hasReceipt,
                              onChanged: (value) {
                                setState(() {
                                  _hasReceipt = value ?? false;
                                });
                              },
                            ),
                            CheckboxListTile(
                              title: const Text('Has Original Packaging'),
                              value: _hasPackaging,
                              onChanged: (value) {
                                setState(() {
                                  _hasPackaging = value ?? false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Additional information
                    const Text(
                      'Additional Information',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _additionalInfoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Any other details that might help identify the owner...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _submitReport,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}