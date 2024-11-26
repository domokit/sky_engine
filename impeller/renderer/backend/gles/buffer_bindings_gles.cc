// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/renderer/backend/gles/buffer_bindings_gles.h"

#include <cstring>
#include <vector>

#include "impeller/base/validation.h"
#include "impeller/core/shader_types.h"
#include "impeller/renderer/backend/gles/device_buffer_gles.h"
#include "impeller/renderer/backend/gles/formats_gles.h"
#include "impeller/renderer/backend/gles/sampler_gles.h"
#include "impeller/renderer/backend/gles/texture_gles.h"

namespace impeller {

namespace {
class ScopedBytes {
 public:
  void Reset(size_t size) {
    bytes_ = std::make_unique<uint8_t[]>(size);
    size_ = size;
  }

  uint8_t* GetBytes() { return bytes_.get(); }
  size_t GetSize() const { return size_; }

 private:
  std::unique_ptr<uint8_t[]> bytes_;
  size_t size_ = 0;
};
}  // namespace

// This prefix is used in the names of inputs generated by ANGLE's framebuffer
// fetch emulation.
static constexpr std::string_view kAngleInputAttachmentPrefix =
    "ANGLEInputAttachment";

BufferBindingsGLES::BufferBindingsGLES() = default;

BufferBindingsGLES::~BufferBindingsGLES() = default;

bool BufferBindingsGLES::RegisterVertexStageInput(
    const ProcTableGLES& gl,
    const std::vector<ShaderStageIOSlot>& p_inputs,
    const std::vector<ShaderStageBufferLayout>& layouts) {
  std::vector<std::vector<VertexAttribPointer>> vertex_attrib_arrays(
      layouts.size());
  // Every layout corresponds to a vertex binding.
  // As we record, separate the attributes into buckets for each layout in
  // ascending order. We do this because later on, we'll need to associate each
  // of the attributes with bound buffers corresponding to the binding.
  for (auto layout_i = 0u; layout_i < layouts.size(); layout_i++) {
    const auto& layout = layouts[layout_i];
    for (const auto& input : p_inputs) {
      if (input.binding != layout_i) {
        continue;
      }
      VertexAttribPointer attrib;
      attrib.index = input.location;
      // Component counts must be 1, 2, 3 or 4. Do that validation now.
      if (input.vec_size < 1u || input.vec_size > 4u) {
        return false;
      }
      attrib.size = input.vec_size;
      auto type = ToVertexAttribType(input.type);
      if (!type.has_value()) {
        return false;
      }
      attrib.type = type.value();
      attrib.normalized = GL_FALSE;
      attrib.offset = input.offset;
      attrib.stride = layout.stride;
      vertex_attrib_arrays[layout_i].push_back(attrib);
    }
  }
  vertex_attrib_arrays_ = std::move(vertex_attrib_arrays);
  return true;
}

static std::string NormalizeUniformKey(const std::string& key) {
  std::string result;
  result.reserve(key.length());
  for (char ch : key) {
    if (ch != '_') {
      result.push_back(toupper(ch));
    }
  }
  return result;
}

static std::string CreateUniformMemberKey(const std::string& struct_name,
                                          const std::string& member,
                                          bool is_array) {
  std::string result;
  result.reserve(struct_name.length() + member.length() + (is_array ? 4 : 1));
  result += struct_name;
  if (!member.empty()) {
    result += '.';
    result += member;
  }
  if (is_array) {
    result += "[0]";
  }
  return NormalizeUniformKey(result);
}

static std::string CreateUniformMemberKey(
    const std::string& non_struct_member) {
  return NormalizeUniformKey(non_struct_member);
}

bool BufferBindingsGLES::ReadUniformsBindings(const ProcTableGLES& gl,
                                              GLuint program) {
  if (!gl.IsProgram(program)) {
    return false;
  }
  GLint max_name_size = 0;
  gl.GetProgramiv(program, GL_ACTIVE_UNIFORM_MAX_LENGTH, &max_name_size);

  GLint uniform_count = 0;
  gl.GetProgramiv(program, GL_ACTIVE_UNIFORMS, &uniform_count);

  // Query the Program for all active uniform locations, and
  // record this via normalized key.
  for (GLint i = 0; i < uniform_count; i++) {
    std::vector<GLchar> name;
    name.resize(max_name_size);
    GLsizei written_count = 0u;
    GLint uniform_var_size = 0u;
    GLenum uniform_type = GL_FLOAT;
    // Note: Active uniforms are defined as uniforms that may have an impact on
    //       the output of the shader. Drivers are allowed to (and often do)
    //       optimize out unused uniforms.
    gl.GetActiveUniform(program,            // program
                        i,                  // index
                        max_name_size,      // buffer_size
                        &written_count,     // length
                        &uniform_var_size,  // size
                        &uniform_type,      // type
                        name.data()         // name
    );

    // Skip unrecognized variables generated by ANGLE.
    if (gl.GetCapabilities()->IsANGLE()) {
      if (written_count >=
              static_cast<GLsizei>(kAngleInputAttachmentPrefix.length()) &&
          std::string_view(name.data(), kAngleInputAttachmentPrefix.length()) ==
              kAngleInputAttachmentPrefix) {
        continue;
      }
    }

    auto location = gl.GetUniformLocation(program, name.data());
    if (location == -1) {
      VALIDATION_LOG << "Could not query the location of an active uniform.";
      return false;
    }
    if (written_count <= 0) {
      VALIDATION_LOG << "Uniform name could not be read for active uniform.";
      return false;
    }
    uniform_locations_[NormalizeUniformKey(std::string{
        name.data(), static_cast<size_t>(written_count)})] = location;
  }
  return true;
}

bool BufferBindingsGLES::BindVertexAttributes(const ProcTableGLES& gl,
                                              size_t binding,
                                              size_t vertex_offset) {
  if (binding >= vertex_attrib_arrays_.size()) {
    return false;
  }

  if (!gl.GetCapabilities()->IsES()) {
    FML_DCHECK(vertex_array_object_ == 0);
    gl.GenVertexArrays(1, &vertex_array_object_);
    gl.BindVertexArray(vertex_array_object_);
  }

  for (const auto& array : vertex_attrib_arrays_[binding]) {
    gl.EnableVertexAttribArray(array.index);
    gl.VertexAttribPointer(array.index,       // index
                           array.size,        // size (must be 1, 2, 3, or 4)
                           array.type,        // type
                           array.normalized,  // normalized
                           array.stride,      // stride
                           reinterpret_cast<const GLvoid*>(static_cast<GLsizei>(
                               vertex_offset + array.offset))  // pointer
    );
  }

  return true;
}

bool BufferBindingsGLES::BindUniformData(const ProcTableGLES& gl,
                                         Allocator& transients_allocator,
                                         const Bindings& vertex_bindings,
                                         const Bindings& fragment_bindings) {
  for (const auto& buffer : vertex_bindings.buffers) {
    if (!BindUniformBuffer(gl, transients_allocator, buffer.view)) {
      return false;
    }
  }
  for (const auto& buffer : fragment_bindings.buffers) {
    if (!BindUniformBuffer(gl, transients_allocator, buffer.view)) {
      return false;
    }
  }

  std::optional<size_t> next_unit_index =
      BindTextures(gl, vertex_bindings, ShaderStage::kVertex);
  if (!next_unit_index.has_value()) {
    return false;
  }

  if (!BindTextures(gl, fragment_bindings, ShaderStage::kFragment,
                    *next_unit_index)
           .has_value()) {
    return false;
  }

  return true;
}

bool BufferBindingsGLES::UnbindVertexAttributes(const ProcTableGLES& gl) {
  for (const auto& array : vertex_attrib_arrays_) {
    for (const auto& attribute : array) {
      gl.DisableVertexAttribArray(attribute.index);
    }
  }
  if (!gl.GetCapabilities()->IsES()) {
    gl.DeleteVertexArrays(1, &vertex_array_object_);
    vertex_array_object_ = 0;
  }

  return true;
}

GLint BufferBindingsGLES::ComputeTextureLocation(
    const ShaderMetadata* metadata) {
  auto location = binding_map_.find(metadata->name);
  if (location != binding_map_.end()) {
    return location->second[0];
  }
  auto& locations = binding_map_[metadata->name] = {};
  auto computed_location =
      uniform_locations_.find(CreateUniformMemberKey(metadata->name));
  if (computed_location == uniform_locations_.end()) {
    locations.push_back(-1);
  } else {
    locations.push_back(computed_location->second);
  }
  return locations[0];
}

const std::vector<GLint>& BufferBindingsGLES::ComputeUniformLocations(
    const ShaderMetadata* metadata) {
  BindingMap::iterator location = binding_map_.find(metadata->name);
  if (location != binding_map_.end()) {
    return location->second;
  }

  // For each metadata member, look up the binding location and record
  // it in the binding map.
  std::vector<GLint>& locations = binding_map_[metadata->name] = {};
  locations.reserve(metadata->members.size());
  for (const ShaderStructMemberMetadata& member : metadata->members) {
    if (member.type == ShaderType::kVoid) {
      // Void types are used for padding. We are obviously not going to find
      // mappings for these. Keep going.
      locations.push_back(-1);
      continue;
    }

    size_t element_count = member.array_elements.value_or(1);
    const std::string member_key =
        CreateUniformMemberKey(metadata->name, member.name, element_count > 1);
    const std::unordered_map<std::string, GLint>::iterator computed_location =
        uniform_locations_.find(member_key);
    if (computed_location == uniform_locations_.end()) {
      // Uniform was not active.
      locations.push_back(-1);
      continue;
    }
    locations.push_back(computed_location->second);
  }
  return locations;
}

bool BufferBindingsGLES::BindUniformBuffer(const ProcTableGLES& gl,
                                           Allocator& transients_allocator,
                                           const BufferResource& buffer) {
  const ShaderMetadata* metadata = buffer.GetMetadata();
  const DeviceBuffer* device_buffer = buffer.resource.GetBuffer();
  if (!device_buffer) {
    VALIDATION_LOG << "Device buffer not found.";
    return false;
  }
  const DeviceBufferGLES& device_buffer_gles =
      DeviceBufferGLES::Cast(*device_buffer);
  const uint8_t* buffer_ptr =
      device_buffer_gles.GetBufferData() + buffer.resource.GetRange().offset;

  if (metadata->members.empty()) {
    VALIDATION_LOG << "Uniform buffer had no members. This is currently "
                      "unsupported in the OpenGL ES backend. Use a uniform "
                      "buffer block.";
    return false;
  }

  const std::vector<GLint>& locations = ComputeUniformLocations(metadata);
  ScopedBytes array_element_buffer;
  for (size_t i = 0u; i < metadata->members.size(); i++) {
    const ShaderStructMemberMetadata& member = metadata->members[i];
    GLint location = locations[i];
    // Void type or inactive uniform.
    if (location == -1 || member.type == ShaderType::kVoid) {
      continue;
    }

    size_t element_count = member.array_elements.value_or(1);
    size_t element_stride = member.byte_length / element_count;
    auto* buffer_data =
        reinterpret_cast<const GLfloat*>(buffer_ptr + member.offset);

    // When binding uniform arrays, the elements must be contiguous. Copy
    // the uniforms to a temp buffer to eliminate any padding needed by the
    // other backends if the array elements have padding.
    if (element_count > 1 && element_stride != member.size) {
      size_t array_size = member.size * element_count;
      if (array_size > array_element_buffer.GetSize()) {
        array_element_buffer.Reset(array_size);
      }
      for (size_t element_i = 0; element_i < element_count; element_i++) {
        std::memcpy(array_element_buffer.GetBytes() + element_i * member.size,
                    reinterpret_cast<const char*>(buffer_data) +
                        element_i * element_stride,
                    member.size);
      }
      buffer_data =
          reinterpret_cast<const GLfloat*>(array_element_buffer.GetBytes());
    }

    switch (member.type) {
      case ShaderType::kFloat:
        switch (member.size) {
          case sizeof(Matrix):
            gl.UniformMatrix4fv(location,       // location
                                element_count,  // count
                                GL_FALSE,       // normalize
                                buffer_data     // data
            );
            continue;
          case sizeof(Vector4):
            gl.Uniform4fv(location,       // location
                          element_count,  // count
                          buffer_data     // data
            );
            continue;
          case sizeof(Vector3):
            gl.Uniform3fv(location,       // location
                          element_count,  // count
                          buffer_data     // data
            );
            continue;
          case sizeof(Vector2):
            gl.Uniform2fv(location,       // location
                          element_count,  // count
                          buffer_data     // data
            );
            continue;
          case sizeof(Scalar):
            gl.Uniform1fv(location,       // location
                          element_count,  // count
                          buffer_data     // data
            );
            continue;
        }
        VALIDATION_LOG << "Size " << member.size
                       << " could not be mapped ShaderType::kFloat for key: "
                       << member.name;
      case ShaderType::kBoolean:
      case ShaderType::kSignedByte:
      case ShaderType::kUnsignedByte:
      case ShaderType::kSignedShort:
      case ShaderType::kUnsignedShort:
      case ShaderType::kSignedInt:
      case ShaderType::kUnsignedInt:
      case ShaderType::kSignedInt64:
      case ShaderType::kUnsignedInt64:
      case ShaderType::kAtomicCounter:
      case ShaderType::kUnknown:
      case ShaderType::kVoid:
      case ShaderType::kHalfFloat:
      case ShaderType::kDouble:
      case ShaderType::kStruct:
      case ShaderType::kImage:
      case ShaderType::kSampledImage:
      case ShaderType::kSampler:
        VALIDATION_LOG << "Could not bind uniform buffer data for key: "
                       << member.name << " : " << static_cast<int>(member.type);
        return false;
    }
  }
  return true;
}

std::optional<size_t> BufferBindingsGLES::BindTextures(
    const ProcTableGLES& gl,
    const Bindings& bindings,
    ShaderStage stage,
    size_t unit_start_index) {
  size_t active_index = unit_start_index;
  for (const auto& data : bindings.sampled_images) {
    const auto& texture_gles = TextureGLES::Cast(*data.texture.resource);
    if (data.texture.GetMetadata() == nullptr) {
      VALIDATION_LOG << "No metadata found for texture binding.";
      return std::nullopt;
    }

    auto location = ComputeTextureLocation(data.texture.GetMetadata());
    if (location == -1) {
      return std::nullopt;
    }

    //--------------------------------------------------------------------------
    /// Set the active texture unit.
    ///
    if (active_index >= gl.GetCapabilities()->GetMaxTextureUnits(stage)) {
      VALIDATION_LOG << "Texture units specified exceed the capabilities for "
                        "this shader stage.";
      return std::nullopt;
    }
    gl.ActiveTexture(GL_TEXTURE0 + active_index);

    //--------------------------------------------------------------------------
    /// Bind the texture.
    ///
    if (!texture_gles.Bind()) {
      return std::nullopt;
    }

    //--------------------------------------------------------------------------
    /// If there is a sampler for the texture at the same index, configure the
    /// bound texture using that sampler.
    ///
    const auto& sampler_gles = SamplerGLES::Cast(**data.sampler);
    if (!sampler_gles.ConfigureBoundTexture(texture_gles, gl)) {
      return std::nullopt;
    }

    //--------------------------------------------------------------------------
    /// Set the texture uniform location.
    ///
    gl.Uniform1i(location, active_index);

    //--------------------------------------------------------------------------
    /// Bump up the active index at binding.
    ///
    active_index++;
  }
  return active_index;
}

}  // namespace impeller
