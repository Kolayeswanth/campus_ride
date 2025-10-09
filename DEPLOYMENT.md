# 🚀 Deployment Guide

This guide covers deploying CampusRide to various platforms and environments.

## 📱 Mobile App Deployment

### **Android Deployment**

#### 1. **Debug Build** (Development)
```bash
# Install on connected device/emulator
flutter run

# Build debug APK
flutter build apk --debug
```

#### 2. **Release Build** (Production)
```bash
# Build release APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

#### 3. **Code Signing**
```bash
# Generate keystore (one-time setup)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Update android/key.properties
storePassword=<password from previous step>
keyPassword=<password from previous step>
keyAlias=upload
storeFile=<location of the key store file>
```

### **iOS Deployment**

#### 1. **Prerequisites**
- macOS with Xcode installed
- Apple Developer account
- iOS device or simulator

#### 2. **Build Commands**
```bash
# Debug build
flutter run

# Release build (requires code signing)
flutter build ios --release

# Build for simulator
flutter build ios --simulator
```

#### 3. **App Store Deployment**
```bash
# Archive for App Store
flutter build ipa

# Upload to App Store Connect
# Use Xcode Organizer or Application Loader
```

## 🌐 Backend Deployment

### **Supabase Setup**

#### 1. **Create Project**
```bash
# Install Supabase CLI
npm install -g @supabase/cli

# Login to Supabase
supabase login

# Initialize project
supabase init

# Link to remote project
supabase link --project-ref <your-project-ref>
```

#### 2. **Database Migration**
```sql
-- Run in Supabase SQL Editor
\i docs/sql/schema.sql

-- Apply RLS policies
\i docs/sql/policies.json
```

#### 3. **Environment Configuration**
```bash
# Set environment variables in Supabase dashboard
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### **Database Backup & Recovery**

#### 1. **Backup**
```bash
# Export schema
supabase db dump --schema-only > schema_backup.sql

# Export data
supabase db dump --data-only > data_backup.sql

# Full backup
supabase db dump > full_backup.sql
```

#### 2. **Recovery**
```bash
# Restore from backup
supabase db reset
psql -h db.your-project.supabase.co -U postgres -d postgres < full_backup.sql
```

## 🔧 CI/CD Pipeline

### **GitHub Actions**

The repository includes automated CI/CD pipeline (`.github/workflows/ci-cd.yml`):

#### 1. **Required Secrets**
Set these in GitHub repository settings → Secrets:

```
SUPABASE_URL
SUPABASE_ANON_KEY
OLA_MAPS_API_KEY
LOCATIONIQ_API_KEY
OPENROUTESERVICE_API_KEY
MAPTILER_API_KEY
MAPLIBRE_STYLE_URL
```

#### 2. **Pipeline Stages**
- **Analyze**: Code analysis and formatting checks
- **Test**: Unit and integration tests
- **Build**: Android APK and iOS builds
- **Deploy**: Automated deployment (if configured)

### **Manual Deployment**

#### 1. **Pre-deployment Checklist**
```bash
# Code quality checks
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test

# Build verification
flutter build apk --release
flutter build ios --release --no-codesign
```

#### 2. **Environment Setup**
```bash
# Copy environment template
cp .env.example .env

# Configure API keys
nano .env

# Verify configuration
flutter run --dart-define-from-file=.env
```

## 📊 Monitoring & Analytics

### **Error Tracking**

#### 1. **Firebase Crashlytics** (Optional)
```dart
// Add to pubspec.yaml
dependencies:
  firebase_crashlytics: ^3.4.8

// Initialize in main.dart
await Firebase.initializeApp();
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
```

#### 2. **Sentry Integration** (Optional)
```dart
// Add to pubspec.yaml
dependencies:
  sentry_flutter: ^7.13.2

// Initialize
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) => options.dsn = 'YOUR_SENTRY_DSN',
  appRunner: () => runApp(MyApp()),
);
```

### **Performance Monitoring**

#### 1. **Flutter Performance**
```bash
# Profile build
flutter build apk --profile
flutter run --profile

# Performance overlay
flutter run --dart-define=flutter.inspector.structuredErrors=true
```

#### 2. **Database Performance**
```sql
-- Monitor slow queries in Supabase
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

## 🔒 Security Considerations

### **Production Security**

#### 1. **API Key Management**
```bash
# Never commit these files
.env
*.key
*.p8
*.p12
*.jks
*.keystore
```

#### 2. **Network Security**
```dart
// Enable certificate pinning
class NetworkConfig {
  static final dio = Dio()
    ..interceptors.add(CertificatePinningInterceptor(
      allowedSHAFingerprints: ['SHA256:...']
    ));
}
```

#### 3. **Data Encryption**
```sql
-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_trips ENABLE ROW LEVEL SECURITY;
```

### **Compliance**

#### 1. **GDPR Compliance**
```dart
// Data retention policies
class DataRetentionService {
  static Future<void> cleanupOldData() async {
    // Remove location data older than 30 days
    await supabase.from('driver_trip_locations')
      .delete()
      .lt('created_at', DateTime.now().subtract(Duration(days: 30)));
  }
}
```

#### 2. **Privacy Controls**
```dart
// User consent management
class ConsentManager {
  static Future<bool> requestLocationConsent() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => LocationConsentDialog(),
    ) ?? false;
  }
}
```

## 📈 Scaling Considerations

### **Database Scaling**

#### 1. **Read Replicas**
```sql
-- Configure read replicas in Supabase dashboard
-- Route read-only queries to replicas
```

#### 2. **Connection Pooling**
```dart
// Configure connection limits
class DatabaseConfig {
  static const int maxConnections = 20;
  static const Duration connectionTimeout = Duration(seconds: 30);
}
```

### **Performance Optimization**

#### 1. **Image Optimization**
```bash
# Optimize app icons and images
flutter packages pub run flutter_launcher_icons:main
```

#### 2. **Bundle Size Optimization**
```bash
# Analyze bundle size
flutter build apk --analyze-size

# Enable obfuscation
flutter build apk --obfuscate --split-debug-info=debug-info/
```

## 🚨 Troubleshooting

### **Common Issues**

#### 1. **Build Failures**
```bash
# Clean build
flutter clean
flutter pub get
flutter build apk

# Gradle issues
cd android && ./gradlew clean
cd .. && flutter build apk
```

#### 2. **Permission Issues**
```bash
# Android permissions
adb shell pm grant com.campusride.campus_ride android.permission.ACCESS_FINE_LOCATION

# iOS permissions - check Info.plist
```

#### 3. **API Issues**
```bash
# Test API connectivity
curl -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
     "$SUPABASE_URL/rest/v1/bus_routes"
```

### **Debugging Tools**

#### 1. **Flutter Inspector**
```bash
flutter run --debug
# Open Flutter Inspector in IDE
```

#### 2. **Network Debugging**
```dart
// Add logging interceptor
dio.interceptors.add(LogInterceptor(
  requestBody: true,
  responseBody: true,
));
```

## 📞 Support

For deployment issues:
- Check [GitHub Issues](https://github.com/yourusername/campus_ride/issues)
- Review [Wiki Documentation](https://github.com/yourusername/campus_ride/wiki)
- Contact: deployment@campusride.app

---

**Remember**: Always test thoroughly in staging environment before production deployment! 🧪