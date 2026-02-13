import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  String? verificationId;
  bool otpSent = false;
  bool showNameField = false;
  String error = '';
  bool loading = false;
  bool checkingAuthorization = false;

  @override
  void initState() {
    super.initState();
    resetState();
  }

  void resetState() {
    otpSent = false;
    showNameField = false;
    error = '';
    phoneCtrl.clear();
    otpCtrl.clear();
    nameCtrl.clear();
    verificationId = null;
    loading = false;
    checkingAuthorization = false;
  }

  Future<bool> isDeliveryAgentAuthorized(String phoneNumber) async {
    try {
      final formattedPhone = phoneNumber.startsWith('+91') 
          ? phoneNumber 
          : '+91$phoneNumber';
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('authorized_agents')
          .where('phone', isEqualTo: formattedPhone)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Authorization check error: $e');
      return false;
    }
  }

  Future<bool> doesAgentExistInDeliveryAgents(String phoneNumber) async {
    try {
      final formattedPhone = phoneNumber.startsWith('+91') 
          ? phoneNumber 
          : '+91$phoneNumber';
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('delivery_agents')
          .where('phone', isEqualTo: formattedPhone)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Delivery agent existence check error: $e');
      return false;
    }
  }

  Future<String?> getExistingAgentDocId(String phoneNumber) async {
    try {
      final formattedPhone = phoneNumber.startsWith('+91') 
          ? phoneNumber 
          : '+91$phoneNumber';
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('delivery_agents')
          .where('phone', isEqualTo: formattedPhone)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      print('Get existing agent ID error: $e');
      return null;
    }
  }

  Future<void> checkIfNameRequired(String phoneNumber) async {
    setState(() => loading = true);
    
    try {
      final agentExists = await doesAgentExistInDeliveryAgents(phoneNumber);
      
      setState(() {
        showNameField = !agentExists;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error checking agent status';
        loading = false;
      });
    }
  }

  Future<void> sendOtp() async {
    setState(() {
      error = '';
      showNameField = false;
      nameCtrl.clear();
    });
    
    final phoneNumber = phoneCtrl.text.trim();
    
    if (phoneNumber.isEmpty || phoneNumber.length < 10) {
      setState(() => error = 'Please enter a valid phone number');
      return;
    }

    setState(() => checkingAuthorization = true);
    
    try {
      final isAuthorized = await isDeliveryAgentAuthorized(phoneNumber);
      
      if (!isAuthorized) {
        setState(() {
          error = 'Your number isn\'t enabled for delivery access yet.\nPlease reach out to the admin to get access.';
          checkingAuthorization = false;
        });
        return;
      }
      
      setState(() {
        checkingAuthorization = false;
        loading = true;
      });
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${phoneCtrl.text}',
        verificationCompleted: (cred) async {
          await FirebaseAuth.instance.signInWithCredential(cred);
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() {
              error = e.message ?? 'Error sending OTP';
              loading = false;
            });
          }
        },
        codeSent: (vid, _) {
          checkIfNameRequired(phoneNumber).then((_) {
            if (mounted) {
              setState(() {
                verificationId = vid;
                otpSent = true;
              });
            }
          });
        },
        codeAutoRetrievalTimeout: (_) {
          if (mounted) {
            setState(() => loading = false);
          }
        },
      );
    } catch (e) {
      setState(() {
        error = 'An error occurred. Please try again.';
        loading = false;
        checkingAuthorization = false;
      });
    }
  }

  Future<void> verifyOtp() async {
    setState(() {
      loading = true;
      error = '';
    });
    
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpCtrl.text,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);

      final phoneNumber = phoneCtrl.text.trim();
      final isAuthorized = await isDeliveryAgentAuthorized(phoneNumber);
      
      if (!isAuthorized) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            error = 'Your number isn\'t enabled for delivery access yet.\nPlease reach out to the admin to get access.';
            loading = false;
            otpSent = false;
            otpCtrl.clear();
            nameCtrl.clear();
          });
        }
        return;
      }

      final formattedPhone = '+91$phoneNumber';
      final agentExists = await doesAgentExistInDeliveryAgents(phoneNumber);
      
      if (agentExists) {
        final existingAgentDocId = await getExistingAgentDocId(phoneNumber);
        
        if (existingAgentDocId != null) {
          await FirebaseFirestore.instance
              .collection('delivery_agents')
              .doc(existingAgentDocId)
              .update({
            'lastLogin': Timestamp.now(),
            'isVerified': true,
            'verifiedAt': Timestamp.now(),
          });
        }
      } else {
        final agentName = nameCtrl.text.trim();
        
        if (agentName.isEmpty) {
          setState(() {
            error = 'Please enter your name';
            loading = false;
          });
          return;
        }
        
        await FirebaseFirestore.instance
            .collection('delivery_agents')
            .doc(userCred.user!.uid)
            .set({
          'phone': formattedPhone,
          'name': agentName,
          'isOnline': false,
          'isVerified': true,
          'verifiedAt': Timestamp.now(),
          'createdAt': Timestamp.now(),
          'lastLogin': Timestamp.now(),
          'cylindersDeliveredToday': 0,
          'earnings': 0,
        });
      }
      
      otpCtrl.clear();
      nameCtrl.clear();
      
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Invalid OTP. Please try again.';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData) {
          return const DashboardScreen();
        }
        
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1A237E),
                  Color(0xFF3949AB),
                  Color(0xFFC62828),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            size: 48,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Delivery Agent",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        if (!otpSent) ...[
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            enabled: !checkingAuthorization && !loading,
                            decoration: InputDecoration(
                              labelText: "Phone Number",
                              hintText: "9876543210",
                              prefixText: "+91 ",
                              prefixStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              prefixIcon: const Icon(Icons.phone_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            enabled: !loading,
                            decoration: InputDecoration(
                              labelText: "Enter OTP",
                              hintText: "000000",
                              prefixIcon: const Icon(Icons.lock_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          
                          if (showNameField) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: nameCtrl,
                              enabled: !loading,
                              decoration: InputDecoration(
                                labelText: "Your Name",
                                hintText: "Enter your full name",
                                prefixIcon: const Icon(Icons.person_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "This is your first login. Please enter your name.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                        
                        if (error.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      color: Colors.red.shade700, 
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: _buildActionButton(),
                        ),
                        
                        if (otpSent) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: loading ? null : () {
                              setState(() {
                                otpSent = false;
                                showNameField = false;
                                otpCtrl.clear();
                                nameCtrl.clear();
                                error = '';
                              });
                            },
                            child: const Text("Change Phone Number"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton() {
    if (checkingAuthorization) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3949AB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(
              "Checking Authorization...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return ElevatedButton(
      onPressed: loading ? null : (otpSent ? verifyOtp : sendOtp),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              otpSent ? "Verify OTP" : "Send OTP",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  @override
  void dispose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }
}
