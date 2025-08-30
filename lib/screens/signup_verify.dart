import 'package:flutter/material.dart';
import 'package:security_alert/screens/login.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class EmailVerifyScreen extends StatefulWidget {
  final String email;

  const EmailVerifyScreen({super.key, required this.email});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  bool _isResending = false;
  String _message = '';
  bool _isSuccess = false;

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isResending = true;
      _message = '';
      _isSuccess = false;
    });

    try {
      print('🔄 Resending verification email to: ${widget.email}');
      
      final apiService = ApiService();
      final response = await apiService.resendVerificationEmail(widget.email);
      
      setState(() {
        _isResending = false;
        _isSuccess = true;
        _message = 'Verification email sent successfully! Please check your inbox.';
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_message),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      print('❌ Error resending verification email: $e');
      
      setState(() {
        _isResending = false;
        _isSuccess = false;
        _message = 'Failed to resend verification email. Please try again.';
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 32),
              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Check Your Email',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Color(0xFF185ABC),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'We\'ve sent a  link to:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF185ABC),
                ),
              ),
              SizedBox(height: 24),
              // Container(
              //   padding: EdgeInsets.all(16),
              //   decoration: BoxDecoration(
              //     color: Colors.blue.shade50,
              //     borderRadius: BorderRadius.circular(8),
              //     border: Border.all(color: Colors.blue.shade200),
              //   ),
              //   child: Column(
              //     children: [
              //       Row(
              //         children: [
              //           Icon(
              //             Icons.info_outline,
              //             color: Colors.blue.shade600,
              //             size: 20,
              //           ),
              //           SizedBox(width: 8),
              //           Text(
              //             'What to do next:',
              //             style: TextStyle(
              //               fontWeight: FontWeight.w600,
              //               color: Colors.blue.shade800,
              //             ),
              //           ),
              //         ],
              //       ),
              //       SizedBox(height: 12),
              //
              //     ],
              //   ),
              // ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF185ABC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  ),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: _isResending ? null : _resendVerificationEmail,
                child: _isResending
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF185ABC)),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Resending...',
                            style: TextStyle(color: Color(0xFF185ABC)),
                          ),
                        ],
                      )
                    : Text(
                        'Didn\'t receive the email?',
                        style: TextStyle(color: Color(0xFF185ABC)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.blue.shade800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
