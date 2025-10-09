# 📡 CampusRide API Documentation

## Overview

CampusRide uses Supabase as its backend, providing a PostgreSQL database with real-time subscriptions, RESTful APIs, and Row Level Security (RLS).

## Base Configuration

```dart
// API Base URLs
SUPABASE_URL: https://your-project.supabase.co
SUPABASE_ANON_KEY: your_anon_key

// Headers
Authorization: Bearer {SUPABASE_ANON_KEY}
Content-Type: application/json
apikey: {SUPABASE_ANON_KEY}
```

## 🔐 Authentication

### **Sign Up**
```http
POST /auth/v1/signup
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword",
  "data": {
    "full_name": "John Doe",
    "role": "student"
  }
}
```

### **Sign In**
```http
POST /auth/v1/token?grant_type=password
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securepassword"
}
```

### **Response**
```json
{
  "access_token": "jwt_token_here",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "refresh_token_here",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "user_metadata": {
      "full_name": "John Doe",
      "role": "student"
    }
  }
}
```

## 🏫 Colleges

### **Get All Colleges**
```http
GET /rest/v1/colleges?select=*
Authorization: Bearer {access_token}
```

### **Response**
```json
[
  {
    "id": "college_uuid",
    "name": "University Name",
    "address": "College Address",
    "phone": "+1234567890",
    "email": "contact@university.edu",
    "website": "https://university.edu",
    "is_active": true,
    "created_at": "2025-01-01T00:00:00Z"
  }
]
```

## 🚌 Bus Routes

### **Get Active Routes**
```http
GET /rest/v1/bus_routes?select=*&is_active=eq.true
Authorization: Bearer {access_token}
```

### **Create Route** (Admin only)
```http
POST /rest/v1/bus_routes
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "route_name": "Route A",
  "route_code": "RT-001",
  "start_name": "Campus Gate",
  "end_name": "City Center",
  "start_latitude": 16.5443217,
  "start_longitude": 81.4963509,
  "end_latitude": 16.752289,
  "end_longitude": 81.6740039,
  "route_points": {
    "points": [
      {
        "lat": 16.5443217,
        "lng": 81.4963509,
        "index": 0,
        "timestamp": 1757933544487
      }
    ]
  },
  "college_id": "college_uuid",
  "is_active": true
}
```

### **Update Route**
```http
PATCH /rest/v1/bus_routes?id=eq.{route_id}
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "route_name": "Updated Route Name",
  "is_active": false
}
```

## 🚍 Driver Trips

### **Start Trip**
```http
POST /rest/v1/driver_trips
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "driver_id": "driver_uuid",
  "route_id": "route_uuid",
  "status": "active",
  "trip_type": "outbound",
  "started_at": "2025-01-01T10:00:00Z",
  "scheduled_start_time": "2025-01-01T10:00:00Z"
}
```

### **Get Active Trips**
```http
GET /rest/v1/driver_trips?select=*,bus_routes(*)&status=eq.active
Authorization: Bearer {access_token}
```

### **End Trip**
```http
PATCH /rest/v1/driver_trips?id=eq.{trip_id}
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "status": "completed",
  "actual_end_time": "2025-01-01T12:00:00Z",
  "driver_notes": "Trip completed successfully"
}
```

## 📍 Location Tracking

### **Submit Location**
```http
POST /rest/v1/driver_trip_locations
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "trip_id": "trip_uuid",
  "lat": 16.5443217,
  "lng": 81.4963509,
  "heading": 45.5,
  "speed_mps": 15.0,
  "accuracy": 5.0,
  "ts": "2025-01-01T10:30:00Z"
}
```

### **Get Trip Locations**
```http
GET /rest/v1/driver_trip_locations?select=*&trip_id=eq.{trip_id}&order=ts.desc&limit=100
Authorization: Bearer {access_token}
```

### **Real-time Subscription**
```dart
// Flutter/Dart real-time subscription
final subscription = supabase
  .from('driver_trip_locations')
  .stream(primaryKey: ['id'])
  .eq('trip_id', tripId)
  .listen((List<Map<String, dynamic>> data) {
    // Handle real-time location updates
    print('Location update: $data');
  });
```

## 👤 User Profiles

### **Get User Profile**
```http
GET /rest/v1/user_profiles?select=*&id=eq.{user_id}
Authorization: Bearer {access_token}
```

### **Update Profile**
```http
PATCH /rest/v1/user_profiles?id=eq.{user_id}
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "full_name": "Updated Name",
  "phone": "+1234567890",
  "profile_picture_url": "https://example.com/avatar.jpg"
}
```

### **Get Driver Profile**
```http
GET /rest/v1/driver_profiles?select=*,bus_routes(*)&user_id=eq.{user_id}
Authorization: Bearer {access_token}
```

## 📊 Analytics & Reports

### **Trip Statistics**
```http
POST /rest/v1/rpc/get_driver_trip_stats
Content-Type: application/json
Authorization: Bearer {access_token}

{
  "driver_uuid": "driver_uuid",
  "start_date": "2025-01-01",
  "end_date": "2025-01-31"
}
```

### **Response**
```json
{
  "total_trips": 45,
  "completed_trips": 42,
  "total_distance_km": 1250.5,
  "total_duration_hours": 89.2,
  "average_speed_kmh": 14.2,
  "on_time_percentage": 92.5
}
```

### **Route Performance**
```http
GET /rest/v1/rpc/get_route_performance?route_id={route_id}&days=30
Authorization: Bearer {access_token}
```

## 🔍 Search & Filters

### **Search Routes**
```http
GET /rest/v1/bus_routes?select=*&or=(route_name.ilike.*query*,start_name.ilike.*query*,end_name.ilike.*query*)&is_active=eq.true
Authorization: Bearer {access_token}
```

### **Filter by College**
```http
GET /rest/v1/bus_routes?select=*&college_id=eq.{college_id}&is_active=eq.true
Authorization: Bearer {access_token}
```

### **Advanced Filtering**
```http
GET /rest/v1/driver_trips?select=*,bus_routes(*)&status=eq.active&created_at=gte.2025-01-01T00:00:00Z&order=created_at.desc
Authorization: Bearer {access_token}
```

## 🔄 Real-time Features

### **Subscribe to Trip Updates**
```dart
final subscription = supabase
  .from('driver_trips')
  .stream(primaryKey: ['id'])
  .eq('status', 'active')
  .listen((List<Map<String, dynamic>> data) {
    // Handle real-time trip updates
  });
```

### **Subscribe to Location Updates**
```dart
final locationSubscription = supabase
  .from('driver_trip_locations')
  .stream(primaryKey: ['id'])
  .eq('trip_id', tripId)
  .order('ts', ascending: false)
  .limit(1)
  .listen((List<Map<String, dynamic>> data) {
    // Handle real-time location updates
  });
```

## 🚨 Error Handling

### **Standard Error Response**
```json
{
  "code": "400",
  "message": "Bad Request",
  "details": "Validation failed for field 'email'",
  "hint": "Email must be a valid email address"
}
```

### **Common HTTP Status Codes**
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `422` - Unprocessable Entity
- `500` - Internal Server Error

## 🔒 Row Level Security (RLS) Policies

### **User Data Access**
```sql
-- Users can only access their own profile
CREATE POLICY users_own_profile ON user_profiles
FOR ALL USING (auth.uid() = id);

-- Drivers can only see their own trips
CREATE POLICY drivers_own_trips ON driver_trips
FOR ALL USING (auth.uid() = driver_id);
```

### **Role-based Access**
```sql
-- Admins can manage college data
CREATE POLICY college_admin_access ON bus_routes
FOR ALL USING (
  get_user_role() = 'admin' 
  AND get_user_college() = college_id
);
```

## 📝 Request Examples

### **Complete Trip Flow**
```bash
# 1. Authenticate
curl -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -d '{"email":"driver@example.com","password":"password"}'

# 2. Start Trip
curl -X POST "${SUPABASE_URL}/rest/v1/driver_trips" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -d '{"route_id":"route_uuid","status":"active","trip_type":"outbound"}'

# 3. Submit Location
curl -X POST "${SUPABASE_URL}/rest/v1/driver_trip_locations" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -d '{"trip_id":"trip_uuid","lat":16.5443217,"lng":81.4963509}'

# 4. End Trip
curl -X PATCH "${SUPABASE_URL}/rest/v1/driver_trips?id=eq.${TRIP_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -d '{"status":"completed","actual_end_time":"2025-01-01T12:00:00Z"}'
```

## 🔧 Rate Limits

- **Authentication**: 60 requests/minute
- **Data Operations**: 300 requests/minute
- **Real-time Subscriptions**: 100 concurrent connections
- **File Uploads**: 10 requests/minute

## 📞 Support

For API-related issues:
- [GitHub Issues](https://github.com/yourusername/campus_ride/issues)
- [API Documentation](https://github.com/yourusername/campus_ride/wiki/API)
- Email: api@campusride.app

---

**Note**: Replace placeholder values (`{user_id}`, `{route_id}`, etc.) with actual UUIDs in production.