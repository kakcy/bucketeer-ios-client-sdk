Pod::Spec.new do |s|
  s.name     = 'BucketeerGen'
  s.version  = '2.1.1' # x-release-please-version
  s.summary  = 'iOS SDK for Bucketeer'
  s.homepage = 'https://github.com/kakcy/bucketeer-ios-client-sdk'

  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '11.0'
  s.swift_version = '5.0'

  s.author = {
    'kakcy' => 'kakinoki_yoshifumi@cyberagent.co.jp'
  }

  s.source_files = 'Bucketeer/Sources/**/*.{swift,h,m}'
  s.source = {
    :git => 'https://github.com/kakcy/bucketeer-ios-client-sdk.git',
    :tag => "test-xcodegen",
  }

  s.license = {
    :type => 'Apache License, Version 2.0',
    :file => 'LICENSE',
  }
end
