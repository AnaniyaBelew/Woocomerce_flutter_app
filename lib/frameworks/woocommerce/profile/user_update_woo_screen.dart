import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:inspireui/utils/logs.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../../common/tools/flash.dart';
import '../../../data/boxes.dart';
import '../../../models/app_model.dart';

class UserUpdateWooScreen extends StatefulWidget {
  @override
  State<UserUpdateWooScreen> createState() => _UserUpdateScreenState();
}

class _UserUpdateScreenState extends State<UserUpdateWooScreen> {
  String? phoneNumber;
  String? otpCode;
  bool otpRequested = false;
  bool otpVerified = false;
  bool isLoadingOtp = false;
  latlong.LatLng? _currentLocation;
  bool _mapLoading = true;
  bool _isUpdatingAddress = false;
  MapController _mapController = MapController();

  // Password fields
  TextEditingController passwordController = TextEditingController();
  TextEditingController oldPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentLocation = latlong.LatLng(9.03, 38.74); // Set initial location for the map.
    _mapLoading = false;
    _isUpdatingAddress=false;
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
    final queryParams = <String, String?>{
      'to': UserBox().userInfo?.username!,
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

  Future<void> _requestOtp() async {
    printLog('OTP request initiated');

    if (UserBox().userInfo?.username == null) {
      _showMessage('please enter you phone number');
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
    final Map<String, String?> queryParams = {
      'from': 'e80ad9d8-adf3-463f-80f4-7c4b39f7f164',
      'to': UserBox().userInfo?.username,
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

          _showMessage('Otp sent successfully expires in 60 sec ', isError: false);
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

  Widget _passwordUpdateSection() {
    var isDarkTheme = Provider.of<AppModel>(context, listen: false).darkTheme;

    return Column(
      children: [
        buildDynamicPasswordField(
          labelText: 'Old Password',
          hintText: 'Enter your Old Password',
          controller: oldPasswordController,
          obscureText: false,
        ),
        const SizedBox(height: 5),
        buildDynamicPasswordField(
          labelText: 'New Password',
          hintText: 'Enter your New Password',
          controller: passwordController, // Should be a new controller for the new password
          obscureText: false,
        ),
        const SizedBox(height: 5),
        buildDynamicPasswordField(
          labelText: 'Confirm Password',
          hintText: 'Confirm your New Password',
          controller: confirmPasswordController,
          obscureText: false,
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: otpVerified ? null : _requestOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkTheme ? Colors.tealAccent : Colors.blue,
          ),
          child: isLoadingOtp
              ? CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(isDarkTheme ? Colors.black : Colors.white),
          )
              : Text('Request OTP', style: TextStyle(color: isDarkTheme ? Colors.black : Colors.white)),
        ),
      ],
    );
  }


  Widget _deliveryAddressMap() {
    var isDarkTheme = Provider.of<AppModel>(context, listen: false).darkTheme;
    return _mapLoading
        ? const CircularProgressIndicator()
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
                width: 80.0,
                height: 80.0,
                point: _currentLocation!,
                builder: (ctx) =>
                const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> submitUpdate({
    String? password,
    String? oldPassword, // Add old password for validation
    String? lat,
    String? lng,
    String? street,
    String? landmark,
    required BuildContext context,
  }) async {
    printLog('data for the update $password');
    printLog('data for the update $oldPassword');
    printLog('data for the update $lat');
    printLog('data for the update $lng');
    printLog('data for the update $street');
    printLog('data for the update $landmark');
    // Construct the body only with non-null values
    Map<String, dynamic> requestBody = {};
    String? username = UserBox().userInfo?.username;

    // Ensure the username is included in the request body
    if (username == null || username.isEmpty) {
      _showMessage('Username is required.', isError: true);
      return; // Exit if username is missing
    }
    requestBody['username'] = username; // Include username
    if (!otpVerified && (password!=null&&password.isNotEmpty)) {
      _showMessage('OTP is not verified');
      return; // Exit if username is missing
    }
    if (password != null && password.isNotEmpty) {
      if (oldPassword != null && oldPassword.isNotEmpty) {
        requestBody['password'] = password;
        requestBody['old_password'] = oldPassword; // Include old password in the request
      } else {
        _showMessage('Old password is required to update the password.', isError: true);
        return; // Exit the function early if old password is missing
      }
    }

    if ((lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty)&& _isUpdatingAddress) {
      requestBody['lat'] = lat;
      requestBody['lng'] = lng;
      if (street != null) requestBody['street'] = street;
      if (landmark != null) requestBody['landmark'] = landmark;
    }

    try {
      HttpClient httpClient = HttpClient();
      HttpClientRequest request = await httpClient.putUrl(Uri.parse('https://negade.biz/wp-json/wp/v2/user/update'));

      // Set request headers
      request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      // Write request body
      request.write(jsonEncode(requestBody));
      // Send the request
      HttpClientResponse response = await request.close();
      // Convert response to a string
      String responseBody = await response.transform(utf8.decoder).join();

      // Check the status code and handle responses
      if (response.statusCode == 200) {
        _showMessage('User updated successfully', isError: false);
      } else {
        // Decode the response body to handle error messages
        final responseData = jsonDecode(responseBody);
        String errorMessage = 'Failed to update user';

        // Check for specific error codes returned by the API
        if (responseData['code'] == 'missing_old_password') {
          errorMessage = 'Old password is required to change the password.';
        } else if (responseData['code'] == 'invalid_old_password') {
          errorMessage = 'Old password is incorrect.';
        } else if (responseData['code'] == 'invalid_password') {
          errorMessage = 'New password must be at least 8 characters long.';
        } else if (responseData['code'] == 'update_failed') {
          errorMessage = 'Failed to update the delivery address.';
        } else if (responseData['code'] == 'user_not_found') {
          errorMessage = 'User not found.';
        }

        _showMessage(errorMessage, isError: true);
      }

      httpClient.close(); // Close the HttpClient connection
    } catch (error) {
      // Handle any other errors
      _showMessage('An error occurred while updating the user: $error', isError: true);
    }
  }


  Widget buildDynamicPasswordField({
    required String labelText,
    required TextEditingController controller,
    bool obscureText = true,
    Color? labelColor,
    Color? borderColor,
    double labelFontSize = 16,
    FontWeight labelFontWeight = FontWeight.w600,
    String? hintText, // New parameter for hint text
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          labelText,
          style: TextStyle(
            fontSize: labelFontSize,
            fontWeight: labelFontWeight,
            color: labelColor ?? Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: Colors.green,
              width: 1.5,
            ),
          ),
          child: TextField(
            obscureText: obscureText,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText, // Use the hintText parameter here
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), // Optional styling for hint text
              ),
            ),
            controller: controller,
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    var isDarkTheme = Provider.of<AppModel>(context, listen: false).darkTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Update Info', style: TextStyle(color: isDarkTheme ? Colors.tealAccent : Colors.white)),
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _passwordUpdateSection(),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: (){
                  setState(() {
                    _isUpdatingAddress=!_isUpdatingAddress;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkTheme ? Colors.tealAccent : Colors.blue,
                ),
                child:_isUpdatingAddress? Text('close', style: TextStyle(color: isDarkTheme ? Colors.black : Colors.white)):Text('Update Address', style: TextStyle(color: isDarkTheme ? Colors.black : Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            _isUpdatingAddress?_deliveryAddressMap():SizedBox(),
            const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () {
              // Extract values from the UI fields
              String? password = passwordController.text;
              String? confirmPassword = confirmPasswordController.text;
              String? oldPassword=oldPasswordController.text;

              if (password != confirmPassword) {
                _showMessage('Passwords do not match');
                return;
              }

              // Latitude and Longitude from the map
              String? lat = _currentLocation?.latitude.toString();
              String? lng = _currentLocation?.longitude.toString();

              String? street = 'Some Street';
              String? landmark = 'Some Landmark';

              submitUpdate(
                password: password,
                oldPassword: oldPassword,
                lat: lat,
                lng: lng,
                street: street,
                landmark: landmark,
                context: context,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkTheme ? Colors.tealAccent : Colors.blue,
            ),
            child: Text('Update User', style: TextStyle(color: isDarkTheme ? Colors.black : Colors.white)),
          ),
        ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String text, {bool isError = true}) {
    if (!mounted) {
      return;
    }
    FlashHelper.message(
      context,
      message: text,
      isError: isError,
    );
  }
}
