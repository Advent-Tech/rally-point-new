import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/blog_model.dart';

class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key});

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  List<BlogModel> _blogs = [];
  bool _isLoading = true;
  BlogModel? _selectedBlog;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(
        '${ApiConstants.blogs}?page=1&page_size=100&show_all=true',
      );
      debugPrint('Blog response: ${response.data}');
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['blogs'] ?? [];
        _blogs = (data as List)
            .map((json) => BlogModel.fromJson(json))
            .toList();
        debugPrint('Loaded ${_blogs.length} blogs');
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Failed to load blogs: $e');
    }
  }

  void _showCreateBlogDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final excerptController = TextEditingController();
    String? uploadedImageUrl;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isPublished = true;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: 800,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.article,
                      size: 28,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Blog Post',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Upload Section
                        const Text(
                          'Featured Image',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: selectedImageBytes != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        selectedImageBytes!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            selectedImageBytes = null;
                                            selectedImageName = null;
                                            uploadedImageUrl = null;
                                          });
                                        },
                                      ),
                                    ),
                                    if (isUploading)
                                      Container(
                                        color: Colors.black38,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : InkWell(
                                  onTap: () async {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.image,
                                          allowMultiple: false,
                                          withData: true,
                                        );
                                    if (result != null &&
                                        result.files.isNotEmpty) {
                                      final file = result.files.first;
                                      setDialogState(() {
                                        selectedImageBytes = file.bytes;
                                        selectedImageName = file.name;
                                      });

                                      // Upload image
                                      if (file.bytes != null) {
                                        setDialogState(
                                          () => isUploading = true,
                                        );
                                        try {
                                          final api =
                                              await ApiClient.getInstance();
                                          final formData = {
                                            'image': MultipartFileData(
                                              bytes: file.bytes!,
                                              filename: file.name,
                                            ),
                                          };
                                          final response = await api
                                              .postMultipart(
                                                ApiConstants.blogUploadImage,
                                                formData,
                                              );
                                          if (response.statusCode == 200 ||
                                              response.statusCode == 201) {
                                            uploadedImageUrl =
                                                response.data['url'] ??
                                                response.data['image_url'];
                                          }
                                        } catch (e) {
                                          debugPrint(
                                            'Failed to upload image: $e',
                                          );
                                        }
                                        setDialogState(
                                          () => isUploading = false,
                                        );
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 48,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Click to upload image',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        'Supports: JPG, PNG, GIF, WebP',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            hintText: 'Enter blog post title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Excerpt
                        TextField(
                          controller: excerptController,
                          decoration: const InputDecoration(
                            labelText: 'Excerpt (Optional)',
                            hintText: 'Brief summary of the post',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Content
                        TextField(
                          controller: contentController,
                          decoration: const InputDecoration(
                            labelText: 'Content *',
                            hintText: 'Write your blog post content here...',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 10,
                        ),
                        const SizedBox(height: 16),

                        // Published toggle
                        SwitchListTile(
                          title: const Text('Publish immediately'),
                          subtitle: const Text(
                            'If disabled, post will be saved as draft',
                          ),
                          value: isPublished,
                          onChanged: (v) =>
                              setDialogState(() => isPublished = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isUploading
                          ? null
                          : () {
                              if (titleController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a title'),
                                  ),
                                );
                                return;
                              }
                              if (contentController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter content'),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              _createBlog(
                                title: titleController.text,
                                content: contentController.text,
                                excerpt: excerptController.text.isEmpty
                                    ? null
                                    : excerptController.text,
                                imageUrl: uploadedImageUrl,
                                isPublished: isPublished,
                              );
                            },
                      child: const Text('Create Post'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createBlog({
    required String title,
    required String content,
    String? excerpt,
    String? imageUrl,
    required bool isPublished,
  }) async {
    try {
      final api = await ApiClient.getInstance();
      await api.post(
        '${ApiConstants.blogs}/',
        data: {
          'title': title,
          'content': content,
          if (excerpt != null) 'excerpt': excerpt,
          if (imageUrl != null) 'image_url': imageUrl,
          'is_published': isPublished,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blog post created'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create blog: $e')));
      }
    }
  }

  void _showEditBlogDialog(BlogModel blog) {
    final titleController = TextEditingController(text: blog.title);
    final contentController = TextEditingController(text: blog.content);
    final excerptController = TextEditingController(text: blog.excerpt ?? '');
    String? uploadedImageUrl = blog.imageUrl;
    Uint8List? selectedImageBytes;
    bool isPublished = blog.isPublished;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: 800,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.edit, size: 28, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Blog Post',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Upload Section
                        const Text(
                          'Featured Image',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child:
                              selectedImageBytes != null ||
                                  uploadedImageUrl != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: selectedImageBytes != null
                                          ? Image.memory(
                                              selectedImageBytes!,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(
                                              uploadedImageUrl!,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      size: 48,
                                                    ),
                                                  ),
                                            ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.refresh,
                                              color: Colors.white,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.black54,
                                            ),
                                            onPressed: () async {
                                              final result = await FilePicker
                                                  .platform
                                                  .pickFiles(
                                                    type: FileType.image,
                                                    allowMultiple: false,
                                                    withData: true,
                                                  );
                                              if (result != null &&
                                                  result.files.isNotEmpty) {
                                                final file = result.files.first;
                                                setDialogState(() {
                                                  selectedImageBytes =
                                                      file.bytes;
                                                });

                                                if (file.bytes != null) {
                                                  setDialogState(
                                                    () => isUploading = true,
                                                  );
                                                  try {
                                                    final api =
                                                        await ApiClient.getInstance();
                                                    final formData = {
                                                      'image':
                                                          MultipartFileData(
                                                            bytes: file.bytes!,
                                                            filename: file.name,
                                                          ),
                                                    };
                                                    final response = await api
                                                        .postMultipart(
                                                          ApiConstants
                                                              .blogUploadImage,
                                                          formData,
                                                        );
                                                    if (response.statusCode ==
                                                            200 ||
                                                        response.statusCode ==
                                                            201) {
                                                      uploadedImageUrl =
                                                          response
                                                              .data['url'] ??
                                                          response
                                                              .data['image_url'];
                                                    }
                                                  } catch (e) {
                                                    debugPrint(
                                                      'Failed to upload image: $e',
                                                    );
                                                  }
                                                  setDialogState(
                                                    () => isUploading = false,
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.black54,
                                            ),
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedImageBytes = null;
                                                uploadedImageUrl = null;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isUploading)
                                      Container(
                                        color: Colors.black38,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : InkWell(
                                  onTap: () async {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.image,
                                          allowMultiple: false,
                                          withData: true,
                                        );
                                    if (result != null &&
                                        result.files.isNotEmpty) {
                                      final file = result.files.first;
                                      setDialogState(() {
                                        selectedImageBytes = file.bytes;
                                      });

                                      if (file.bytes != null) {
                                        setDialogState(
                                          () => isUploading = true,
                                        );
                                        try {
                                          final api =
                                              await ApiClient.getInstance();
                                          final formData = {
                                            'image': MultipartFileData(
                                              bytes: file.bytes!,
                                              filename: file.name,
                                            ),
                                          };
                                          final response = await api
                                              .postMultipart(
                                                ApiConstants.blogUploadImage,
                                                formData,
                                              );
                                          if (response.statusCode == 200 ||
                                              response.statusCode == 201) {
                                            uploadedImageUrl =
                                                response.data['url'] ??
                                                response.data['image_url'];
                                          }
                                        } catch (e) {
                                          debugPrint(
                                            'Failed to upload image: $e',
                                          );
                                        }
                                        setDialogState(
                                          () => isUploading = false,
                                        );
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 48,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Click to upload image',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: excerptController,
                          decoration: const InputDecoration(
                            labelText: 'Excerpt (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: contentController,
                          decoration: const InputDecoration(
                            labelText: 'Content *',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 10,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Published'),
                          value: isPublished,
                          onChanged: (v) =>
                              setDialogState(() => isPublished = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isUploading
                          ? null
                          : () {
                              if (titleController.text.isEmpty ||
                                  contentController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Title and content are required',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              _updateBlog(
                                id: blog.id,
                                title: titleController.text,
                                content: contentController.text,
                                excerpt: excerptController.text.isEmpty
                                    ? null
                                    : excerptController.text,
                                imageUrl: uploadedImageUrl,
                                isPublished: isPublished,
                              );
                            },
                      child: const Text('Update Post'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateBlog({
    required String id,
    required String title,
    required String content,
    String? excerpt,
    String? imageUrl,
    required bool isPublished,
  }) async {
    try {
      final api = await ApiClient.getInstance();
      await api.put(
        '${ApiConstants.blogs}/$id',
        data: {
          'title': title,
          'content': content,
          'excerpt': excerpt,
          'image_url': imageUrl,
          'is_published': isPublished,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blog post updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update blog: $e')));
      }
    }
  }

  Future<void> _deleteBlog(BlogModel blog) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Blog Post'),
        content: Text('Are you sure you want to delete "${blog.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiClient.getInstance();
        await api.delete('${ApiConstants.blogs}/${blog.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Blog post deleted'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        if (_selectedBlog?.id == blog.id) {
          setState(() => _selectedBlog = null);
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete blog: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showCreateBlogDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 768;

                // Mobile: Show either list or details
                if (isMobile) {
                  return _selectedBlog == null
                      ? _buildBlogList()
                      : Column(
                          children: [
                            // Back button
                            Container(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => setState(() {
                                      _selectedBlog = null;
                                    }),
                                  ),
                                  const Text(
                                    'Back to Blog Posts',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _BlogPreviewPanel(
                                blog: _selectedBlog!,
                                onEdit: () => _showEditBlogDialog(_selectedBlog!),
                                onDelete: () => _deleteBlog(_selectedBlog!),
                                isMobile: true,
                              ),
                            ),
                          ],
                        );
                }

                // Desktop/Tablet: Side-by-side layout
                return Row(
                  children: [
                    // Blog List (Left Panel)
                    SizedBox(
                      width: constraints.maxWidth < 1024 ? 320 : 400,
                      child: _buildBlogList(),
                    ),

                    // Divider
                    const VerticalDivider(width: 1),

                    // Blog Preview (Right Panel)
                    Expanded(
                      child: _selectedBlog == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.article_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Select a blog post to preview',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _BlogPreviewPanel(
                              blog: _selectedBlog!,
                              onEdit: () => _showEditBlogDialog(_selectedBlog!),
                              onDelete: () => _deleteBlog(_selectedBlog!),
                              isMobile: false,
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildBlogList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Blog Posts (${_blogs.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _blogs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _blogs.length,
                  itemBuilder: (context, index) {
                    final blog = _blogs[index];
                    final isSelected = _selectedBlog?.id == blog.id;
                    return Card(
                      color: isSelected ? AppColors.primary.withAlpha(20) : null,
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: blog.imageUrl != null
                                ? Image.network(
                                    blog.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.primary.withAlpha(30),
                                      child: const Icon(
                                        Icons.article,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.primary.withAlpha(30),
                                    child: const Icon(
                                      Icons.article,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          blog.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blog.formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: blog.isPublished
                                        ? AppColors.success.withAlpha(30)
                                        : Colors.grey.withAlpha(30),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    blog.isPublished ? 'Published' : 'Draft',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: blog.isPublished
                                          ? AppColors.success
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.visibility,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${blog.viewCount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') _showEditBlogDialog(blog);
                            if (value == 'delete') _deleteBlog(blog);
                          },
                        ),
                        onTap: () => setState(() => _selectedBlog = blog),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No blog posts yet',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showCreateBlogDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Post'),
          ),
        ],
      ),
    );
  }
}

class _BlogPreviewPanel extends StatelessWidget {
  final BlogModel blog;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isMobile;

  const _BlogPreviewPanel({
    required this.blog,
    required this.onEdit,
    required this.onDelete,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: Icon(Icons.edit, size: isMobile ? 16 : 18),
                label: Text(isMobile ? 'Edit' : 'Edit'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete,
                  size: isMobile ? 16 : 18,
                  color: AppColors.error,
                ),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Featured Image
          if (blog.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              child: Image.network(
                blog.imageUrl!,
                height: isMobile ? 180 : 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: isMobile ? 180 : 300,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
            ),
          SizedBox(height: isMobile ? 16 : 24),

          // Meta Info - Wrap on mobile
          isMobile
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: blog.isPublished
                            ? AppColors.success.withAlpha(30)
                            : Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        blog.isPublished ? 'Published' : 'Draft',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: blog.isPublished ? AppColors.success : Colors.grey,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          blog.formattedDate,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${blog.viewCount} views',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: blog.isPublished
                            ? AppColors.success.withAlpha(30)
                            : Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        blog.isPublished ? 'Published' : 'Draft',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: blog.isPublished ? AppColors.success : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      blog.formattedDate,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.visibility, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${blog.viewCount} views',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (blog.authorName != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        blog.authorName!,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
          SizedBox(height: isMobile ? 16 : 24),

          // Title
          Text(
            blog.title,
            style: TextStyle(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Excerpt
          if (blog.excerpt != null && blog.excerpt!.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(30)),
              ),
              child: Text(
                blog.excerpt!,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),
          ],

          // Content
          Text(
            blog.content,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
