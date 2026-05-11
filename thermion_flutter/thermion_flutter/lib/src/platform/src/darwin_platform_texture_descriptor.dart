import 'package:thermion_flutter/src/swift/swift_bindings.g.dart';
import 'platform_texture_descriptor.dart';

class DarwinPlatformTextureDescriptorImpl extends PlatformTextureDescriptor {
  final MetalTextureWrapper texture;

  bool _destroyed = false;

  DarwinPlatformTextureDescriptorImpl(this.texture,
      {required super.flutterTextureId,
      required super.hardwareId,
      required super.width,
      required super.height});

  @override
  Future destroy() async {
    // Idempotent: a second destroy() is a no-op rather than a throw.
    // Reason: the widget's `_allocateTexture` !mounted-branch calls
    // texture.destroy() on its in-flight texture; if the viewer's own
    // teardown path already destroyed it (e.g. when a multi-viewer
    // screen is popped while allocation is in progress), the throw
    // would propagate up through `setState()` and crash the Dart VM
    // (an FFI callback firing after Dart-side cleanup). Idempotency
    // makes the lifecycle race safe — see also the equivalent
    // Windows path which doesn't throw on double-destroy.
    if (_destroyed) {
      return;
    }
    // set flag early to ensure markTextureFrameAvailable is not called
    // with a destroyed texture handle
    _destroyed = true;
    SwiftThermionFlutterPluginObjCAPI
        .unregisterFlutterTextureWithFlutterTextureId_(flutterTextureId);
    texture.release();
  }

  @override
  void markTextureFrameAvailable() async {
    if (_destroyed) {
      return;
    }
    SwiftThermionFlutterPluginObjCAPI
        .markTextureFrameAvailableWithFlutterTextureId_(flutterTextureId);
  }

  static DarwinPlatformTextureDescriptorImpl allocate(int width, int height) {
    final metalTexture =
        MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(
            width, height, false, false);
    metalTexture.retain();
    final flutterTextureId =
        SwiftThermionFlutterPluginObjCAPI.registerTextureWithTexture_(
            metalTexture);
    if (flutterTextureId == -1) {
      throw Exception("Failed to register Flutter texture");
    }
    return DarwinPlatformTextureDescriptorImpl(metalTexture,
        flutterTextureId: flutterTextureId,
        hardwareId: metalTexture.metalTextureAddress,
        width: width,
        height: height);
  }
}
