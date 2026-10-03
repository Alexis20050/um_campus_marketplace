import '../utils/price_validator.dart';

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_service.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';

class PostProductScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;

  const PostProductScreen({super.key, this.onPostSuccess});

  @override
  State<PostProductScreen> createState() => _PostProductScreenState();
}

class _PostProductScreenState extends State<PostProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  final _descriptionController = TextEditingController();

  final _priceController = TextEditingController();

  final _scrollController = ScrollController();

  String _category = 'Books';

  String _itemCondition = 'Good';

  final List<XFile> _selectedImages = [];

  final List<Uint8List> _selectedImageBytes = [];

  bool _isUploading = false;
  bool _isPicking = false;

  int _uploadedCount = 0;

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
  void dispose() {
    _titleController.dispose();

    _descriptionController.dispose();

    _priceController.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // IMAGE PICKING
  // ============================================================

  Future<void> _pickImages({required bool fromCamera}) async {
    if (_isPicking) return;

    if (_selectedImages.length >= _maxImages) {
      _showSnack('You can select up to $_maxImages photos.');

      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final List<XFile> picked = fromCamera
          ? await _pickSingleFromCamera()
          : await _picker.pickMultiImage();

      if (picked.isEmpty) return;

      final remainingSlots = _maxImages - _selectedImages.length;

      final imagesToAdd = picked.take(remainingSlots).toList();

      final List<Uint8List> bytesList = [];

      for (final img in imagesToAdd) {
        bytesList.add(await img.readAsBytes());
      }

      if (!mounted) return;

      setState(() {
        _selectedImages.addAll(imagesToAdd);

        _selectedImageBytes.addAll(bytesList);
      });

      if (picked.length > remainingSlots) {
        _showSnack('Only $_maxImages photos allowed. Added $remainingSlots.');
      }
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

  Future<List<XFile>> _pickSingleFromCamera() async {
    final img = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    return img == null ? <XFile>[] : [img];
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 12),

            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: AppColors.brandOf(context),
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);

                _pickImages(fromCamera: false);
              },
            ),

            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: AppColors.brandOf(context),
              ),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);

                _pickImages(fromCamera: true);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);

      _selectedImageBytes.removeAt(index);
    });
  }

  void _previewImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImage(
          bytes: _selectedImageBytes[index],
          title: _selectedImages[index].name,
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE UPLOAD
  // ============================================================

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }

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

      if (compressed.length >= rawBytes.length) {
        return rawBytes;
      }

      return compressed;
    } catch (e) {
      debugPrint('Image compression failed: $e');

      return rawBytes;
    }
  }

  Future<List<String>> _uploadImages() async {
    final supabase = Supabase.instance.client;

    final List<String> urls = [];

    final images = List<XFile>.of(_selectedImages);

    final imageBytes = List<Uint8List>.of(_selectedImageBytes);

    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('You must be logged in to upload images.');
    }

    for (int i = 0; i < images.length; i++) {
      final img = images[i];

      final bytes = await _compressImage(imageBytes[i]);

      final safeName = _sanitizeFileName(img.name);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final path = '$userId/$fileName';

      await supabase.storage.from('product-images').uploadBinary(path, bytes);

      urls.add(supabase.storage.from('product-images').getPublicUrl(path));

      if (mounted) {
        setState(() {
          _uploadedCount = i + 1;
        });
      }
    }

    return urls;
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isUploading || _isPicking) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
    });

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

      final title = _titleController.text.trim();

      final description = _descriptionController.text.trim();

      final price = double.parse(_priceController.text.trim());

      final sellerName = authService.user?.email ?? 'UM Student';

      final imageUrls = await _uploadImages();

      await productProvider.addProduct(
        sellerId: userId,
        sellerName: sellerName,
        title: title,
        description: description,
        price: price,
        category: _category,
        itemCondition: _itemCondition,
        imageUrls: imageUrls,
      );

      if (!mounted) return;

      _formKey.currentState!.reset();

      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();

      setState(() {
        _selectedImages.clear();

        _selectedImageBytes.clear();

        _category = 'Books';

        _itemCondition = 'Good';
      });

      widget.onPostSuccess?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnack('Error: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadedCount = 0;
        });
      }
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Sell an Item'),
        backgroundColor: isDark ? AppColors.maroonDark : AppColors.maroon,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(
              icon: Icons.photo_camera_outlined,
              title: 'Photos',
              subtitle: 'Up to $_maxImages photos',
            ),

            const SizedBox(height: 8),

            _buildImagePicker(),

            const SizedBox(height: 24),

            const _SectionHeader(
              icon: Icons.info_outline,
              title: 'Item Details',
              subtitle: 'Tell buyers what you\'re selling',
            ),

            const SizedBox(height: 8),

            Card(
              color: AppColors.surfaceOf(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !_isUploading,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g., Calculus Textbook 7th Edition',
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }

                        if (value.trim().length < 3) {
                          return 'Title must be at least 3 characters';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isUploading,
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText:
                            'Age, defects, inclusions, reason for selling...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const _SectionHeader(
              icon: Icons.sell_outlined,
              title: 'Pricing & Details',
              subtitle: 'Set price, category and condition',
            ),

            const SizedBox(height: 8),

            Card(
              color: AppColors.surfaceOf(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _priceController,
                      enabled: !_isUploading,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        hintText: '0.00',
                        prefixText: '₱ ',
                      ),
                      validator: validatePrice,
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      dropdownColor: AppColors.surfaceOf(context),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: _isUploading
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
                      dropdownColor: AppColors.surfaceOf(context),
                      items: _conditions
                          .map(
                            (condition) => DropdownMenuItem(
                              value: condition,
                              child: Text(condition),
                            ),
                          )
                          .toList(),
                      onChanged: _isUploading
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
                      validator: (value) {
                        if (value == null) {
                          return 'Please select the item condition';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOf(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedImages.isEmpty
                                ? 'Posting...'
                                : 'Uploading $_uploadedCount/${_selectedImages.length}...',
                          ),
                        ],
                      )
                    : const Text('Post Item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Card(
      color: AppColors.surfaceOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_selectedImages.isEmpty)
              GestureDetector(
                onTap: _isUploading ? null : _showImageSourceSheet,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAltOf(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 36,
                        color: AppColors.brandOf(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add photos',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount:
                    _selectedImages.length +
                    (_selectedImages.length < _maxImages ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _selectedImages.length) {
                    return InkWell(
                      onTap: _showImageSourceSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAltOf(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.borderOf(context),
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: AppColors.brandOf(context),
                        ),
                      ),
                    );
                  }

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _previewImage(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes[index],
                            fit: BoxFit.cover,
                          ),
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
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 12),

            Text(
              '${_selectedImages.length}/$_maxImages photos',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandSoftOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.brandOf(context)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final Uint8List bytes;
  final String title;

  const _FullScreenImage({required this.bytes, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
