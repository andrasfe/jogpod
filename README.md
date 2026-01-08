# JogPod

A podcast player for runners. Listen to your favorite podcasts while tracking your workouts.

## Features

- **Podcast Management**: Subscribe to podcasts via search or RSS URL
- **Queue-Based Playlist**: Manually select episodes from multiple podcasts to create your workout playlist
- **Workout Tracking**: Track distance, duration, pace, and calories during runs
- **Heart Rate Monitoring**: Connect to Bluetooth heart rate sensors
- **Voice Announcements**: Audio cues for workout stats while running
- **Apple Watch Support**: Companion app for watchOS

## Getting Started

1. Open the app and go to the **Playlist** tab
2. Tap **+** to add a podcast (search or paste RSS URL)
3. Tap on a podcast to view episodes
4. Swipe left on episodes to add them to your **Up Next** queue
5. Go to **Dashboard** and tap **Start Workout**

## Requirements

- iOS 17.0+
- Xcode 15.0+
- watchOS 10.0+ (for Apple Watch companion)

## Building

```bash
xcodebuild -project JogPod.xcodeproj -target JogPod -sdk iphonesimulator -configuration Debug build
```

## Disclaimer

**USE AT YOUR OWN RISK**

This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement.

In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

**Health and Safety Warning**: This app tracks workout metrics but should not be used as a medical device. Always consult with a healthcare professional before starting any exercise program. Do not rely solely on this app for health or fitness decisions.

## License

All rights reserved.

---

<sub>This is a personal project developed in my own time. It is not affiliated with, endorsed by, or related to my employer or any company I work for. All views and code are my own.</sub>
