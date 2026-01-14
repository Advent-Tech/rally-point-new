import 'package:intl/intl.dart';

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
  });

  factory BlogModel.fromJson(Map<String, dynamic> json) {
    return BlogModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      excerpt: json['excerpt'],
      imageUrl: json['image_url'],
      authorId: json['author_id'] ?? '',
      authorName: json['author_name'],
      isPublished: json['is_published'] ?? true,
      viewCount: json['view_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  String get formattedDate {
    if (createdAt == null) return 'Unknown date';
    return DateFormat('MMM d, yyyy').format(createdAt!);
  }

  String get shortExcerpt {
    if (excerpt != null && excerpt!.isNotEmpty) {
      return excerpt!.length > 150 ? '${excerpt!.substring(0, 150)}...' : excerpt!;
    }
    return content.length > 150 ? '${content.substring(0, 150)}...' : content;
  }

  BlogModel copyWith({
    String? id,
    String? title,
    String? content,
    String? excerpt,
    String? imageUrl,
    String? authorId,
    String? authorName,
    bool? isPublished,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BlogModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      excerpt: excerpt ?? this.excerpt,
      imageUrl: imageUrl ?? this.imageUrl,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      isPublished: isPublished ?? this.isPublished,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
