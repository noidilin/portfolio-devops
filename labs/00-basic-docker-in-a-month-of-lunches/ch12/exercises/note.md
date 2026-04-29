## Bottom line

- One Dockerfile is enough when the base image and all build/runtime dependencies support all target platforms.
- Separate Dockerfiles or conditional logic are needed when some base images, tools, or artifacts are platform-specific.

## Multi-arch requirement

1. The `FROM` image must be available for the target platform.
   - If the base image is a multi-arch image, one tag can serve multiple platforms.
   - If it is not, you need separate platform-specific base images, like in these Dockerfiles:
     - `Dockerfile.linux-amd64` uses `diamol/base:2e-linux-amd64`
     - `Dockerfile.linux-arm64` uses `diamol/base:2e-linux-arm64`
     - `Dockerfile.linux-arm` uses `diamol/base:linux-arm`

2. Everything that executes inside the image build must match the target platform.
   - `RUN apk add ...`
   - `RUN apt-get install ...`
   - `RUN npm install` when native modules compile
   - `RUN dotnet publish`, `go build`, `pip install`, etc.
   If those steps produce native binaries, they must produce binaries for the target architecture.

3. Everything copied into the final image must also match the target platform.
   - Scripts are usually fine.
   - Native executables, shared libraries, Node native addons, Python wheels, Java JNI libs, etc. must match the target platform.

---

## What else to be aware of

1. Build platform vs target platform
   - In multi-platform builds, Docker may build on one machine architecture and target another.
   - `BUILDPLATFORM` = machine doing the build
   - `TARGETPLATFORM` = platform of the image being produced
   This matters a lot in multi-stage builds.

2. Emulation vs native build
   - `buildx` can use QEMU to build foreign architectures.
   - It is convenient, but slower.
   - Some build steps behave differently or fail under emulation.

3. Multi-arch tag vs separate tags
   - A single image tag like `myapp:latest` can actually point to a manifest list containing `amd64`, `arm64`, etc.
   - Docker pulls the matching variant automatically.
   - That is usually better than publishing separate user-facing tags unless you specifically want explicit platform tags.

4. OS matters too, not just CPU
   - `linux/amd64` and `windows/amd64` are different targets.
   - Binaries and base images must match both OS and architecture.

5. Language/runtime specifics
   - Interpreted code is usually portable.
   - Native dependencies are where problems usually appear.
   - Example: a Node app with pure JS is easier than one with native addons.

6. Final image can be simpler than build image
   - Common pattern: compile in one stage, copy only the correct target artifact into a runtime image for the same target platform.
