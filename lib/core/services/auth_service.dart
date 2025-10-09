import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  User? _currentUser;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  bool _needsProfileCompletion = false;

  User? get currentUser => _currentUser;
  UserProfile? get userProfile => _userProfile;
  String? get userRole => _userProfile?.role;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get needsProfileCompletion => _needsProfileCompletion;

  AuthService() {
    _initialize();
  }

  void _initialize() {
    _currentUser = _supabase.auth.currentUser;
    if (_currentUser != null) {
      _loadUserProfile();
    }
    
    _supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      if (_currentUser != null) {
        _loadUserProfile();
      } else {
        _userProfile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;
    
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', _currentUser!.id)
          .single();
      
      _userProfile = UserProfile.fromJson(response);
      _needsProfileCompletion = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user profile: $e');
      }
      
      // Check if this is a confirmed user who needs profile creation
      if (_currentUser!.emailConfirmedAt != null) {
        if (kDebugMode) {
          print('Email confirmed, checking for pending profile data...');
        }
        await _checkAndCreateProfileFromPendingData();
        
        // If still no profile after checking pending data, create a basic profile
        // This is a fallback for users whose metadata wasn't stored properly
        if (_userProfile == null) {
          if (kDebugMode) {
            print('No profile found and no pending data. Creating fallback profile.');
          }
          
          // Set a flag to indicate the user needs to complete their profile
          _needsProfileCompletion = true;
          notifyListeners();
        }
      } else {
        if (kDebugMode) {
          print('Email not confirmed yet. Profile will be created after email verification.');
        }
      }
    }
  }

  /// Store registration data temporarily until email is confirmed
  Future<void> _storeRegistrationData(String userId, String name, String collegeId) async {
    try {
      if (kDebugMode) {
        print('Storing registration data for user: $userId');
        print('Name: $name, College ID: $collegeId');
      }
      
      // Store in user metadata
      final result = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'pending_profile': {
              'display_name': name,
              'college_id': collegeId,
              'role': 'passenger',
            }
          },
        ),
      );
      
      if (kDebugMode) {
        print('Registration data storage result: ${result.user?.userMetadata}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to store registration data: $e');
      }
      // Don't throw here to avoid breaking the registration flow
    }
  }

  /// Check if user has pending profile data and create profile after email confirmation
  Future<void> _checkAndCreateProfileFromPendingData() async {
    if (kDebugMode) {
      print('Checking for pending profile data...');
      print('User metadata: ${_currentUser?.userMetadata}');
    }
    
    if (_currentUser?.userMetadata?['pending_profile'] != null) {
      final pendingData = _currentUser!.userMetadata!['pending_profile'] as Map<String, dynamic>;
      
      if (kDebugMode) {
        print('Found pending profile data: $pendingData');
      }
      
      try {
        await createProfile(
          pendingData['display_name'] as String,
          pendingData['college_id'] as String,
        );
        
        // Clear pending data after successful profile creation
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {'pending_profile': null},
          ),
        );
        
        if (kDebugMode) {
          print('Profile created successfully after email confirmation');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to create profile from pending data: $e');
        }
        rethrow; // Re-throw to handle in calling method
      }
    } else {
      if (kDebugMode) {
        print('No pending profile data found in user metadata');
      }
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccessMessage(String message) {
    _successMessage = message;
    _error = null;
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Load user profile - this will create profile from pending data if needed
        await _loadUserProfile();
        _setSuccessMessage('Successfully signed in');
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> registerWithEmail(String email, String password, String name) async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Create profile
        await createProfile(name, 'default-college-id');
        _setSuccessMessage('Account created successfully');
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> registerWithEmailAndCollege(String email, String password, String name, String collegeId) async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        if (kDebugMode) {
          print('User registered successfully: ${response.user!.id}');
          print('Email confirmed at: ${response.user!.emailConfirmedAt}');
        }
        
        // Store registration data for later profile creation after email confirmation
        await _storeRegistrationData(response.user!.id, name, collegeId);
        
        if (response.user!.emailConfirmedAt == null) {
          // Email confirmation required
          _setSuccessMessage('Please confirm your email and login');
        } else {
          // Email already confirmed (shouldn't happen in signup but just in case)
          await createProfile(name, collegeId);
          _setSuccessMessage('Account created successfully');
        }
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createProfile(String displayName, String collegeId, {String? phone, String? photoUrl}) async {
    if (_currentUser == null) return;
    
    try {
      final profileData = {
        'id': _currentUser!.id,
        'email': _currentUser!.email!, // Add email field as required by schema
        'role': 'passenger',
        'display_name': displayName,
        'phone_number': phone,
        'avatar_url': photoUrl,
        'college_id': collegeId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (kDebugMode) {
        print('Creating profile with data: $profileData');
      }
      
      final result = await _supabase.from('user_profiles').insert(profileData).select();
      
      if (kDebugMode) {
        print('Profile creation result: $result');
      }
      
      // Reset the profile completion flag
      _needsProfileCompletion = false;
      
      await _loadUserProfile();
    } catch (e) {
      if (kDebugMode) {
        print('Profile creation error: $e');
      }
      throw Exception('Failed to create profile: $e');
    }
  }

  Future<void> updateUserRole(String role) async {
    if (_currentUser == null) return;
    
    try {
      await _supabase
          .from('user_profiles')
          .update({'role': role, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', _currentUser!.id);
      
      await _loadUserProfile();
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  Future<void> completeProfile(String displayName, String collegeId) async {
    if (_currentUser == null) return;
    
    try {
      await createProfile(displayName, collegeId);
      _needsProfileCompletion = false;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to complete profile: $e');
    }
  }

  Future<void> selectCollege(String collegeId) async {
    if (_currentUser == null) return;
    
    try {
      await _supabase
          .from('user_profiles')
          .update({'college_id': collegeId, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', _currentUser!.id);
      
      await _loadUserProfile();
    } catch (e) {
      throw Exception('Failed to update college: $e');
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      _setError('Failed to send reset email');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _userProfile = null;
      _error = null;
      _successMessage = null;
    } catch (e) {
      _setError('Failed to sign out');
    }
  }

  Future<void> submitDriverRequest(Map<String, dynamic> requestData) async {
    if (_currentUser == null) return;
    
    try {
      final data = {
        ...requestData,
        'user_id': _currentUser!.id,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await _supabase.from('driver_requests').insert(data);
      _setSuccessMessage('Driver request submitted successfully');
    } catch (e) {
      _setError('Failed to submit driver request: $e');
    }
  }

  Future<bool> hasPendingDriverRequest() async {
    if (_currentUser == null) return false;
    
    try {
      final response = await _supabase
          .from('driver_requests')
          .select('id')
          .eq('user_id', _currentUser!.id)
          .eq('status', 'pending')
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getDriverRequestStatus() async {
    if (_currentUser == null) return null;
    
    try {
      final response = await _supabase
          .from('driver_requests')
          .select('status')
          .eq('user_id', _currentUser!.id)
          .order('created_at', ascending: false)
          .maybeSingle();
      
      return response?['status'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllDriverRequests() async {
    try {
      final response = await _supabase
          .from('driver_requests')
          .select('*, user_profiles!inner(display_name, phone_number)')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> handleDriverRequest(String requestId, String action) async {
    try {
      await _supabase
          .from('driver_requests')
          .update({
            'status': action,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      if (action == 'approved') {
        // Update user role to driver
        final request = await _supabase
            .from('driver_requests')
            .select('user_id')
            .eq('id', requestId)
            .single();
        
        await _supabase
            .from('user_profiles')
            .update({'role': 'driver', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', request['user_id']);
      }
      
      _setSuccessMessage('Driver request $action successfully');
    } catch (e) {
      _setError('Failed to handle driver request: $e');
    }
  }

  Future<void> testDatabaseAccess() async {
    try {
      await _supabase.from('user_profiles').select('id').limit(1);
      _setSuccessMessage('Database connection successful');
    } catch (e) {
      _setError('Database connection failed: $e');
    }
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }
}
