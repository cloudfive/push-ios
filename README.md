# Cloud Five Push for iOS

[![CI Status](http://img.shields.io/travis/Brian Samson/cloudfivepush.svg?style=flat)](https://travis-ci.org/Brian Samson/cloudfivepush)
[![Version](https://img.shields.io/cocoapods/v/cloudfivepush.svg?style=flat)](http://cocoapods.org/pods/cloudfivepush)
[![License](https://img.shields.io/cocoapods/l/cloudfivepush.svg?style=flat)](http://cocoapods.org/pods/cloudfivepush)
[![Platform](https://img.shields.io/cocoapods/p/cloudfivepush.svg?style=flat)](http://cocoapods.org/pods/cloudfivepush)

## Usage

After the application is initialized (i.e., in `applicationDidLaunch`), simple call `register`

    //Register this device for push notifications

    [CloudFivePush register];

    // If you wish to send targeted notifications to specific users, simply pass in a
    // unique user identifier:

    [CloudFivePush registerWithUserIdentifier: @"user@example.com"];

## Advanced Usage

Coming soon.

## Requirements

* iOS version must be at least 8

* You will need an account on [Cloud Five](http://push.cloudfiveapp.com) in order to send push notifications to the device.

## Installation

CloudFivePush is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "CloudFivePush"
```

## Author

Brian Samson, @samsonasu

## License

CloudFivePush is available under the MIT license. See the LICENSE file for more info.
