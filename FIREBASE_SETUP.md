# Firebase Setup Guide

Complete guide to setting up Firebase for your iOS app template.

## Prerequisites
- Apple Developer Account
- Firebase Account (Google account)
- Xcode with iOS 15+ support

## Step 1: ONLY USE FIREBASE IF DEVELOPER REQUESTS IT. - Create Firebase Project 

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Create a Project**
3. Enter project name: `MyApp` (or your app name)
4. Accept terms and create project

## Step 2: Register iOS App

1. In Firebase Console, click **Project Settings** (gear icon)
2. Click **Add App** → **iOS**
3. Enter iOS Bundle ID: `com.yourcompany.yourapp`
4. Download `GoogleService-Info.plist`

## Step 3: Add to Xcode

1. Open your app in Xcode
2. Drag `GoogleService-Info.plist` into Xcode (check "Copy items if needed")
3. Select your target and add to Build Phases

### Verify in Build Phases:
- Select Target → Build Phases
- Expand "Copy Bundle Resources"
- Ensure `GoogleService-Info.plist` is listed

## Step 4: Install Firebase SDK

### Option A: Swift Package Manager (Recommended)
```
1. File → Add Packages
2. Search: https://github.com/firebase/firebase-ios-sdk.git
3. Select version 10.0.0 or higher
4. Add to your target
```

### Option B: CocoaPods
```bash
# Create Podfile
pod init

# Edit Podfile, add:
pod 'Firebase/Auth'
pod 'Firebase/Firestore'
pod 'Firebase/Analytics'

# Install
pod install
```

## Step 5: Initialize Firebase

In `App.swift`, add:

```swift
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct TemplateApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Step 6: Enable Firestore Database

### In Firebase Console:
1. Go to Firestore Database
2. Click **Create database**
3. Select region (e.g., us-central1)
4. Start in **Test Mode** for development

### Important: Test Mode Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Change to **Production Mode** before releasing:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Subscriptions
    match /subscriptions/{document=**} {
      allow read: if request.auth.uid == resource.data.userId;
      allow write: if false; // Only backend creates
    }
  }
}
```

## Step 7: Enable Authentication

### In Firebase Console:
1. Go to **Authentication**
2. Click **Get started**
3. Enable providers you need:
   - **Email/Password**: Enable
   - **Apple**: Enable (for Sign in with Apple)
   - **Google**: Enable (optional)

### For Apple Sign In:
1. Go to Authentication → Sign-in method
2. Enable Apple
3. Provide Team ID and Key ID (from Apple Developer)

## Step 8: Create Firestore Collections

### Users Collection
```
Collection: users
Document ID: (auto-generated)

Fields:
- id: string (user ID)
- email: string
- displayName: string
- profileImageURL: string (nullable)
- createdAt: timestamp
- lastSignIn: timestamp
- isSubscribed: boolean
```

### Subscriptions Collection
```
Collection: subscriptions
Document ID: (auto-generated)

Fields:
- userId: string
- planId: string (weekly, monthly, yearly)
- transactionId: string
- isActive: boolean
- createdAt: timestamp
- expiryDate: timestamp
- renewalDate: timestamp
```

## Step 9: Test Firebase Connection

Add this test function to verify connection:

```swift
@MainActor
func testFirebaseConnection() {
    let db = Firestore.firestore()
    
    db.collection("test").document("test").setData(["message": "Hello from iOS"]) { error in
        if let error = error {
            print("Error writing test document: \(error)")
        } else {
            print("Successfully connected to Firestore!")
        }
    }
}

// Call in onAppear:
.onAppear {
    testFirebaseConnection()
}
```

## Step 10: Update DatabaseManager

The template includes `DatabaseManager.swift` which is pre-configured for Firestore. Verify it's using correct Firebase imports:

```swift
import FirebaseFirestore
import FirebaseAuth
```

## Security Rules by Use Case

### Allow Authenticated Users Only
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### User-Specific Data
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

### Public Read, Authenticated Write
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /posts/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## Troubleshooting

### "GoogleService-Info.plist not found"
- Ensure file is in Xcode project
- Check Build Phases → Copy Bundle Resources
- Verify file is added to correct target

### "Firebase not initialized"
- Add `FirebaseApp.configure()` in app init
- Check GoogleService-Info.plist is valid
- Restart Xcode and clean build

### "Firestore permission denied"
- Check security rules
- Verify user is authenticated
- Check console logs for specific errors

### "Cannot authenticate with Sign in with Apple"
- Verify Apple key is uploaded in Firebase
- Check Team ID and Key ID are correct
- Ensure app is on Apple Developer Account

## Performance Tips

1. **Enable offline persistence**:
   ```swift
   let settings = Firestore.firestore().settings
   settings.cacheSettings = PersistentCacheSettings()
   Firestore.firestore().settings = settings
   ```

2. **Batch writes** for multiple operations
3. **Index common queries** in Firebase console
4. **Paginate large result sets**

## Common Swift Code Snippets

### Save Document
```swift
let user = ["email": "user@example.com", "name": "John"]
try await Firestore.firestore().collection("users").addDocument(from: user)
```

### Read Document
```swift
let doc = try await Firestore.firestore().collection("users").document("userId").getDocument()
let user = try doc.data(as: User.self)
```

### Listen to Changes
```swift
Firestore.firestore().collection("users").document("userId").addSnapshotListener { snapshot, error in
    // Handle update
}
```

## Monitoring & Debugging

### In Firebase Console:
- Go to **Firestore** → **Usage** tab to monitor reads/writes
- Check **Logs** for errors
- Use **Realtime Database** for debugging auth issues

### Xcode Console:
Enable Firebase debug logging:
```swift
import FirebaseCore
FirebaseConfiguration.shared.setLoggerLevel(.debug)
```

## Next Steps

1. ✅ Database initialized
2. ✅ Authentication working
3. Deploy backend API → Configure for Firestore
4. Test subscriptions with App Store
5. Monitor usage and optimize

## Support

- [Firebase Docs](https://firebase.google.com/docs)
- [Swift SDK Guide](https://firebase.google.com/docs/firestore/quickstart)
- [Authentication Guide](https://firebase.google.com/docs/auth/ios/start)

---

Firebase setup complete! Your app is now ready to use real-time database and authentication.
