import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late String _category;

  // Existing images (URLs) still kept by the user
  final List<String> _existingImageUrls = [];
  // Newly-picked images not yet uploaded
  final List<XFile> _newImages = [];
  final List<Uint8List> _newImageBytes = [];

  bool _isSaving = false;
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
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _descriptionController = TextEditingController(
      text: widget.product.description,
    );
    _priceController = TextEditingController(
      text: widget.product.price.toStringAsFixed(2),
    );
    _category = _categories.contains(widget.product.category)
        ? widget.product.category
        : _categories.first;
    _existingImageUrls.addAll(widget.product.imageUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int get _totalImages => _existingImageUrls.length + _newImages.length;

  Future<void> _pickImages() async {
    if (_isPicking) return;
    if (_totalImages >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can have up to $_maxImages photos.')),
      );
      return;
    }

    setState(() => _isPicking = true);
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final remaining = _maxImages - _totalImages;
        final toAdd = images.take(remaining).toList();

        final List<Uint8List> bytesList = [];
        for (final img in toAdd) {
          bytesList.add(await img.readAsBytes());
        }

        setState(() {
          _newImages.addAll(toAdd);
          _newImageBytes.addAll(bytesList);
        });

        if (images.length > remaining) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only $_maxImages photos allowed. Added $remaining.',
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

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[^\w.\-]'), '_');

  Future<Uint8List> _compressImage(Uint8List rawBytes) async {
    if (kIsWeb) return rawBytes;
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      if (compressed.length >= rawBytes.length) return rawBytes;
      return compressed;
    } catch (e) {
      debugPrint('Compression failed: $e');
      return rawBytes;
    }
  }

  /// Uploads new images and returns their public URLs.
  Future<List<String>> _uploadNewImages(String userId) async {
    final supabase = Supabase.instance.client;
    final urls = <String>[];
    for (int i = 0; i < _newImages.length; i++) {
      final img = _newImages[i];
      final bytes = await _compressImage(_newImageBytes[i]);
      final safeName = _sanitizeFileName(img.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final path = '$userId/$fileName';
      await supabase.storage.from('product-images').uploadBinary(path, bytes);
      urls.add(supabase.storage.from('product-images').getPublicUrl(path));
    }
    return urls;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

      // Upload new images (if any)
      final newUrls = await _uploadNewImages(userId);

      // Combine: existing (still kept) + newly uploaded
      final finalImageUrls = [..._existingImageUrls, ...newUrls];

      await productProvider.updateProduct(
        id: widget.product.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        category: _category,
        imageUrls: finalImageUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Listing updated!')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Listing')),
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
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Image picker header
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
                  '$_totalImages/$_maxImages',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Thumbnails: existing (URL) + new (memory)
            if (_totalImages > 0)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _totalImages,
                  itemBuilder: (ctx, i) {
                    // Existing image
                    if (i < _existingImageUrls.length) {
                      return _thumb(
                        child: Image.network(
                          _existingImageUrls[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        onRemove: () =>
                            setState(() => _existingImageUrls.removeAt(i)),
                      );
                    }

                    // Newly picked image
                    final newIndex = i - _existingImageUrls.length;
                    return _thumb(
                      child: Image.memory(
                        _newImageBytes[newIndex],
                        fit: BoxFit.cover,
                      ),
                      onRemove: () => setState(() {
                        _newImages.removeAt(newIndex);
                        _newImageBytes.removeAt(newIndex);
                      }),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Saving...'),
                      ],
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
