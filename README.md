# 🚌 CampusRide - Smart Campus Transportation System

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-green.svg)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📱 Overview

CampusRide is a comprehensive campus transportation management system built with Flutter and Supabase. It provides real-time bus tracking, route management, and seamless communication between drivers, passengers, and administrators.

### ✨ Key Features

#### 🚍 **For Drivers**
- **Real-time GPS Tracking** - Continuous location sharing even when app is closed
- **Background Location Service** - Persistent notifications and location updates
- **Interactive Navigation** - Turn-by-turn directions with route optimization
- **Trip Management** - Start, pause, resume, and end trips with one tap
- **Route Assignment** - Automatic route assignment and management
- **Passenger Communication** - Real-time passenger count and feedback

#### 👥 **For Passengers**
- **Live Bus Tracking** - Real-time bus location on interactive map
- **Route Information** - Detailed route schedules and stop information
- **ETA Predictions** - Accurate arrival time estimates
- **Favorite Routes** - Quick access to frequently used routes
- **Push Notifications** - Bus arrival alerts and service updates
- **Offline Support** - Basic functionality without internet connection

#### 🏫 **For Administrators**
- **Fleet Management** - Complete oversight of all buses and routes
- **Driver Management** - Driver assignment and performance monitoring
- **Route Optimization** - AI-powered route planning and optimization
- **Analytics Dashboard** - Comprehensive insights and reporting
- **User Management** - Student and staff account management
- **System Configuration** - College-specific settings and customization

## 🏗️ Architecture

### **Backend Stack**
- **Supabase** - PostgreSQL database with real-time subscriptions
- **Row Level Security (RLS)** - Secure data access policies
- **Real-time Updates** - WebSocket connections for live tracking
- **RESTful APIs** - Standard HTTP endpoints for mobile integration

### **Mobile Stack**
- **Flutter 3.0+** - Cross-platform mobile development
- **Provider** - State management
- **Geolocator** - GPS location services
- **Flutter Map** - Interactive map rendering
- **Background Services** - Continuous location tracking

### **External Services**
- **Ola Maps API** - Route calculation and navigation
- **LocationIQ** - Reverse geocoding
- **OpenRouteService** - Fallback routing service
- **Firebase** - Push notifications (optional)

## 🚀 Getting Started

### **Prerequisites**

- Flutter 3.0 or higher
- Dart 3.0 or higher
- Android Studio / VS Code
- Android SDK (API level 21+)
- iOS 11.0+ (for iOS development)

### **Installation**

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/campus_ride.git
   cd campus_ride
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Environment Configuration**
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env with your configuration
   nano .env
   ```

4. **Required API Keys**
   
   Create accounts and obtain API keys for:
   - **Supabase** - [supabase.com](https://supabase.com)
   - **Ola Maps** - [maps.olacabs.com](https://maps.olacabs.com)
   - **LocationIQ** - [locationiq.com](https://locationiq.com)
   - **OpenRouteService** - [openrouteservice.org](https://openrouteservice.org)
   - **MapTiler** - [maptiler.com](https://maptiler.com)

5. **Database Setup**
   
   Import the database schema and policies:
   ```sql
   -- In Supabase SQL Editor, run:
   \i docs/sql/schema.sql
   \i docs/sql/policies.json
   ```

6. **Run the app**
   ```bash
   # Development mode
   flutter run
   
   # Release build
   flutter build apk --release
   ```

## 🔧 Configuration

### **Environment Variables**

Configure the following variables in your `.env` file:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key

# Ola Maps API
OLA_MAPS_API_KEY=your_ola_maps_api_key

# LocationIQ API (for reverse geocoding)
LOCATIONIQ_API_KEY=your_locationiq_api_key

# OpenRouteService API (fallback routing)
OPENROUTESERVICE_API_KEY=your_openrouteservice_api_key

# MapTiler Configuration
MAPTILER_API_KEY=your_maptiler_api_key
MAPLIBRE_STYLE_URL=https://api.maptiler.com/maps/streets/style.json?key=your_key
```

### **Android Configuration**

1. **Permissions** (automatically handled by app)
   - Location permissions (fine and coarse)
   - Background location permission
   - Foreground service permission
   - Notification permissions

2. **ProGuard** (for release builds)
   ```
   # Already configured in android/app/proguard-rules.pro
   ```

### **iOS Configuration**

1. **Info.plist** permissions
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>This app needs location permission to track bus location</string>
   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>This app needs background location to continue tracking when closed</string>
   ```

## 📱 Features Deep Dive

### **🔄 Background Location Tracking**

The app implements a robust background location service that:

- **Continues tracking** when app is minimized or closed
- **Shows persistent notifications** with trip status
- **Updates location every 15 seconds** to the database
- **Handles battery optimization** across different Android versions
- **Manages permissions** with user-friendly dialogs

### **🗺️ Real-time Navigation**

Advanced navigation features include:

- **Live GPS tracking** with smooth marker animations
- **Route optimization** using multiple mapping services
- **Turn-by-turn directions** with voice guidance
- **Dynamic route recalculation** based on traffic
- **Offline map support** for basic functionality

### **📊 Analytics & Reporting**

Comprehensive analytics system:

- **Trip statistics** - Distance, duration, fuel efficiency
- **Driver performance** - On-time rates, route adherence
- **Passenger insights** - Popular routes, peak times
- **System health** - App usage, error tracking

## 🔐 Security & Privacy

### **Data Protection**
- **End-to-end encryption** for sensitive data
- **Row Level Security** in Supabase database
- **API key protection** through environment variables
- **No hardcoded secrets** in source code

### **Privacy Compliance**
- **Location data anonymization** after trip completion
- **GDPR compliance** for EU users
- **User consent management** for data collection
- **Data retention policies** configurable per institution

## 📦 Project Structure

```
lib/
├── core/                   # Core business logic
│   ├── models/            # Data models
│   ├── services/          # Business services
│   └── utils/             # Utility functions
├── features/              # Feature modules
│   ├── auth/              # Authentication
│   ├── driver/            # Driver functionality
│   ├── passenger/         # Passenger features
│   └── admin/             # Admin dashboard
├── shared/                # Shared widgets & components
└── main.dart              # App entry point

docs/                      # Documentation
├── sql/                   # Database schema
├── flows/                 # User flow diagrams
└── api/                   # API documentation

android/                   # Android-specific code
ios/                       # iOS-specific code
web/                       # Web platform code
```

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Generate test coverage
flutter test --coverage
```

## 📈 Performance

### **Optimization Features**
- **Efficient location updates** (15-second intervals)
- **Smart caching** for offline functionality
- **Image optimization** for map tiles
- **Battery optimization** handling
- **Memory management** for long-running processes

### **Monitoring**
- **Crashlytics integration** for error tracking
- **Performance monitoring** for app metrics
- **Real-time logging** for debugging
- **Analytics tracking** for user behavior

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **Development Workflow**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### **Code Standards**

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` for linting
- Maintain test coverage above 80%
- Document public APIs with DartDoc

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Ola Maps** for routing and navigation services
- **Supabase** for backend infrastructure
- **Flutter team** for the amazing framework
- **OpenStreetMap** contributors for map data
- **Contributors** who have helped improve this project

## 📞 Support

- **Documentation**: [Wiki](https://github.com/yourusername/campus_ride/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/campus_ride/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/campus_ride/discussions)
- **Email**: support@campusride.app

---

<div align="center">
  <p>Built with ❤️ for campus communities worldwide</p>
  <p>
    <a href="#top">Back to top</a>
  </p>
</div>
