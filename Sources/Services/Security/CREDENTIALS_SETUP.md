# Credentials Setup Guide

This document describes how to configure credentials for the JogPod application.

## Overview

JogPod requires the following credentials:

| Credential | Purpose | Required |
|------------|---------|----------|
| Fitbit Consumer Key | OAuth 1.0a app authentication | Yes |
| Fitbit Consumer Secret | OAuth 1.0a app authentication | Yes |
| Fitbit OAuth Callback | OAuth redirect URL | Yes |
| Weather API Key | Weather data for workouts | Optional |

## Security Architecture

All credentials are stored securely using the iOS Keychain with appropriate protection levels:

- **App-level credentials** (Consumer Key/Secret): Stored with `whenUnlockedThisDeviceOnly` accessibility
- **User credentials** (OAuth tokens): Stored with `afterFirstUnlockThisDeviceOnly` for background refresh support

### Key Components

```
Sources/Services/Security/
├── KeychainManager.swift      # Low-level Keychain access
├── CredentialsService.swift   # High-level credential management
├── CredentialsBootstrap.swift # Initial setup and migration
└── CREDENTIALS_SETUP.md       # This file
```

## Initial Setup

### Option 1: Environment Variables (Recommended for CI/CD)

Set the following environment variables:

```bash
export JOGPOD_FITBIT_CONSUMER_KEY="your-consumer-key"
export JOGPOD_FITBIT_CONSUMER_SECRET="your-consumer-secret"
export JOGPOD_FITBIT_CALLBACK="https://your-callback-url"
export JOGPOD_WEATHER_API_KEY="your-weather-api-key"  # Optional
```

Then in your app initialization:

```swift
let credentialsService = CredentialsService()
let bootstrap = CredentialsBootstrap(credentialsService: credentialsService)
try bootstrap.loadFromEnvironment()
```

### Option 2: Configuration File (Development)

Create a `credentials.json` file (DO NOT commit to source control):

```json
{
    "fitbit": {
        "consumerKey": "your-consumer-key",
        "consumerSecret": "your-consumer-secret",
        "callbackURL": "https://your-callback-url"
    },
    "weather": {
        "apiKey": "your-weather-api-key"
    }
}
```

Add to `.gitignore`:
```
credentials.json
*.credentials
```

Load in app:
```swift
let configURL = Bundle.main.url(forResource: "credentials", withExtension: "json")!
try bootstrap.loadFromConfigurationFile(at: configURL)
```

### Option 3: Xcode Scheme Environment Variables

1. Edit your scheme (Product > Scheme > Edit Scheme)
2. Select "Run" > "Arguments"
3. Add environment variables under "Environment Variables"

### Option 4: Programmatic Setup (Testing)

```swift
let credentialsService = CredentialsService()
let bootstrap = CredentialsBootstrap(credentialsService: credentialsService)

try bootstrap.configureFitbit(
    consumerKey: "your-key",
    consumerSecret: "your-secret",
    callback: "https://your-callback"
)
```

## Usage in Code

### Retrieving Credentials

```swift
let credentialsService = CredentialsService()

// Get individual credential
let consumerKey = try credentialsService.credential(for: .fitbitConsumerKey)

// Get all Fitbit app credentials
let fitbitCredentials = try credentialsService.fitbitAppCredentials()
print(fitbitCredentials.consumerKey)
print(fitbitCredentials.consumerSecret)
print(fitbitCredentials.callbackURL)

// Check if user is authenticated
if credentialsService.hasFitbitAuthentication {
    let userTokens = try credentialsService.fitbitUserTokens()
}
```

### Storing User Tokens After OAuth

```swift
// After successful OAuth flow
try credentialsService.storeFitbitUserTokens(
    token: oauthToken,
    secret: oauthTokenSecret
)
```

### Clearing User Session (Logout)

```swift
try credentialsService.clearFitbitAuthentication()
// Or clear all user credentials:
try credentialsService.clearUserCredentials()
```

## Migration from Legacy App

The legacy app stored OAuth tokens in UserDefaults. To migrate:

```swift
let bootstrap = CredentialsBootstrap(credentialsService: credentialsService)
let didMigrate = try bootstrap.migrateFromLegacyStorage()

if didMigrate {
    print("Successfully migrated credentials from legacy storage")
}
```

This will:
1. Read `fitbitAuthCode` and `fitbitSecret` from UserDefaults
2. Store them securely in Keychain
3. Remove the insecure UserDefaults entries

## Environment Support

The credentials service supports different environments:

- **Development**: Uses `development_` prefix for credential keys
- **Staging**: Uses `staging_` prefix
- **Production**: Uses `production_` prefix

This allows testing with different credentials without affecting production data.

```swift
// Environment is automatically detected from build configuration
let service = CredentialsService()  // Uses DEBUG/RELEASE to determine environment

// Or specify explicitly
let service = CredentialsService(environment: .staging)
```

## Security Best Practices

### DO:
- Store all sensitive credentials in Keychain
- Use environment-specific credentials
- Clear user credentials on logout
- Validate credentials are configured before use

### DON'T:
- Commit credentials to source control
- Log credential values (even in debug)
- Store credentials in UserDefaults or files
- Hardcode credentials in source code

## Production Recommendations

For production deployments, consider:

1. **Server-Side OAuth**: Move consumer credentials server-side to prevent extraction from the app binary
2. **Certificate Pinning**: Implement SSL pinning for OAuth flows
3. **App Attest**: Use App Attest to verify app integrity before credential delivery
4. **Credential Rotation**: Implement periodic credential rotation

## Troubleshooting

### Credentials Not Found

```swift
// Check if credentials are configured
let missing = bootstrap.missingCredentials()
if !missing.isEmpty {
    print("Missing credentials: \(missing.map { $0.description })")
}
```

### Keychain Access Errors

Ensure your app has the Keychain entitlement enabled in Xcode:
1. Select your target
2. Go to "Signing & Capabilities"
3. Add "Keychain Sharing" capability

### Testing

For unit tests, use a mock KeychainManager:

```swift
class MockKeychainManager: KeychainManaging {
    var storage: [String: String] = [:]

    func save(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
        storage[key] = value
    }

    func retrieve(forKey key: String) throws -> String {
        guard let value = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return value
    }

    func delete(forKey key: String) throws {
        storage.removeValue(forKey: key)
    }

    func exists(forKey key: String) -> Bool {
        storage[key] != nil
    }

    func update(_ value: String, forKey key: String, accessibility: KeychainAccessibility) throws {
        storage[key] = value
    }
}

// In tests
let mockKeychain = MockKeychainManager()
let service = CredentialsService(keychain: mockKeychain)
```

## API Reference

See inline documentation in:
- `KeychainManager.swift`
- `CredentialsService.swift`
- `CredentialsBootstrap.swift`
