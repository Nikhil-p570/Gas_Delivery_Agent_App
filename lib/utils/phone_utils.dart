import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class PhoneUtils {
  static Future<void> callCustomer(String phoneNumber, BuildContext context) async {
    if (phoneNumber.isEmpty || phoneNumber == 'Not available') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // Clean phone number (remove +91 or spaces)
    String cleanNumber = phoneNumber.replaceAll('+91', '').replaceAll(' ', '').trim();
    
    // Check if it's a valid Indian number
    if (cleanNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number format'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // Format with country code
    final phoneUrl = 'tel:+91$cleanNumber';

    if (await canLaunchUrl(Uri.parse(phoneUrl))) {
      await launchUrl(Uri.parse(phoneUrl));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open dialer'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}