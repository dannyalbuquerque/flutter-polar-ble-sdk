#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint polar_ble_sdk.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'polar_ble_sdk'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'streams_channel'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.preserve_paths = 'PolarBleSdk.xcframework', 'RxSwift.xcframework'
  s.xcconfig = { 'OTHER_LDFLAGS' => '-framework PolarBleSdk.xcframework RxSwift.xcframework' }
  s.vendored_frameworks = 'PolarBleSdk.xcframework', 'RxSwift.xcframework'
end
