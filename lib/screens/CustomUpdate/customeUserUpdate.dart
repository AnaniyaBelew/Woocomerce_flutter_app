import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:inspireui/utils/logs.dart';
import 'package:latlong2/latlong.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class UpdateInfoScreen extends StatefulWidget {
  @override
  _UpdateInfoScreenState createState() => _UpdateInfoScreenState();
}

class _UpdateInfoScreenState extends State<UpdateInfoScreen> {
  String? phoneNumber;
  String? otpCode;
  bool otpRequested = false;
  bool otpVerified = false;
  bool isLoadingOtp = false;
  LatLng? _currentLocation;
  bool _mapLoading = true;
  MapController _mapController = MapController();

  // Password fields
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentLocation = LatLng(9.03, 38.74); // Set initial location for the map.
    _mapLoading = false;
  }
  Future<void> _requestOtp() async {
    printLog('OTP request initiated');

    if (phoneNumber == null || phoneNumber!.isEmpty) {
      _showMessage('please enter you phone number');
      setState(() {
        otpRequested = false;
      });
      return;
    }
    if (!(phoneNumber!.startsWith('09') || phoneNumber!.startsWith('251'))) {
      _showMessage('Please use a real phone number!');
      setState(() {
        otpRequested = false;
      });
      return;
    }
    if (phoneNumber!.startsWith('09') && phoneNumber!.length != 10) {
      _showMessage('Incorrect Phone Format');
      setState(() {
        otpRequested = false;
      });
      return;
    }
    if (phoneNumber!.startsWith('251') && phoneNumber!.length != 12) {
      _showMessage('Incorrect Phone Format');
      setState(() {
        otpRequested = false;
      });
      return;
    }
    printLog('last seen');
    setState(() {
      isLoadingOtp = true;
    });

    // Define the API endpoint and parameters
    const String url = 'https://api.afromessage.com/api/challenge';
    final Map<String, String> queryParams = {
      'from': 'e80ad9d8-adf3-463f-80f4-7c4b39f7f164',
      'to': phoneNumber!,
      'len': '6',
      't': '2',
      'ttl': '60',
      'sender': 'Bzu',
    };

    final Uri uri = Uri.parse(url).replace(queryParameters: queryParams);
    printLog('Constructed URI: $uri');

    // Define the bearer token
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.eyJpZGVudGlmaWVyIjoiZThnZExTcGwySk1KbUwyWUFTWHl1SUdBMFA5ajF5ZloiLCJleHAiOjE4NzM2MjU5MzksImlhdCI6MTcxNTg1OTUzOSwianRpIjoiZjk3NTRlMDgtMWE1Ni00NWJmLWEyNGYtYWZlYjIwYjkyNmIyIn0.PWyhsGn17hprc5sOga_q_3gyIqMl-8AD6QdzcyxWkqM';

    try {
      // Create an HttpClient
      final httpClient = HttpClient();

      // Create the request
      final HttpClientRequest request = await httpClient.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');

      // Send the request and receive a response
      final HttpClientResponse response = await request.close();

      // Read the response body
      final responseBody = await response.transform(utf8.decoder).join();
      printLog('Response received: ${response.statusCode}');
      printLog('Response body: $responseBody');

      if (response.statusCode == HttpStatus.ok) {
        final responseJson = json.decode(responseBody);
        printLog('Parsed response body: $responseJson');

        if (responseJson['acknowledge'] == 'success') {
          setState(() {
            otpCode = responseJson['response']['verificationId'];
            otpRequested = true;
          });

          _showMessage('Otp sent successfully expires in 60 sec ',
              isError: false);
          await _showOtpDialog(context);
        } else {
          _showMessage('Failed to send Otp');
          setState(() {
            otpRequested = false;
          });
        }
      } else {
        _showMessage('Failed to send Otp');
        setState(() {
          otpRequested = false;
        });
      }
    } catch (error, stackTrace) {
      printLog('Error occurred: $error');
      printLog('Stack trace: $stackTrace');
      _showMessage('Failed to send Otp');
      setState(() {
        otpRequested = false;
      });
    } finally {
      setState(() {
        isLoadingOtp = false; // Stop loading
      });
    }
  }

  Future<void> _showOtpDialog(BuildContext context) {
    String otpCode = '';

    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                // Dialog UI unchanged...
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('Enter the OTP sent to your phone'),
                    const SizedBox(height: 20.0),
                    // OTP Input Field
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
                      onChanged: (value) {
                        otpCode = value;
                      },
                      onCompleted: (value) {
                        otpCode = value;
                      },
                      // Same as before...
                    ),
                    const SizedBox(height: 20.0),
                    // Verify Button
                    MaterialButton(
                      onPressed: () async {
                        // Call OTP verification API or logic here
                        bool result = await _verifyOtp(otpCode);
                        if (result) {
                          Navigator.of(context).pop(); // Close the dialog
                          setState(() {
                            otpVerified = true; // Set OTP verified flag
                          });
                          _showMessage('OTP Verified',
                              isError: false); // Show success message
                        } else {
                          _showMessage('OTP incorrect'); // Show error message
                        }
                      },
                      color: Theme.of(context).primaryColor,
                      minWidth: double.infinity,
                      child: const Text('Verify',
                          style: TextStyle(color: Colors.white)),
                    ),
                    // Resend Button...
                  ],
                ),
              );
            },
          );
        });
  }

  Future<bool> _verifyOtp(String input) async {
    // otpCode == input;
    const String url = 'https://api.afromessage.com/api/verify';
    final queryParams = <String, String>{
      'to': phoneNumber!,
      'vc': otpCode ?? '',
      'code': input
    };
    final Uri uri = Uri.parse(url).replace(queryParameters: queryParams);
    printLog('Constructed URI: $uri');

    // Define the bearer token
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.eyJpZGVudGlmaWVyIjoiZThnZExTcGwySk1KbUwyWUFTWHl1SUdBMFA5ajF5ZloiLCJleHAiOjE4NzM2MjU5MzksImlhdCI6MTcxNTg1OTUzOSwianRpIjoiZjk3NTRlMDgtMWE1Ni00NWJmLWEyNGYtYWZlYjIwYjkyNmIyIn0.PWyhsGn17hprc5sOga_q_3gyIqMl-8AD6QdzcyxWkqM';
    try {
      // Create an HttpClient
      final httpClient = HttpClient();

      // Create the request
      final request = await httpClient.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');

      // Send the request and receive a response
      final HttpClientResponse response = await request.close();

      // Read the response body
      final responseBody = await response.transform(utf8.decoder).join();
      printLog('Response received: ${response.statusCode}');
      printLog('Response body: $responseBody');

      if (response.statusCode == HttpStatus.ok) {
        final responseJson = json.decode(responseBody);
        printLog('Parsed response body: $responseJson');

        if (responseJson['acknowledge'] == 'success') {
          setState(() {
            otpVerified = true;
          });

          _showMessage('Otp Verified!', isError: false);
          return true;
        } else {
          _showMessage('Otp is either incorrect or Expired');
          setState(() {
            otpVerified = false;
          });
          return false;
        }
      } else {
        _showMessage('Failed to Verify Otp');
        setState(() {
          otpVerified = false;
        });
        return false;
      }
    } catch (error, stackTrace) {
      printLog('Error occurred: $error');
      printLog('Stack trace: $stackTrace');
      _showMessage('Failed to Verify Otp');
      setState(() {
        otpVerified = false;
      });
      return false;
    }
  }

  // Widget for Password Update Section
  Widget _passwordUpdateSection() {
    return Column(
      children: [
        TextField(
          controller: passwordController,
          decoration: InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        TextField(
          controller: confirmPasswordController,
          decoration: InputDecoration(labelText: 'Confirm Password'),
          obscureText: true,
        ),
        SizedBox(height: 10),
        MaterialButton(
          onPressed: otpVerified ? null : _requestOtp, // Disable if OTP verified
          color: Theme.of(context).primaryColor,
          child: isLoadingOtp ? CircularProgressIndicator() : Text('Request OTP'),
        ),
      ],
    );
  }

  // Widget for Delivery Address Update (Map)
  Widget _deliveryAddressMap() {
    return _mapLoading
        ? CircularProgressIndicator()
        : Container(
      height: 300.0,
      margin: const EdgeInsets.symmetric(vertical: 20.0),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: _currentLocation,
          zoom: 15.0,
          onTap: (tapPosition, point) {
            setState(() {
              _currentLocation = point; // Set new location on tap
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                builder: (ctx) => Icon(Icons.location_pin, color: Colors.red, size: 40.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Submission of changes
  Future<void> _submitUpdate() async {
    if (passwordController.text != confirmPasswordController.text) {
      _showMessage("Passwords don't match");
      return;
    }
    if (!otpVerified) {
      _showMessage("OTP not verified");
      return;
    }

    // Submit password update and delivery address logic goes here
    _showMessage("Update successful", isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Update Info')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _passwordUpdateSection(),
            SizedBox(height: 20),
            _deliveryAddressMap(),
            SizedBox(height: 20),
            MaterialButton(
              onPressed: _submitUpdate,
              color: Theme.of(context).primaryColor,
              child: Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }
}
