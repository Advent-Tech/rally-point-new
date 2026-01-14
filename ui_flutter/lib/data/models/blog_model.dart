class BlogModel {
  final String id;
  final String title;
  final String content;
  final String? excerpt;
  final String? imageUrl;
  final String authorId;
  final String? authorName;
  final bool isPublished;
  final int viewCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final BlogAuthor? author;

  BlogModel({
    required this.id,
    required this.title,
    required this.content,
    this.excerpt,
    this.imageUrl,
    required this.authorId,
    this.authorName,
    this.isPublished = true,
    this.viewCount = 0,
    this.createdAt,
    this.updatedAt,
    this.author,
  });

  factory BlogModel.fromJson(Map<String, dynamic> json) {
    return BlogModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      excerpt: json['excerpt']?.toString(),
      imageUrl: json['image_url']?.toString(),
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name']?.toString(),
      isPublished: json['is_published'] as bool? ?? true,
      viewCount: json['view_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      author: json['author'] != null
          ? BlogAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'excerpt': excerpt,
    'image_url': imageUrl,
    'author_id': authorId,
    'author_name': authorName,
    'is_published': isPublished,
    'view_count': viewCount,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'author': author?.toJson(),
  };

  /// Get the display name of the author
  String get displayAuthorName {
    if (author?.displayName != null && author!.displayName.isNotEmpty) {
      return author!.displayName;
    }
    return authorName ?? 'Unknown Author';
  }

  /// Get formatted date
  String get formattedDate {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(createdAt!);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
    }
  }

  /// Get short excerpt for preview
  String get shortExcerpt {
    final text = excerpt ?? content;
    if (text.length <= 100) return text;
    return '${text.substring(0, 100)}...';
  }
}

class BlogAuthor {
  final String id;
  final String displayName;
  final String? email;
  final String? profilePhotoUrl;

  BlogAuthor({
    required this.id,
    required this.displayName,
    this.email,
    this.profilePhotoUrl,
  });

  factory BlogAuthor.fromJson(Map<String, dynamic> json) {
    return BlogAuthor(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      email: json['email']?.toString(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'email': email,
    'profile_photo_url': profilePhotoUrl,
  };
}

class BlogListResponse {
  final List<BlogModel> blogs;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  BlogListResponse({
    required this.blogs,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory BlogListResponse.fromJson(Map<String, dynamic> json) {
    final blogsList = (json['blogs'] as List<dynamic>?)
        ?.map((e) => BlogModel.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return BlogListResponse(
      blogs: blogsList,
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 10,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'blogs': blogs.map((e) => e.toJson()).toList(),
    'total': total,
    'page': page,
    'page_size': pageSize,
    'total_pages': totalPages,
  };

  bool get hasMore => page < totalPages;
}

/// Request to create a new blog
class CreateBlogRequest {
  final String title;
  final String content;
  final String? excerpt;
  final String? imageUrl;
  final bool isPublished;

  CreateBlogRequest({
    required this.title,
    required this.content,
    this.excerpt,
    this.imageUrl,
    this.isPublished = true,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'content': content,
    if (excerpt != null) 'excerpt': excerpt,
    if (imageUrl != null) 'image_url': imageUrl,
    'is_published': isPublished,
  };
}

/// Request to update a blog
class UpdateBlogRequest {
  final String? title;
  final String? content;
  final String? excerpt;
  final String? imageUrl;
  final bool? isPublished;

  UpdateBlogRequest({
    this.title,
    this.content,
    this.excerpt,
    this.imageUrl,
    this.isPublished,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (title != null) map['title'] = title;
    if (content != null) map['content'] = content;
    if (excerpt != null) map['excerpt'] = excerpt;
    if (imageUrl != null) map['image_url'] = imageUrl;
    if (isPublished != null) map['is_published'] = isPublished;
    return map;
  }
}
