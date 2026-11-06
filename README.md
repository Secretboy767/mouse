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

The app links and embeds `MemoryCore.xcframework` as a dynamic library. Swift
calls the C ABI in the embedded `libmemorycore.dylib`; the app does not compile
a second copy of `MemoryCore.cpp` into its executable. The simulator library
contains both Apple Silicon and Intel simulator slices.

## GitHub Actions builds

The [iOS workflow](.github/workflows/ios-native.yml) runs on a macOS GitHub
Actions runner. It builds Mach-O libraries for **iPhoneOS arm64** and **iOS
Simulator arm64**, packages them as `MemoryCore.xcframework`, builds and
launches the simulator app, builds an unsigned iPhone device app, and publishes
the framework, simulator app, device app, and an unsigned `.ipa` as downloadable
workflow artifacts. The `.ipa` contains the complete `MemoryInspector.app`,
including its SwiftUI interface and in-app floating overlay. It runs on pushes
to relevant source files and can be started manually from the repository's
Actions tab.

The unsigned `.ipa` is a package, not an install-ready signed application.
Sideloading it still requires signing it with a valid Apple development
identity and provisioning profile using an appropriate signing tool. The
simulator app is for the iOS Simulator. iOS does not grant ordinary apps
unrestricted access to other apps' process memory; this app is intentionally
limited to its registered, owned test regions.