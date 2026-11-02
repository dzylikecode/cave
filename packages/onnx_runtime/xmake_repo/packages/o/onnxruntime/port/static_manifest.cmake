# Copyright (c) 2026. Licensed under the MIT License.
# Keep the session C API visible when its objects are relinked into a DSO.
set_target_properties(onnxruntime_session PROPERTIES
  C_VISIBILITY_PRESET default CXX_VISIBILITY_PRESET default)
# Generate a CMake File API link manifest without building another shared library.
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/onnxruntime_dart_link_manifest.c" "int ort_dart_manifest;\n")
add_library(onnxruntime_dart_link_manifest SHARED EXCLUDE_FROM_ALL
  "${CMAKE_CURRENT_BINARY_DIR}/onnxruntime_dart_link_manifest.c")
target_link_libraries(onnxruntime_dart_link_manifest PRIVATE
  onnxruntime_session ${onnxruntime_libs} ${onnxruntime_INTERNAL_PROVIDER_LIBRARIES}
  onnxruntime_optimizer onnxruntime_providers onnxruntime_lora
  onnxruntime_framework onnxruntime_graph onnxruntime_util
  ${ONNXRUNTIME_MLAS_LIBS} onnxruntime_common onnxruntime_flatbuffers
  ${onnxruntime_EXTERNAL_LIBRARIES})


# ARM common/platform objects reference cpuinfo even when upstream's exported
# dependency list omits it. Keep its actual archive in the merged link inputs.
if(TARGET cpuinfo)
  target_link_libraries(onnxruntime_dart_link_manifest PRIVATE cpuinfo)
endif()

# Static ORT builds do not link a top-level executable, so some external
# archives (for example re2) are excluded from the default upstream build.
# Build those resolved dependencies without linking the manifest DSO.
add_custom_target(onnxruntime_dart_archives ALL)
get_target_property(_ort_link_targets onnxruntime_dart_link_manifest LINK_LIBRARIES)
foreach(_ort_target IN LISTS _ort_link_targets)
  if(TARGET "${_ort_target}")
    get_target_property(_ort_alias "${_ort_target}" ALIASED_TARGET)
    if(_ort_alias)
      set(_ort_target "${_ort_alias}")
    endif()
    get_target_property(_ort_imported "${_ort_target}" IMPORTED)
    if(NOT _ort_imported)
      add_dependencies(onnxruntime_dart_archives "${_ort_target}")
    endif()
  endif()
endforeach()
