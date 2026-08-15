import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OtpService _otpService = OtpService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    required String userType,
    String? webmail,
    String? regNumber,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(fullName);
        await user.sendEmailVerification();

        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': fullName,
          'email': email,
          'userType': userType,
          'webmail': webmail ?? '',
          'regNumber': regNumber ?? '',
          'isAdmin': false,
          'isVerified': false,
          'badgeCount': 0,
          'walletBalance': 0,
          'momoNumber': '',
          'joinedAt': FieldValue.serverTimestamp(),
          'profileImage': '',
        });
      }

      Map<String, dynamic> otpResult = await _otpService.sendOtp(
        userId: user!.uid,
        email: email,
        name: fullName,
      );

      return {
        'success': true,
        'otpSent': otpResult['success'] == true,
        'message': otpResult['success'] == true
            ? 'Account created! Check your email for the verification code.'
            : 'Account created. Verification email could not be delivered yet. Please use Resend Code on the next screen.',
        'userId': user.uid,
        'email': email,
        'name': fullName,
      };
    } on FirebaseAuthException catch (e) {
      String message = _getAuthErrorMessage(e.code);
      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong. Please try again.'
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          final isVerified = data['isVerified'] == true;

          if (!isVerified) {
            await _auth.signOut();
            return {
              'success': false,
              'needVerification': true,
              'userId': user.uid,
              'email': data['email'] ?? email,
              'name': data['fullName'] ?? '',
              'message': 'Please verify your email before logging in.',
            };
          }

          return {
            'success': true,
            'message': 'Login successful',
            'userData': data,
          };
        }
      }

      return {'success': true, 'message': 'Login successful'};
    } on FirebaseAuthException catch (e) {
      String message = _getAuthErrorMessage(e.code);
      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong. Please try again.'
      };
    }
  }

  Future<Map<String, dynamic>> loginAsGuest({required String email}) async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': 'Guest',
          'email': email,
          'userType': 'guest',
          'isAdmin': false,
          'isVerified': false,
          'badgeCount': 0,
          'walletBalance': 0,
          'momoNumber': '',
          'joinedAt': FieldValue.serverTimestamp(),
          'profileImage': '',
        });
      }

      return {'success': true, 'message': 'Continuing as guest'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not continue as guest. Please try again.'
      };
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent. Check your inbox.'
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    }
  }

  Future<Map<String, dynamic>> resendOtp({
    required String userId,
    required String email,
    required String name,
  }) async {
    return await _otpService.resendOtp(
        userId: userId, email: email, name: name);
  }

  Future<bool> isAdmin() async {
    User? user = _auth.currentUser;
    if (user == null) return false;
    DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return data['isAdmin'] == true;
    }
    return false;
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
