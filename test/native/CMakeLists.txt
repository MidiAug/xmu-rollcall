cmake_minimum_required(VERSION 3.14)
project(notification_registration_tests LANGUAGES CXX)
add_executable(notification_registration_test
  notification_registration_test.cpp
  ../../windows/runner/notification_registration.cpp
)
target_compile_features(notification_registration_test PRIVATE cxx_std_17)
target_compile_definitions(notification_registration_test PRIVATE UNICODE _UNICODE NOMINMAX)
target_compile_options(notification_registration_test PRIVATE /W4 /WX /utf-8 /EHsc)
target_link_libraries(notification_registration_test PRIVATE ole32 shell32 propsys)
# Exercise Unicode shortcut names and executable paths containing spaces.
set_target_properties(notification_registration_test PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/path with spaces")
enable_testing()
add_test(NAME notification_registration COMMAND notification_registration_test)
set_tests_properties(notification_registration PROPERTIES TIMEOUT 45)
