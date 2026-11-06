# Memory Inspector

Memory Inspector is a native SwiftUI iOS app for inspecting explicitly
registered, application-owned test buffers. Its C++20 core copies source data
into native-owned regions; it does not read other processes or retain pointers
to caller memory.

## Build and test on Linux

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
```

The shared object is emitted as `build/libmemorycore.so`. The public C ABI is
defined in [`Native/MemoryCore.h`](Native/MemoryCore.h). Its region creation
function copies the supplied bytes into owned storage; subsequent writes and
scans operate only on that storage. Candidate retrieval is capped at 250 per
page while all candidates remain available for filtering.

## Native iOS UI and overlay

Open [`iOSMemoryInspector.xcodeproj`](iOSMemoryInspector.xcodeproj) in Xcode.
The app includes responsive iPhone tab navigation and an iPad sidebar, typed
initial and progressive scans, 250-row result paging, candidate inspection,
watchlist monitoring with value history, byte inspection, local SHA-256
snapshots, scan history, dataset mutation controls, and a draggable radial
quick-access overlay. The control is in-app only. Source data is synthetic,
mutable app-owned memory.

The app's native bridge compiles `Native/MemoryCore.cpp` directly into the app
target. The separate XCFramework build remains available for other authorized
app integrations.

## GitHub Actions builds

The [iOS workflow](.github/workflows/ios-native.yml) runs on a macOS GitHub
Actions runner. It builds Mach-O libraries for **iPhoneOS arm64** and **iOS
Simulator arm64**, packages them as `MemoryCore.xcframework`, builds the
unsigned simulator app, and publishes both as downloadable workflow artifacts.
It runs on pushes to relevant source files and can be started manually from
the repository's Actions tab.

The simulator app is not installable on a physical iPhone. Creating an
iPhone-installable IPA requires an Apple signing identity and provisioning
profile. iOS does not grant ordinary apps unrestricted access to other apps'
process memory; the app is intentionally limited to its registered, owned test
regions.