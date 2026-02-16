import 'package:flutter/cupertino.dart';

import '../presentation/layout/responsive_layout.dart';

enum HttpMethod { get, post, put, delete, patch, head, options }

extension HttpMethodX on HttpMethod {
  String get name {
    switch (this) {
      case HttpMethod.get:
        return 'GET';
      case HttpMethod.post:
        return 'POST';
      case HttpMethod.put:
        return 'PUT';
      case HttpMethod.delete:
        return 'DELETE';
      case HttpMethod.patch:
        return 'PATCH';
      case HttpMethod.head:
        return 'HEAD';
      case HttpMethod.options:
        return 'OPTIONS';
    }
  }

  static HttpMethod fromString(String value) {
    switch (value.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PUT':
        return HttpMethod.put;
      case 'DELETE':
        return HttpMethod.delete;
      case 'PATCH':
        return HttpMethod.patch;
      case 'HEAD':
        return HttpMethod.head;
      case 'OPTIONS':
        return HttpMethod.options;
      default:
        throw ArgumentError('Unknown HTTP method: $value');
    }
  }
}

extension AppContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  bool get isMobile => screenWidth < AppBreakpoints.tablet;
  bool get isTablet => screenWidth >= AppBreakpoints.tablet && screenWidth < AppBreakpoints.desktop;
  bool get isDesktop => screenWidth >= AppBreakpoints.desktop;
}
