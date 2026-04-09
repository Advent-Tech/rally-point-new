import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? token;

  const VerifyEmailScreen({super.key, this.token});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _verifyEmail();
  }

  Future<void> _verifyEmail() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = 'Invalid verification link. No token provided.';
      });
      return;
    }

    try {
      final apiClient = await ApiClient.getInstance();
      final response = await apiClient.post(
        '/api/auth/verify-email',
        data: {'token': widget.token},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _message = data['message'] ?? 'Email verified successfully!';
        });
      } else {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _message = 'Verification failed. Please try again.';
        });
      }
    } on DioException catch (e) {
      String errorMessage = 'Verification failed.';
      if (e.response?.data is Map) {
        errorMessage = e.response?.data['error'] ?? errorMessage;
      }
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = errorMessage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _message = 'An unexpected error occurred.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _isLoading
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 24),
                        Text(
                          'Verifying your email...',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle : Icons.error,
                          size: 80,
                          color: _isSuccess ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isSuccess ? 'Email Verified!' : 'Verification Failed',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_isSuccess) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Your email has been verified. Please wait for admin approval before you can login.',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        const Text(
                          'You can close this window.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
