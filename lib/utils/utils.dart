import 'package:flutter/services.dart';

class Utils {
  Utils._privateConstructor();

  static final Utils _instance = Utils._privateConstructor();

  static Utils get instance => _instance;

  Future<String> getLocalJson(String jsonName) async {
    final json = await rootBundle.loadString("assets/abi/$jsonName.json");
    return json;
  }
}
