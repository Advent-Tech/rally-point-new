import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/blog_model.dart';

class BlogRepository {
  final ApiClient _apiClient;

  BlogRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Get list of blogs with pagination
  Future<BlogListResponse> getBlogs({int page = 1, int pageSize = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.blogs,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      return BlogListResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting blogs: $e');
      rethrow;
    }
  }

  /// Get a single blog by ID
  Future<BlogModel> getBlog(String id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConstants.blogs}/$id');
      return BlogModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting blog: $e');
      rethrow;
    }
  }

  /// Create a new blog (admin only)
  Future<BlogModel> createBlog(CreateBlogRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.blogs,
        data: request.toJson(),
      );
      return BlogModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error creating blog: $e');
      rethrow;
    }
  }

  /// Update a blog (admin only)
  Future<BlogModel> updateBlog(String id, UpdateBlogRequest request) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiConstants.blogs}/$id',
        data: request.toJson(),
      );
      return BlogModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error updating blog: $e');
      rethrow;
    }
  }

  /// Delete a blog (admin only)
  Future<void> deleteBlog(String id) async {
    try {
      await _apiClient.dio.delete('${ApiConstants.blogs}/$id');
    } catch (e) {
      debugPrint('Error deleting blog: $e');
      rethrow;
    }
  }

  /// Upload an image for a blog
  Future<String> uploadImage(String blogId, List<int> imageData, String filename) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(imageData, filename: filename),
      });

      final response = await _apiClient.dio.post(
        '${ApiConstants.blogs}/$blogId/image',
        data: formData,
      );

      return response.data['image_url'] as String;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  /// Upload an image directly (for new blogs)
  Future<String> uploadImageDirect(List<int> imageData, String filename) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(imageData, filename: filename),
      });

      final response = await _apiClient.dio.post(
        '${ApiConstants.blogs}/upload-image',
        data: formData,
      );

      return response.data['image_url'] as String;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }
}
