import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../../services/post_service.dart';
import '../../utils/constants.dart';
import '../../utils/secrets.dart';

class CreatePostScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userType;

  const CreatePostScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userType,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PostService _postService = PostService();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  String _selectedSport = 'General';
  File? _selectedImage;
  double _uploadProgress = 0.0;
  bool _isUploading = false;

  final List<String> _sports = [
    'General',
    'Football',
    'Volleyball',
    'Athletics',
    'Other',
  ];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _pickImage() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Photo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontLarge,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _selectImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _selectImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Uploads image to Cloudinary using unsigned upload preset
  // Cloudinary accepts a multipart/form-data POST request
  // No authentication needed when using an unsigned preset
  Future<String> _uploadToCloudinary(File imageFile) async {
    // Cloudinary upload URL - uses our cloud name
    final Uri uploadUrl = Uri.parse(
      'https://api.cloudinary.com/v1_1/${AppSecrets.cloudinaryCloudName}/image/upload',
    );

    // MultipartRequest lets us send files over HTTP
    // 'POST' is the HTTP method, uploadUrl is the destination
    final request = http.MultipartRequest('POST', uploadUrl);

    // Add the upload preset - tells Cloudinary which settings to use
    request.fields['upload_preset'] = AppSecrets.cloudinaryUploadPreset;

    // Add the image file to the request
    // MultipartFile.fromPath reads the file from device storage
    // MediaType tells Cloudinary the file type is an image/jpeg
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // Cloudinary expects the field name to be 'file'
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    // Send the request and wait for response
    final streamedResponse = await request.send();

    // ByteStream.toBytes() collects all response bytes
    final responseBytes = await streamedResponse.stream.toBytes();

    // Convert bytes to a String so we can parse it as JSON
    final responseString = utf8.decode(responseBytes);

    // jsonDecode converts the JSON string into a Dart Map
    final responseJson = jsonDecode(responseString);

    print('Cloudinary response: $responseJson');

    if (streamedResponse.statusCode == 200) {
      // 'secure_url' is the HTTPS URL of the uploaded image
      return responseJson['secure_url'];
    } else {
      throw Exception(
        'Cloudinary upload failed: ${responseJson['error']?['message'] ?? responseString}',
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadProgress = 0.0;
    });
  }

  void _submitPost() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something or add a photo'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = _selectedImage != null;
    });

    String imageUrl = '';

    if (_selectedImage != null) {
      try {
        // Show uploading state
        setState(() => _uploadProgress = 0.3);
        imageUrl = await _uploadToCloudinary(_selectedImage!);
        setState(() {
          _uploadProgress = 1.0;
          _isUploading = false;
        });
      } catch (e) {
        print('Upload error: $e');
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image upload failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    Map<String, dynamic> result = await _postService.createPost(
      userId: widget.userId,
      userName: widget.userName,
      userType: widget.userType,
      content: _contentController.text.trim(),
      imageUrl: imageUrl,
      sport: _selectedSport,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? AppColors.accent : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result['success']) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Create Post',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontMedium,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    widget.userName.isNotEmpty
                        ? widget.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Pending approval',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content input
            TextField(
              controller: _contentController,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: "What's happening in JC Sports?",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                counterStyle: TextStyle(color: Colors.grey.shade400),
              ),
              style: const TextStyle(
                fontSize: AppSizes.fontMedium,
                height: 1.5,
              ),
            ),

            // IMAGE PREVIEW
            if (_selectedImage != null) ...[
              const SizedBox(height: 8),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Upload progress overlay
                  if (_isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMedium),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value:
                                  _uploadProgress > 0 ? _uploadProgress : null,
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Uploading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Remove button
                  if (!_isUploading)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],

            const Divider(height: 24),

            // ADD PHOTO BUTTON
            GestureDetector(
              onTap: _isLoading ? null : _pickImage,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedImage != null
                          ? Icons.image
                          : Icons.add_photo_alternate_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedImage != null ? 'Change Photo' : 'Add Photo',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: AppSizes.fontSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sport selector
            const Text(
              'Tag a sport:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontSmall,
              ),
            ),
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sports.map((sport) {
                  final bool isSelected = _selectedSport == sport;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSport = sport),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        sport,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontSize: AppSizes.fontSmall,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Approval notice
            Container(
              padding: const EdgeInsets.all(AppSizes.paddingMedium),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your post will be reviewed by admin before appearing in the feed.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: AppSizes.fontSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
