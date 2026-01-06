//
//  ResponseFixtures.swift
//  JogPod
//
//  Sample JSON and XML response fixtures for testing.
//  Created for JogPod Revival project.
//

import Foundation
@testable import JogPod

// MARK: - Fitbit API Response Fixtures

/// Sample Fitbit API response fixtures for testing.
public enum FitbitAPIFixtures {

    // MARK: - User Profile

    /// Successful user profile response.
    public static var userProfile: String {
        """
        {
            "user": {
                "encodedId": "ABC123",
                "displayName": "John Runner",
                "fullName": "John Marathon Runner",
                "avatar": "https://static0.fitbit.com/avatar/ABC123.jpg",
                "avatar150": "https://static0.fitbit.com/avatar/ABC123_150.jpg",
                "memberSince": "2020-01-15",
                "timezone": "America/New_York",
                "strideLengthRunning": 1.28,
                "strideLengthWalking": 0.76,
                "dateOfBirth": "1990-05-20",
                "height": 175.5,
                "weight": 72.5,
                "gender": "MALE"
            }
        }
        """
    }

    /// Minimal user profile response.
    public static var minimalUserProfile: String {
        """
        {
            "user": {
                "encodedId": "MIN456",
                "displayName": "Minimal User"
            }
        }
        """
    }

    // MARK: - OAuth Tokens

    /// Successful OAuth token response.
    public static var oauthToken: String {
        """
        {
            "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIyMjc...",
            "refresh_token": "64c5f...",
            "token_type": "Bearer",
            "expires_in": 28800,
            "scope": "activity profile heartrate location",
            "user_id": "ABC123"
        }
        """
    }

    /// OAuth token with short expiration.
    public static var shortLivedToken: String {
        """
        {
            "access_token": "short_lived_token_xyz",
            "refresh_token": "refresh_for_short_token",
            "token_type": "Bearer",
            "expires_in": 60,
            "scope": "activity profile",
            "user_id": "ABC123"
        }
        """
    }

    /// OAuth error response - invalid grant.
    public static var invalidGrantError: String {
        """
        {
            "error": "invalid_grant",
            "error_description": "The provided authorization grant is invalid, expired, revoked, or does not match the redirect URI used in the authorization request."
        }
        """
    }

    /// OAuth error response - invalid client.
    public static var invalidClientError: String {
        """
        {
            "error": "invalid_client",
            "error_description": "Client authentication failed."
        }
        """
    }

    /// OAuth error response - invalid scope.
    public static var invalidScopeError: String {
        """
        {
            "error": "invalid_scope",
            "error_description": "The requested scope is invalid, unknown, or malformed."
        }
        """
    }

    // MARK: - Activities

    /// Activity summary response.
    public static var activitySummary: String {
        """
        {
            "activities": [],
            "goals": {
                "activeMinutes": 30,
                "caloriesOut": 2500,
                "distance": 8.05,
                "floors": 10,
                "steps": 10000
            },
            "summary": {
                "activeScore": -1,
                "activityCalories": 1256,
                "caloriesBMR": 1545,
                "caloriesOut": 2801,
                "distances": [
                    {"activity": "total", "distance": 9.84},
                    {"activity": "tracker", "distance": 9.84},
                    {"activity": "loggedActivities", "distance": 0}
                ],
                "elevation": 27.43,
                "fairlyActiveMinutes": 23,
                "floors": 9,
                "heartRateZones": [
                    {"caloriesOut": 1800, "max": 95, "min": 30, "minutes": 1200, "name": "Out of Range"},
                    {"caloriesOut": 300, "max": 133, "min": 95, "minutes": 45, "name": "Fat Burn"},
                    {"caloriesOut": 200, "max": 166, "min": 133, "minutes": 20, "name": "Cardio"},
                    {"caloriesOut": 100, "max": 220, "min": 166, "minutes": 5, "name": "Peak"}
                ],
                "lightlyActiveMinutes": 198,
                "marginalCalories": 711,
                "restingHeartRate": 58,
                "sedentaryMinutes": 719,
                "steps": 12435,
                "veryActiveMinutes": 42
            }
        }
        """
    }

    // MARK: - Heart Rate

    /// Heart rate time series response.
    public static var heartRateTimeSeries: String {
        """
        {
            "activities-heart": [
                {
                    "dateTime": "2024-01-15",
                    "value": {
                        "restingHeartRate": 58,
                        "heartRateZones": [
                            {"caloriesOut": 1800, "max": 95, "min": 30, "minutes": 1200, "name": "Out of Range"},
                            {"caloriesOut": 300, "max": 133, "min": 95, "minutes": 45, "name": "Fat Burn"},
                            {"caloriesOut": 200, "max": 166, "min": 133, "minutes": 20, "name": "Cardio"},
                            {"caloriesOut": 100, "max": 220, "min": 166, "minutes": 5, "name": "Peak"}
                        ]
                    }
                }
            ]
        }
        """
    }

    // MARK: - Error Responses

    /// Rate limit exceeded response.
    public static var rateLimitExceeded: String {
        """
        {
            "errors": [
                {
                    "errorType": "request",
                    "message": "Too many requests. You have exceeded your rate limit."
                }
            ],
            "success": false
        }
        """
    }

    /// Insufficient permissions response.
    public static var insufficientPermissions: String {
        """
        {
            "errors": [
                {
                    "errorType": "insufficient_permissions",
                    "fieldName": "heartrate",
                    "message": "This application does not have permission to access heartrate data."
                }
            ],
            "success": false
        }
        """
    }

    /// Expired token response.
    public static var expiredToken: String {
        """
        {
            "errors": [
                {
                    "errorType": "expired_token",
                    "message": "Access token expired."
                }
            ],
            "success": false
        }
        """
    }

    /// Invalid token response.
    public static var invalidToken: String {
        """
        {
            "errors": [
                {
                    "errorType": "invalid_token",
                    "message": "Access token invalid."
                }
            ],
            "success": false
        }
        """
    }

    // MARK: - Token Introspection

    /// Active token introspection response.
    public static var tokenIntrospectionActive: String {
        """
        {
            "active": true,
            "scope": "activity profile heartrate location",
            "client_id": "ABC123",
            "user_id": "USER456",
            "token_type": "access_token",
            "exp": 1704067200,
            "iat": 1704038400
        }
        """
    }

    /// Inactive token introspection response.
    public static var tokenIntrospectionInactive: String {
        """
        {
            "active": false
        }
        """
    }
}

// MARK: - Weather API Response Fixtures

/// Sample weather API response fixtures for testing.
public enum WeatherAPIFixtures {

    /// Current weather response.
    public static var currentWeather: String {
        """
        {
            "coord": {"lon": -73.99, "lat": 40.71},
            "weather": [
                {"id": 800, "main": "Clear", "description": "clear sky", "icon": "01d"}
            ],
            "main": {
                "temp": 18.5,
                "feels_like": 17.8,
                "temp_min": 16.2,
                "temp_max": 20.1,
                "pressure": 1015,
                "humidity": 65
            },
            "visibility": 10000,
            "wind": {"speed": 3.6, "deg": 180},
            "clouds": {"all": 0},
            "dt": 1704067200,
            "sys": {
                "type": 2,
                "id": 2039034,
                "country": "US",
                "sunrise": 1704028800,
                "sunset": 1704063600
            },
            "timezone": -18000,
            "id": 5128581,
            "name": "New York",
            "cod": 200
        }
        """
    }

    /// Weather for running conditions.
    public static var goodRunningWeather: String {
        """
        {
            "weather": [{"id": 801, "main": "Clouds", "description": "few clouds", "icon": "02d"}],
            "main": {
                "temp": 15.0,
                "feels_like": 14.5,
                "humidity": 50
            },
            "wind": {"speed": 2.5, "deg": 90},
            "name": "Running City",
            "cod": 200
        }
        """
    }

    /// Bad weather conditions.
    public static var badRunningWeather: String {
        """
        {
            "weather": [{"id": 502, "main": "Rain", "description": "heavy intensity rain", "icon": "10d"}],
            "main": {
                "temp": 8.0,
                "feels_like": 4.5,
                "humidity": 95
            },
            "wind": {"speed": 12.5, "deg": 270},
            "name": "Rainy City",
            "cod": 200
        }
        """
    }

    /// API error response.
    public static var apiKeyError: String {
        """
        {
            "cod": 401,
            "message": "Invalid API key. Please see https://openweathermap.org/faq#error401 for more info."
        }
        """
    }

    /// City not found error.
    public static var cityNotFound: String {
        """
        {
            "cod": "404",
            "message": "city not found"
        }
        """
    }
}

// MARK: - Generic API Response Fixtures

/// Generic API response fixtures for common scenarios.
public enum GenericAPIFixtures {

    /// Empty JSON object.
    public static var emptyObject: String { "{}" }

    /// Empty JSON array.
    public static var emptyArray: String { "[]" }

    /// Generic success response.
    public static var success: String {
        """
        {
            "success": true,
            "message": "Operation completed successfully"
        }
        """
    }

    /// Generic error response.
    public static var error: String {
        """
        {
            "success": false,
            "error": {
                "code": "GENERIC_ERROR",
                "message": "An error occurred"
            }
        }
        """
    }

    /// Malformed JSON.
    public static var malformedJSON: String {
        "{ invalid json }"
    }

    /// HTML response (wrong content type).
    public static var htmlResponse: String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>Error</title></head>
        <body><h1>500 Internal Server Error</h1></body>
        </html>
        """
    }
}

// MARK: - RSS Feed XML Fixtures (Extended)

/// Extended RSS/Atom feed XML fixtures for testing feed parsing.
public enum ExtendedFeedFixtures {

    /// RSS feed with iTunes podcast extensions.
    public static var iTunesPodcast: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"
             xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
             xmlns:content="http://purl.org/rss/1.0/modules/content/">
            <channel>
                <title>JogPod Running Podcast</title>
                <link>https://jogpod.example.com</link>
                <description>The best podcast for runners!</description>
                <language>en-us</language>
                <itunes:author>JogPod Team</itunes:author>
                <itunes:owner>
                    <itunes:name>JogPod Team</itunes:name>
                    <itunes:email>podcast@jogpod.example.com</itunes:email>
                </itunes:owner>
                <itunes:image href="https://jogpod.example.com/artwork.jpg"/>
                <itunes:category text="Sports">
                    <itunes:category text="Running"/>
                </itunes:category>
                <itunes:explicit>false</itunes:explicit>
                <item>
                    <title>Episode 1: Getting Started</title>
                    <link>https://jogpod.example.com/episodes/1</link>
                    <guid isPermaLink="false">jogpod-ep-001</guid>
                    <pubDate>Mon, 01 Jan 2024 08:00:00 GMT</pubDate>
                    <description>Your first steps into running</description>
                    <content:encoded><![CDATA[<p>Welcome to JogPod!</p><p>In this episode...</p>]]></content:encoded>
                    <enclosure url="https://jogpod.example.com/audio/ep001.mp3" type="audio/mpeg" length="52428800"/>
                    <itunes:duration>45:30</itunes:duration>
                    <itunes:author>JogPod Team</itunes:author>
                    <itunes:explicit>false</itunes:explicit>
                    <itunes:episode>1</itunes:episode>
                    <itunes:season>1</itunes:season>
                </item>
                <item>
                    <title>Episode 2: Marathon Training</title>
                    <link>https://jogpod.example.com/episodes/2</link>
                    <guid isPermaLink="false">jogpod-ep-002</guid>
                    <pubDate>Mon, 08 Jan 2024 08:00:00 GMT</pubDate>
                    <description>How to train for your first marathon</description>
                    <enclosure url="https://jogpod.example.com/audio/ep002.mp3" type="audio/mpeg" length="62914560"/>
                    <itunes:duration>1:02:15</itunes:duration>
                    <itunes:episode>2</itunes:episode>
                    <itunes:season>1</itunes:season>
                </item>
            </channel>
        </rss>
        """
    }

    /// RSS feed with multiple enclosures.
    public static var multipleEnclosures: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Multi-Format Podcast</title>
                <link>https://multi.example.com</link>
                <description>Available in multiple formats</description>
                <item>
                    <title>Episode with Multiple Formats</title>
                    <guid>multi-001</guid>
                    <pubDate>Mon, 01 Jan 2024 08:00:00 GMT</pubDate>
                    <description>Same episode, multiple formats</description>
                    <enclosure url="https://multi.example.com/ep001.mp3" type="audio/mpeg" length="52428800"/>
                    <enclosure url="https://multi.example.com/ep001.m4a" type="audio/x-m4a" length="41943040"/>
                    <enclosure url="https://multi.example.com/ep001.ogg" type="audio/ogg" length="31457280"/>
                </item>
            </channel>
        </rss>
        """
    }

    /// RSS feed with special characters.
    public static var specialCharacters: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
            <channel>
                <title>Special Characters &amp; Symbols</title>
                <link>https://special.example.com</link>
                <description>Testing &lt;special&gt; &amp; "characters" in feeds</description>
                <item>
                    <title>Episode: "Quotes" &amp; &lt;Tags&gt;</title>
                    <guid>special-001</guid>
                    <pubDate>Mon, 01 Jan 2024 08:00:00 GMT</pubDate>
                    <description>Testing various special characters: &amp; &lt; &gt; " '</description>
                    <enclosure url="https://special.example.com/ep001.mp3" type="audio/mpeg" length="52428800"/>
                </item>
            </channel>
        </rss>
        """
    }

    /// RSS feed with CDATA content.
    public static var cdataContent: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
            <channel>
                <title>CDATA Content Podcast</title>
                <link>https://cdata.example.com</link>
                <description>Testing CDATA handling</description>
                <item>
                    <title>CDATA Episode</title>
                    <guid>cdata-001</guid>
                    <pubDate>Mon, 01 Jan 2024 08:00:00 GMT</pubDate>
                    <description><![CDATA[<p>This is <strong>HTML</strong> in CDATA</p>]]></description>
                    <content:encoded><![CDATA[<h1>Full Content</h1><p>With <a href="http://example.com">links</a></p>]]></content:encoded>
                    <enclosure url="https://cdata.example.com/ep001.mp3" type="audio/mpeg" length="52428800"/>
                </item>
            </channel>
        </rss>
        """
    }

    /// RSS feed with various date formats.
    public static var variousDateFormats: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
            <channel>
                <title>Date Format Podcast</title>
                <link>https://dates.example.com</link>
                <description>Testing various date formats</description>
                <item>
                    <title>RFC 822 Date</title>
                    <guid>date-001</guid>
                    <pubDate>Mon, 01 Jan 2024 08:00:00 GMT</pubDate>
                    <enclosure url="https://dates.example.com/ep001.mp3" type="audio/mpeg"/>
                </item>
                <item>
                    <title>RFC 822 with timezone</title>
                    <guid>date-002</guid>
                    <pubDate>Tue, 02 Jan 2024 08:00:00 -0500</pubDate>
                    <enclosure url="https://dates.example.com/ep002.mp3" type="audio/mpeg"/>
                </item>
                <item>
                    <title>Dublin Core Date</title>
                    <guid>date-003</guid>
                    <dc:date>2024-01-03T08:00:00Z</dc:date>
                    <enclosure url="https://dates.example.com/ep003.mp3" type="audio/mpeg"/>
                </item>
            </channel>
        </rss>
        """
    }

    /// Atom feed with full features.
    public static var fullAtomFeed: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Atom Running Podcast</title>
            <subtitle>The Atom-powered podcast for runners</subtitle>
            <link href="https://atom-running.example.com" rel="alternate"/>
            <link href="https://atom-running.example.com/feed.atom" rel="self"/>
            <id>urn:uuid:atom-running-feed</id>
            <updated>2024-01-15T08:00:00Z</updated>
            <author>
                <name>Atom Runner</name>
                <email>runner@atom.example.com</email>
            </author>
            <icon>https://atom-running.example.com/icon.png</icon>
            <logo>https://atom-running.example.com/logo.png</logo>
            <entry>
                <title>First Atom Episode</title>
                <link href="https://atom-running.example.com/episodes/1" rel="alternate"/>
                <link href="https://atom-running.example.com/audio/ep1.mp3" rel="enclosure" type="audio/mpeg" length="52428800"/>
                <id>urn:uuid:atom-ep-001</id>
                <published>2024-01-01T08:00:00Z</published>
                <updated>2024-01-01T10:00:00Z</updated>
                <summary>The very first episode of our Atom podcast</summary>
                <content type="html"><![CDATA[<p>Welcome to Atom Running!</p>]]></content>
                <author>
                    <name>Guest Runner</name>
                </author>
            </entry>
            <entry>
                <title>Second Atom Episode</title>
                <link href="https://atom-running.example.com/episodes/2" rel="alternate"/>
                <link href="https://atom-running.example.com/audio/ep2.mp3" rel="enclosure" type="audio/mpeg" length="62914560"/>
                <id>urn:uuid:atom-ep-002</id>
                <published>2024-01-08T08:00:00Z</published>
                <updated>2024-01-08T08:00:00Z</updated>
                <summary>Episode two of our journey</summary>
            </entry>
        </feed>
        """
    }
}

// MARK: - Data Conversion Extensions

extension FitbitAPIFixtures {
    /// Returns the fixture as Data.
    public static func data(for fixture: String) -> Data {
        fixture.data(using: .utf8)!
    }
}

extension WeatherAPIFixtures {
    /// Returns the fixture as Data.
    public static func data(for fixture: String) -> Data {
        fixture.data(using: .utf8)!
    }
}

extension ExtendedFeedFixtures {
    /// Returns the fixture as Data.
    public static func data(for fixture: String) -> Data {
        fixture.data(using: .utf8)!
    }
}
