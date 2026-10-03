import '../utils/price_validator.dart';

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';

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

  late String _itemCondition;

  final List<String> _existingImageUrls = [];

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

  final List<String> _conditions = [
    'Brand New',
    'Like New',
    'Good',
    'Fair',
    'For Parts',
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

    _itemCondition = _conditions.contains(widget.product.itemCondition)
        ? widget.product.itemCondition
        : 'Good';

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
    if (_isPicking || _isSaving) {
      return;
    }

    if (_totalImages >= _maxImages) {
      _showSnack('You can have up to $_maxImages photos.');

      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final images = await _picker.pickMultiImage();

      if (images.isEmpty) {
        return;
      }

      final remaining = _maxImages - _totalImages;

      final toAdd = images.take(remaining).toList();

      final List<Uint8List> bytesList = [];

      for (final image in toAdd) {
        bytesList.add(await image.readAsBytes());
      }

      if (!mounted) return;

      setState(() {
        _newImages.addAll(toAdd);

        _newImageBytes.addAll(bytesList);
      });
    } catch (e) {
      _showSnack('Failed to pick images: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }

  Future<Uint8List> _compressImage(Uint8List rawBytes) async {
    if (kIsWeb) {
      return rawBytes;
    }

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 1080,
        minHeight: 1080,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressed.length >= rawBytes.length) {
        return rawBytes;
      }

      return compressed;
    } catch (e) {
      debugPrint('Compression failed: $e');

      return rawBytes;
    }
  }

  Future<List<String>> _uploadNewImages(String userId) async {
    final supabase = Supabase.instance.client;

    final urls = <String>[];

    for (int i = 0; i < _newImages.length; i++) {
      final bytes = await _compressImage(_newImageBytes[i]);

      final safeName = _sanitizeFileName(_newImages[i].name);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final path = '$userId/$fileName';

      await supabase.storage.from('product-images').uploadBinary(path, bytes);

      urls.add(supabase.storage.from('product-images').getPublicUrl(path));
    }

    return urls;
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSaving || _isPicking) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);

      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        throw StateError('You must be signed in.');
      }

      final newUrls = await _uploadNewImages(userId);

      final finalImages = [..._existingImageUrls, ...newUrls];

      await provider.updateProduct(
        id: widget.product.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        category: _category,
        itemCondition: _itemCondition,
        imageUrls: finalImages,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Listing updated!')));

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: const Text('Edit Listing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              enabled: !_isSaving,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: '₱ ',
              ),
              validator: validatePrice,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _category,
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _category = value;
                      });
                    },
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _itemCondition,
              items: _conditions
                  .map(
                    (condition) => DropdownMenuItem(
                      value: condition,
                      child: Text(condition),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _itemCondition = value;
                      });
                    },
              decoration: const InputDecoration(
                labelText: 'Condition',
                prefixIcon: Icon(Icons.verified_outlined),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: (_isPicking || _isSaving) ? null : _pickImages,
                  icon: _isPicking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(_isPicking ? 'Picking...' : 'Add Photos'),
                ),

                const SizedBox(width: 12),

                Text(
                  '$_totalImages/$_maxImages',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_totalImages > 0)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _totalImages,
                  itemBuilder: (context, index) {
                    if (index < _existingImageUrls.length) {
                      return _thumb(
                        context,
                        child: Image.network(
                          _existingImageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surfaceAltOf(context),
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        onRemove: () {
                          setState(() {
                            _existingImageUrls.removeAt(index);
                          });
                        },
                      );
                    }

                    final newIndex = index - _existingImageUrls.length;

                    return _thumb(
                      context,
                      child: Image.memory(
                        _newImageBytes[newIndex],
                        fit: BoxFit.cover,
                      ),
                      onRemove: () {
                        setState(() {
                          _newImages.removeAt(newIndex);

                          _newImageBytes.removeAt(newIndex);
                        });
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 28),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: (_isSaving || _isPicking) ? null : _save,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(
    BuildContext context, {
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderOf(context)),
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
            onTap: _isSaving ? null : onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
