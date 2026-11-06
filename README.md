# MemoryCore

MemoryCore is a C++20 shared library for scanning explicitly registered,
library-owned test buffers. It does not read other processes or retain pointers
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

## Build the iOS library with GitHub Actions

The [iOS workflow](.github/workflows/ios-native.yml) runs on a macOS GitHub
Actions runner, but targets **iPhoneOS arm64** and **iOS Simulator arm64**. It
packages both Mach-O dynamic libraries into `MemoryCore.xcframework` and
publishes that as a downloadable workflow artifact. It runs on pushes that
change `Native/` and can also be started manually from the repository's
Actions tab with **Build iOS MemoryCore → Run workflow**.

The generated XCFramework is a library for an iOS app to link and embed; it is
not an iPhone app or an independently installable package. Embedding it in an
app and distributing that app requires an Xcode app target and signing. This
workspace has no such app project, so the workflow does not produce an IPA.