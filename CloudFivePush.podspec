#
# Be sure to run `pod lib lint cloudfivepush.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "CloudFivePush"
  s.version          = "0.11.0"
  s.summary          = "iOS client library for receiving push notifications from cloudfiveapp.com."
  s.description      = <<-DESC
                       Easy push notifications via https://push.cloudfiveapp.com.  Just include this Pod in your iOS
                       project and sign up online to get started.
                       DESC
  s.homepage         = "https://github.com/cloudfive/push-ios"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Brian Samson" => "brian@cloudfiveapp.com" }
  s.source           = { :git => "https://github.com/cloudfive/push-ios.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/cloudfiveapp'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'

end
