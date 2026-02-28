import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ReportItemOrMatchScreen extends StatefulWidget {
  final String? initialType; 

  final String? lostItemId;
  final String? lostItemTitle;
  final String? lostItemImage;

  const ReportItemOrMatchScreen({
    super.key,
    this.initialType,
    this.lostItemId,
    this.lostItemTitle,
    this.lostItemImage,
  });

  @override
  State<ReportItemOrMatchScreen> createState() => _ReportItemOrMatchScreenState();
}

class _ReportItemOrMatchScreenState extends State<ReportItemOrMatchScreen> {
  final _formKey = GlobalKey<FormState>();

  late bool _isMatchMode;
  String _reportType = 'lost'; 

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  DateTime? _foundDate;
  TimeOfDay? _foundTime;
  bool _hasSerialNumber = false;
  bool _hasDistinctiveMark = false;
  bool _hasReceipt = false;
  bool _hasPackaging = false;

  bool _isLoading = false;
  String? _errorMessage;


  @override
  void initState() {
    super.initState();

    _isMatchMode = widget.lostItemId != null && widget.lostItemId!.isNotEmpty;

    if (_isMatchMode) {
      _reportType = 'found';
      if (widget.lostItemTitle != null) {
        _titleController.text = 'i Found : ${widget.lostItemTitle}';
      }
    } else if (widget.initialType != null &&
        (widget.initialType == 'lost' || widget.initialType == 'found')) {
      _reportType = widget.initialType!;
    }
  }

  Future<String?> _getUserStringId() async {
    try {
      final user = await AuthService.getUser();
      return user?['user_string_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? picked = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (picked != null) {
        for (final xfile in picked) {
          final file = File(xfile.path);
          final size = await file.length();
          if (size > 5 * 1024 * 1024) {
            _showSnackBar('Image too large (max 5MB)', Colors.orange);
            continue;
          }
          setState(() => _selectedImages.add(file));
        }
      }
    } catch (e) {
      _showSnackBar('Error picking images: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _foundDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _foundTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userStringId = await _getUserStringId();
    if (userStringId == null || userStringId.isEmpty) {
      _showSnackBar('Cannot identify user. Please login again.', Colors.red);
      return;
    }

    if (_isMatchMode && _foundDate == null) {
      _showSnackBar('Please select the date you found the item', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;
      
    final String? userName = await AuthService.getUserName();
    final String? userPhone = await AuthService.getUserphone();
       

      if (_isMatchMode) {
        final props = {
          'hasSerialNumber': _hasSerialNumber,
          'hasDistinctiveMark': _hasDistinctiveMark,
          'hasReceipt': _hasReceipt,
          'hasPackaging': _hasPackaging,
        };

        final message = '''
        Description match: ${_descriptionController.text.trim()}
        Extra info: ${_additionalInfoController.text.trim()}
        '''.trim();
        
        result = await ApiService.reportFoundMatch(
          lostItemStringId: widget.lostItemId!,
          finderName: userName.toString(), 
          finderPhone: userPhone.toString(), 
          finderMessage: message,
          userStringId: userStringId,
          title : _titleController.text.trim(),
          location :_locationController.text.trim(),
          properties :'$props',
          foundDate :' ${_foundDate != null ? '${_foundDate!.day}/${_foundDate!.month}/${_foundDate!.year}' : '—'} ${_foundTime?.format(context) ?? '—'}',
          imageFiles: _selectedImages,
        );
      } else {
        result = await ApiService.reportlostItem(
          type: _reportType,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          imageFiles: _selectedImages,
          reporterName:userName.toString(), 
          reporterPhone: userPhone.toString(),    
          userStringId: userStringId,
        );
      }

      if (result['success'] == true) {
        _showSnackBar(
          _isMatchMode ? 'Match report submitted!' : 'Report submitted successfully!',
          Colors.green,
        );
      } else {
        _errorMessage = result['message'] ?? 'Submission failed';
        _showSnackBar(_errorMessage!, Colors.red);
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      _showSnackBar(_errorMessage!, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
       AuthService.isLoggedIn();
    final isLost = !_isMatchMode && _reportType == 'lost';
    final primaryColor = isLost ? Colors.red : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isMatchMode
              ? 'Report Found Match'
              : 'Report ${isLost ? 'Lost' : 'Found'} Item',
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isMatchMode && widget.lostItemTitle != null) ...[
                        Card(
                          color: Colors.blue[50],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                if (widget.lostItemImage != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      widget.lostItemImage!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'You are reporting a possible match for:',
                                        style: TextStyle(fontSize: 13, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.lostItemTitle!,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (!_isMatchMode) ...[
                        const Text(
                          'Report Type *',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            ChoiceChip(
                              label: const Text('Lost'),
                              selected: _reportType == 'lost',
                              onSelected: (sel) => setState(() => _reportType = 'lost'),
                              selectedColor: Colors.red[100],
                              labelStyle: TextStyle(
                                color: _reportType == 'lost' ? Colors.red[900] : null,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Found'),
                              selected: _reportType == 'found',
                              onSelected: (sel) => setState(() => _reportType = 'found'),
                              selectedColor: Colors.green[100],
                              labelStyle: TextStyle(
                                color: _reportType == 'found' ? Colors.green[900] : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Title *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.title),
                          ),
                          validator: (v) =>
                              (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
                        ),

                      if (!_isMatchMode) const SizedBox(height: 20),

                      const Text(
                        'Photos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isMatchMode || _reportType == 'found'
                            ? 'Required — take clear photos from multiple angles'
                            : 'Optional but highly recommended',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      if (_selectedImages.isNotEmpty)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, i) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    _selectedImages[i],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Photos'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),

                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          alignLabelWithHint: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Description is required';
                          if (v.trim().length < 10) return 'Please provide more details';
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location ${!_isMatchMode ? '(optional)' : '*'}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        validator: _isMatchMode
                            ? (v) => (v?.trim().isEmpty ?? true) ? 'Location is required' : null
                            : null,
                      ),

                      const SizedBox(height: 24),
                      if (_isMatchMode) ...[
                        const SizedBox(height: 24),
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
                                  _foundTime == null ? 'Select Time' : _foundTime!.format(context),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'Helpful properties (check all that apply)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Card(
                          margin: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                title: const Text('Has serial number / IMEI'),
                                value: _hasSerialNumber,
                                onChanged: (v) => setState(() => _hasSerialNumber = v ?? false),
                              ),
                              CheckboxListTile(
                                title: const Text('Has distinctive mark / damage / engraving'),
                                value: _hasDistinctiveMark,
                                onChanged: (v) => setState(() => _hasDistinctiveMark = v ?? false),
                              ),
                              CheckboxListTile(
                                title: const Text('Has receipt / proof of purchase'),
                                value: _hasReceipt,
                                onChanged: (v) => setState(() => _hasReceipt = v ?? false),
                              ),
                              CheckboxListTile(
                                title: const Text('Has original packaging / box'),
                                value: _hasPackaging,
                                onChanged: (v) => setState(() => _hasPackaging = v ?? false),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _additionalInfoController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Additional information',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: 'Anything else that might help identify the owner...',
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Icon(isLost ? Icons.warning_amber : Icons.check_circle),
                          label: Text(
                            _isLoading
                                ? 'Submitting...'
                                : _isMatchMode
                                    ? 'Submit Match Report'
                                    : 'Submit ${isLost ? 'Lost' : 'Found'} Report',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
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
                      ],

                      const SizedBox(height: 40),
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
    _additionalInfoController.dispose();
    super.dispose();
  }
}