
#include "flutter/shell/platform/android/image_external_texture.h"

#include <android/hardware_buffer_jni.h>
#include <android/sensor.h>

#include "flutter/shell/platform/android/jni/platform_view_android_jni.h"
#include "flutter/shell/platform/android/ndk_helpers.h"

namespace flutter {

ImageExternalTexture::ImageExternalTexture(
    int64_t id,
    const fml::jni::ScopedJavaGlobalRef<jobject>& image_texture_entry,
    const std::shared_ptr<PlatformViewAndroidJNI>& jni_facade)
    : Texture(id),
      image_texture_entry_(image_texture_entry),
      jni_facade_(jni_facade) {}

// Implementing flutter::Texture.
void ImageExternalTexture::Paint(PaintContext& context,
                                 const SkRect& bounds,
                                 bool freeze,
                                 const DlImageSampling sampling) {
  if (state_ == AttachmentState::kDetached) {
    return;
  }
  Attach(context);
  const bool should_process_frame = !freeze;
  if (should_process_frame) {
    ProcessFrame(context, bounds);
  }
  if (dl_image_) {
    context.canvas->DrawImageRect(
        dl_image_,                                     // image
        SkRect::Make(dl_image_->bounds()),             // source rect
        bounds,                                        // destination rect
        sampling,                                      // sampling
        context.paint,                                 // paint
        flutter::DlCanvas::SrcRectConstraint::kStrict  // enforce edges
    );
  } else {
    FML_LOG(INFO) << "No DlImage available for ImageExternalTexture to paint.";
  }
}

// Implementing flutter::Texture.
void ImageExternalTexture::MarkNewFrameAvailable() {
  // NOOP.
}

// Implementing flutter::Texture.
void ImageExternalTexture::OnTextureUnregistered() {}

// Implementing flutter::ContextListener.
void ImageExternalTexture::OnGrContextCreated() {
  state_ = AttachmentState::kUninitialized;
}

sk_sp<flutter::DlImage> ImageExternalTexture::FindImage(uint64_t key) {
  for (size_t i = 0u; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == key) {
      auto result = images_[i].image;
      UpdateKey(result, key);
      return result;
    }
  }
  return nullptr;
}

void ImageExternalTexture::UpdateKey(const sk_sp<flutter::DlImage>& image,
                                     uint64_t key) {
  if (images_[0].key == key) {
    return;
  }
  size_t i = 1u;
  for (; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == key) {
      break;
    }
  }
  for (auto j = i; j > 0; j--) {
    images_[j] = images_[j - 1];
  }
  images_[0] = LRUImage{.key = key, .image = image};
}

uint64_t ImageExternalTexture::AddImage(const sk_sp<flutter::DlImage>& image,
                                        uint64_t key) {
  uint64_t lru_key = images_[kImageReaderSwapchainSize - 1].key;
  bool updated_image = false;
  for (size_t i = 0u; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == lru_key) {
      updated_image = true;
      images_[i] = LRUImage{.key = key, .image = image};
      break;
    }
  }
  if (!updated_image) {
    images_[0] = LRUImage{.key = key, .image = image};
  }
  UpdateKey(image, key);
  return lru_key;
}

void ImageExternalTexture::Clear() {
  for (size_t i = 0u; i < kImageReaderSwapchainSize; i++) {
    images_[i] = {.key = 0u, .image = nullptr};
  }
}

// Implementing flutter::ContextListener.
void ImageExternalTexture::OnGrContextDestroyed() {
  if (state_ == AttachmentState::kAttached) {
    dl_image_.reset();
    Clear();
    Detach();
  }
  state_ = AttachmentState::kDetached;
}

JavaLocalRef ImageExternalTexture::AcquireLatestImage() {
  JNIEnv* env = fml::jni::AttachCurrentThread();
  FML_CHECK(env != nullptr);

  // ImageTextureEntry.acquireLatestImage.
  JavaLocalRef image_java =
      jni_facade_->ImageProducerTextureEntryAcquireLatestImage(
          JavaLocalRef(image_texture_entry_));
  return image_java;
}

void ImageExternalTexture::CloseImage(const fml::jni::JavaRef<jobject>& image) {
  if (image.obj() == nullptr) {
    return;
  }
  jni_facade_->ImageClose(JavaLocalRef(image));
}

void ImageExternalTexture::CloseHardwareBuffer(
    const fml::jni::JavaRef<jobject>& hardware_buffer) {
  if (hardware_buffer.obj() == nullptr) {
    return;
  }
  jni_facade_->HardwareBufferClose(JavaLocalRef(hardware_buffer));
}

JavaLocalRef ImageExternalTexture::HardwareBufferFor(
    const fml::jni::JavaRef<jobject>& image) {
  if (image.obj() == nullptr) {
    return JavaLocalRef();
  }
  // Image.getHardwareBuffer.
  return jni_facade_->ImageGetHardwareBuffer(JavaLocalRef(image));
}

AHardwareBuffer* ImageExternalTexture::AHardwareBufferFor(
    const fml::jni::JavaRef<jobject>& hardware_buffer) {
  JNIEnv* env = fml::jni::AttachCurrentThread();
  FML_CHECK(env != nullptr);
  return NDKHelpers::AHardwareBuffer_fromHardwareBuffer(env,
                                                        hardware_buffer.obj());
}

}  // namespace flutter
