
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
  const bool should_process_frame =
      (!freeze && new_frame_ready_) || dl_image_ == nullptr;
  if (should_process_frame) {
    ProcessFrame(context, bounds);
    new_frame_ready_ = false;
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
  new_frame_ready_ = true;
}

// Implementing flutter::Texture.
void ImageExternalTexture::OnTextureUnregistered() {}

// Implementing flutter::ContextListener.
void ImageExternalTexture::OnGrContextCreated() {
  state_ = AttachmentState::kUninitialized;
}

sk_sp<flutter::DlImage> ImageExternalTexture::FindImage(uint64_t key) {
  for (auto i = 0u; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == key) {
      UpdateKey(key);
      return images_[i].image;
    }
  }
  return nullptr;
}

void ImageExternalTexture::UpdateKey(uint64_t key) {
  if (keys_[0] == key) {
    return;
  }
  auto i = 1u;
  for (; i < kImageReaderSwapchainSize; i++) {
    if (keys_[i] == key) {
      break;
    }
  }
  for (auto j = i; j > 0; j--) {
    keys_[j] = keys_[j - 1];
  }
  keys_[0] = key;
}

void ImageExternalTexture::AddImage(const sk_sp<flutter::DlImage>& image,
                                    uint64_t key) {
  uint64_t lru_key = keys_[kImageReaderSwapchainSize - 1];
  bool updated_image = false;
  for (auto i = 0u; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == lru_key) {
      updated_image = true;
      images_[i] = LRUImage{.key = key, .image = image};
      break;
    }
  }
  if (!updated_image) {
    keys_[0] = key;
    images_[0] = LRUImage{.key = key, .image = image};
  }
  UpdateKey(key);
}

// Implementing flutter::ContextListener.
void ImageExternalTexture::OnGrContextDestroyed() {
  if (state_ == AttachmentState::kAttached) {
    dl_image_.reset();
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
