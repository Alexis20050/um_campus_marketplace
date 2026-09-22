import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_service.dart';
import '../providers/product_provider.dart';

// UM brand colors
const Color _kMaroon = Color(0xFF800000);
const Color _kGold = Color(0xFFD4AF37);

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
  final _scrollController = ScrollController();

  String _category = 'Books';

  final List<XFile> _selectedImages = [];
  final List<Uint8List> _selectedImageBytes = [];

  bool _isUploading = false;
  bool _isPicking = false;
  int _uploadedCount = 0; // for progress display
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

    setState(() => _isPicking = true);
    try {
      final List<XFile> images = fromCamera
          ? [
              if (await _picker.pickImage(source: ImageSource.camera) != null)
                (await _picker.pickImage(source: ImageSource.camera))!,
            ]
          : await _picker.pickMultiImage();

      // The camera branch above re-picks; simplify by using a single
      // helper that returns a list for both paths.
      final List<XFile> picked = fromCamera
          ? await _pickSingleFromCamera()
          : images;

      if (picked.isEmpty) return;

      final remainingSlots = _maxImages - _selectedImages.length;
      final imagesToAdd = picked.take(remainingSlots).toList();

      final List<Uint8List> bytesList = [];
      for (var img in imagesToAdd) {
        bytesList.add(await img.readAsBytes());
      }

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
      if (mounted) setState(() => _isPicking = false);
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _kMaroon),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _kMaroon),
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
  // UPLOAD LOGIC
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

      if (compressed.length >= rawBytes.length) return rawBytes;
      return compressed;
    } catch (e) {
      debugPrint('Image compression failed, using original: $e');
      return rawBytes;
    }
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
      final rawBytes = _selectedImageBytes[i];
      final bytes = await _compressImage(rawBytes);

      final safeName = _sanitizeFileName(img.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final path = '$userId/$fileName';

      await supabase.storage.from('product-images').uploadBinary(path, bytes);
      final url = supabase.storage.from('product-images').getPublicUrl(path);
      urls.add(url);

      // Update progress counter for the UI.
      if (mounted) setState(() => _uploadedCount = i + 1);
    }
    return urls;
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploading) return;

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

      final imageUrls = await _uploadImages();
      await productProvider.addProduct(
        sellerId: userId,
        sellerName: authService.user?.email ?? 'UM Student',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadedCount = 0;
        });
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Sell an Item'),
        backgroundColor: _kMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- Photo section ----------
            _SectionHeader(
              icon: Icons.photo_camera_outlined,
              title: 'Photos',
              subtitle: 'Up to $_maxImages photos',
            ),
            const SizedBox(height: 8),
            _buildImagePicker(),
            const SizedBox(height: 24),

            // ---------- Item details ----------
            _SectionHeader(
              icon: Icons.info_outline,
              title: 'Item Details',
              subtitle: 'Tell buyers what you\'re selling',
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        if (v.trim().length < 3) {
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
                            'Condition, age, reason for selling, meet-up spot...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ---------- Pricing & category ----------
            _SectionHeader(
              icon: Icons.sell_outlined,
              title: 'Pricing & Category',
              subtitle: 'Help buyers find your listing',
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter a price';
                        }
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Enter a valid number';
                        if (parsed <= 0) {
                          return 'Price must be greater than 0';
                        }
                        if (parsed > 1000000) {
                          return 'Price seems too high';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: _categories
                          .map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          )
                          .toList(),
                      onChanged: _isUploading
                          ? null
                          : (val) => setState(() => _category = val!),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ---------- Submit ----------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kMaroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                            width: 20,
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image grid
            if (_selectedImages.isEmpty)
              GestureDetector(
                onTap: _isUploading ? null : _showImageSourceSheet,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 36,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add photos',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PNG or JPG, up to $_maxImages',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                itemBuilder: (ctx, i) {
                  // Last tile = "+ Add" button
                  if (i == _selectedImages.length) {
                    return GestureDetector(
                      onTap: _isUploading ? null : _showImageSourceSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.grey[600],
                          size: 32,
                        ),
                      ),
                    );
                  }

                  // Image tile
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _previewImage(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _isUploading ? null : () => _removeImage(i),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${_selectedImages.length}/$_maxImages · tap an image to preview',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HELPER WIDGETS
// ============================================================

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
        Icon(icon, size: 20, color: _kMaroon),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
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
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
