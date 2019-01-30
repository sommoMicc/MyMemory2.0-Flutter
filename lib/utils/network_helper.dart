import 'package:http/http.dart' as http;
import 'dart:convert'; //per JSON

import './storage_helper.dart';
import '../models/message.dart';

class NetworkHelper {
  static final String PROTOCOL = "https";
  static final String WEB_DOMAIN = "tagliabuemichele.homepc.it";
  static final int PORT = 8080;

  static Future<Message> doSignUp(String username, String email) async {
    final response = await http.post(
      _buildURL()+"/signup",
      body: {
        "username": username,
        "email": email
      }
    );
    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      return Message.fromJSON(json.decode(response.body));
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Comunicazione fallita');
    }
  }

  static String _buildURL() {
    return PROTOCOL+"://"+WEB_DOMAIN+":"+PORT.toString();
  }
}