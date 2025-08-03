import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AddPage extends StatefulWidget {
  final void Function(
    String imageId,
    String serverImageUrl,
    String title,
    String category,
    String tag,
    String description,
  )?
  onUploadComplete;

  const AddPage({super.key, this.onUploadComplete});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _tagController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _selectedCategory = 'Pilih Kategori';
  bool _isUploading = false;

  final List<String> _categories = [
    'Pilih Kategori',
    'Fashion',
    'Food & Drink',
    'Home Decor',
    'Travel',
    'DIY & Crafts',
    'Photography',
    'Art',
    'Technology',
    'Sports',
    'Music',
    'Books',
  ];

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih gambar: $e')));
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _linkController.clear();
    _tagController.clear();
    setState(() {
      _selectedCategory = 'Pilih Kategori';
      _selectedImage = null;
    });
  }

  Future<void> _publishPin() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final link = _linkController.text.trim();
    final tag = _tagController.text.trim();
    final category =
        _selectedCategory == 'Pilih Kategori' ? '' : _selectedCategory;

    // Validation
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gambar wajib dipilih'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse('http://192.168.101.7:5000/api/gallery/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['link'] = link;
      request.fields['tag'] = tag;
      request.fields['category'] = category;
      request.fields['userId'] = '6640f38f7758c17c70cefb1d';

      // Add image file
      final imageFile = await http.MultipartFile.fromPath(
        'image',
        _selectedImage!.path,
      );
      request.files.add(imageFile);

      debugPrint('Uploading image: ${_selectedImage!.path}');
      debugPrint('Request fields: ${request.fields}');

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${responseBody.body}');

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(responseBody.body);

        // Get the full image URL from response
        final String? imageUrl = data['fullImageUrl'];
        final String imageId = data['_id'].toString();

        if (imageUrl != null) {
          // Call the callback with all necessary data
          widget.onUploadComplete?.call(
            imageId,
            imageUrl,
            title,
            category,
            tag,
            description,
          );

          // Reset form after successful upload
          _resetForm();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Upload berhasil!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('URL gambar tidak ditemukan dalam response');
        }
      } else {
        final errorData = jsonDecode(responseBody.body);
        throw Exception(
          errorData['error'] ??
              'Upload gagal dengan status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload gagal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Pin'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Remove back button since we're using tabs
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker section
            GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    _selectedImage != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Ketuk untuk mengunggah gambar",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 20),

            // Title field (required)
            TextField(
              controller: _titleController,
              enabled: !_isUploading,
              decoration: const InputDecoration(
                labelText: "Judul *",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                helperText: "Wajib diisi",
              ),
            ),
            const SizedBox(height: 16),

            // Description field
            TextField(
              controller: _descriptionController,
              enabled: !_isUploading,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Deskripsi",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Link field
            TextField(
              controller: _linkController,
              enabled: !_isUploading,
              decoration: const InputDecoration(
                labelText: "Link",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: "https://...",
              ),
            ),
            const SizedBox(height: 16),

            // Category dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: "Kategori",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items:
                  _categories
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
              onChanged:
                  _isUploading
                      ? null
                      : (value) {
                        setState(() => _selectedCategory = value!);
                      },
            ),
            const SizedBox(height: 16),

            // Tag field
            TextField(
              controller: _tagController,
              enabled: !_isUploading,
              decoration: const InputDecoration(
                labelText: "Tag",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                hintText: "Pisahkan dengan koma",
              ),
            ),
            const SizedBox(height: 32),

            // Publish button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _publishPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE60023),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child:
                    _isUploading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          "Publish",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),

            if (_isUploading) ...[
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "Sedang mengupload...",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _tagController.dispose();
    super.dispose();
  }
}
