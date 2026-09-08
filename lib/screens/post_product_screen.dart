import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';

class PostProductScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;
  const PostProductScreen({super.key, this.onPostSuccess});

  @override
  _PostProductScreenState createState() => _PostProductScreenState();
}

class _PostProductScreenState extends State<PostProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _category = 'Books';

  final List<XFile> _selectedImages = [];
  final List<Uint8List> _selectedImageBytes = []; // For web preview

  bool _isUploading = false;
  bool _isPicking = false;
  static const int _maxImages = 5;

  final List<String> _categories = [
    'Books',
    'Electronics',
    'Furniture',
    'Clothing',
    'School Supplies',
    'Services',
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isPicking) return;
    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can select up to $_maxImages photos.')),
      );
      return;
    }

    setState(() => _isPicking = true);
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final remainingSlots = _maxImages - _selectedImages.length;
        final imagesToAdd = images.take(remainingSlots).toList();

        // Read bytes for preview and upload (web + mobile)
        final List<Uint8List> bytesList = [];
        for (var img in imagesToAdd) {
          final bytes = await img.readAsBytes();
          bytesList.add(bytes);
        }

        setState(() {
          _selectedImages.addAll(imagesToAdd);
          _selectedImageBytes.addAll(bytesList);
        });

        if (images.length > remainingSlots) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only $_maxImages photos allowed. Added $remainingSlots.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }

  Future<List<String>> _uploadImages() async {
    final supabase = Supabase.instance.client;
    final List<String> urls = [];
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be logged in to upload images.');
    }

    for (int i = 0; i < _selectedImages.length; i++) {
      final img = _selectedImages[i];
      final bytes = _selectedImageBytes[i];
      final safeName = _sanitizeFileName(img.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final path = '$userId/$fileName';
      await supabase.storage.from('product-images').uploadBinary(path, bytes);
      final url = supabase.storage.from('product-images').getPublicUrl(path);
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      final userId = authService.user?.id;
      if (userId == null) {
        throw Exception('You must be logged in to post.');
      }

      final imageUrls = await _uploadImages();
      await productProvider.addProduct(
        sellerId: userId,
        sellerName: authService.user?.email ?? 'UM Student',
        title: _titleController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        category: _category,
        imageUrls: imageUrls,
      );

      // Reset form
      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      setState(() {
        _selectedImages.clear();
        _selectedImageBytes.clear();
        _category = 'Books';
      });

      widget.onPostSuccess?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product posted successfully!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell an Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Calculus Textbook 7th Edition',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the item, condition, etc.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price (₱)',
                hintText: '0.00',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter price';
                final parsed = double.tryParse(v);
                if (parsed == null) return 'Enter a valid number';
                if (parsed <= 0) return 'Price must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _category = val!),
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isPicking ? null : _pickImages,
                  icon: _isPicking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library),
                  label: Text(_isPicking ? 'Picking...' : 'Add Photos'),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_selectedImages.length}/$_maxImages selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (ctx, i) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedImageBytes[i],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(i);
                                _selectedImageBytes.removeAt(i);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
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
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: _isUploading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Posting...'),
                      ],
                    )
                  : const Text('Post Item'),
            ),
          ],
        ),
      ),
    );
  }
}
