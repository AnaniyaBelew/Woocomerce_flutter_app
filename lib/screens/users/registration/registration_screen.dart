import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import '../../../common/config.dart';
import '../../../common/constants.dart';
import '../../../common/tools.dart';
import '../../../common/tools/flash.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart'
    show AppModel, CartModel, PointModel, User, UserModel;
import '../../../modules/dynamic_layout/helper/helper.dart';
import '../../../modules/vendor_on_boarding/screen_index.dart';
import '../../../routes/flux_navigate.dart';
import '../../../services/service_config.dart';
import '../../../services/services.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/flux_image.dart';
import '../../home/privacy_term_screen.dart';

enum RegisterType { customer, vendor }

class RegistrationScreenMobile extends StatefulWidget {
  const RegistrationScreenMobile();

  @override
  State<RegistrationScreenMobile> createState() =>
      _RegistrationScreenMobileState();
}

class _RegistrationScreenMobileState extends State<RegistrationScreenMobile> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();

  String? firstName,
      lastName,
      emailAddress,
      phoneNumber,
      password,
      companyName,
      confirmPassword;
  RegisterType? _registerType = RegisterType.customer;
  bool isChecked = true;
  bool _mapLoading = true;
  List<dynamic> salesPersons = [];
  String? selectedSalesPerson;
  String? otpCode;
  bool otpVerified = false;
  bool isLoadingOtp = false;
  bool otpRequested = false;

  LatLng? _currentLocation;

  final bool showPhoneNumberWhenRegister =
      kLoginSetting.showPhoneNumberWhenRegister;
  final bool requirePhoneNumberWhenRegister =
      kLoginSetting.requirePhoneNumberWhenRegister;

  final firstNameNode = FocusNode();
  final lastNameNode = FocusNode();
  final phoneNumberNode = FocusNode();
  final emailNode = FocusNode();
  final passwordNode = FocusNode();
  final companyNode = FocusNode();
  final confirmNode = FocusNode();

  Location _location = Location();
  MapController _mapController = MapController();

  void _welcomeDiaLog(User user) {
    Provider.of<CartModel>(context, listen: false).setUser(user);
    Provider.of<PointModel>(context, listen: false).getMyPoint(user.cookie);
    final model = Provider.of<UserModel>(context, listen: false);

    if (kVendorConfig.vendorRegister &&
        Provider.of<AppModel>(context, listen: false).isMultivendor &&
        user.isVender) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => VendorOnBoarding(
            user: user,
            onFinish: () {
              model.getUser();
              var email = user.email;
              _showMessage(
                '${S.of(ctx).welcome} $email!',
                isError: false,
              );
              var routeFound = false;
              var routeNames = [RouteList.dashboard, RouteList.productDetail];
              Navigator.popUntil(ctx, (route) {
                if (routeNames.any((element) =>
                    route.settings.name?.contains(element) ?? false)) {
                  routeFound = true;
                }
                return routeFound || route.isFirst;
              });

              if (!routeFound) {
                Navigator.of(ctx).pushReplacementNamed(RouteList.dashboard);
              }
            },
          ),
        ),
      );
      return;
    }

    var email = user.email;
    _showMessage(
      '${S.of(context).welcome} $email!',
      isError: false,
    );
    if (Services().widget.isRequiredLogin) {
      Navigator.of(context).pushReplacementNamed(RouteList.dashboard);
      return;
    }
    var routeFound = false;
    var routeNames = [RouteList.dashboard, RouteList.productDetail];
    Navigator.popUntil(context, (route) {
      if (routeNames
          .any((element) => route.settings.name?.contains(element) ?? false)) {
        routeFound = true;
      }
      return routeFound || route.isFirst;
    });

    if (!routeFound) {
      Navigator.of(context).pushReplacementNamed(RouteList.dashboard);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSalesPersons();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _companyController.dispose();
    firstNameNode.dispose();
    lastNameNode.dispose();
    emailNode.dispose();
    passwordNode.dispose();
    phoneNumberNode.dispose();
    companyNode.dispose();
    super.dispose();
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

  Future<void> _getLocation() async {
    var permissionStatus = await Permission.location.request();

    if (permissionStatus.isGranted) {
      try {
        var locationData = await _location.getLocation();
        setState(() {
          _currentLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
          _mapLoading = false; // Stop loading the map once location is fetched
        });
      } catch (e) {
        _showMessage('Error getting location: $e');
      }
    } else if (permissionStatus.isDenied) {
      _showMessage('Location permission denied. Please enable it in settings.');
    } else if (permissionStatus.isPermanentlyDenied) {
      _showMessage(
          'Location permission permanently denied. Open settings to allow.');
    }
  }

  Future<void> _resendOtp() async {
    if (phoneNumber == null || phoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number first')),
      );
      return;
    }
    // Define the API endpoint and parameters
    const String url = 'https://api.afromessage.com/api/challenge';
    final Map<String, String> queryParams = {
      'from': 'e80ad9d8-adf3-463f-80f4-7c4b39f7f164',
      'to': phoneNumber!,
      'len': '6',
      't': '2',
      'sender': 'Bzu',
    };

    final Uri uri = Uri.parse(url).replace(queryParameters: queryParams);

    // Define the bearer token
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.eyJpZGVudGlmaWVyIjoiZThnZExTcGwySk1KbUwyWUFTWHl1SUdBMFA5ajF5ZloiLCJleHAiOjE4NzM2MjU5MzksImlhdCI6MTcxNTg1OTUzOSwianRpIjoiZjk3NTRlMDgtMWE1Ni00NWJmLWEyNGYtYWZlYjIwYjkyNmIyIn0.PWyhsGn17hprc5sOga_q_3gyIqMl-8AD6QdzcyxWkqM';

    try {
      // Make the GET request
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      // Handle the response
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        // Check if the response acknowledges success
        if (responseBody['acknowledge'] == 'success') {
          setState(() {
            otpCode = responseBody['response']['code'];
            otpRequested = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to send OTP: ${responseBody['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      setState(() {
        isLoadingOtp = false; // Stop loading
      });
    }
  }

  Future<void> fetchSalesPersons() async {
    const String username =
        'admin@negade.biz'; // Replace with your Basic Auth username
    const String password =
        '86Mk U4OH YX9g rgUI TlCZ 422w'; // Replace with your Basic Auth password
    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    final Uri uri =
        Uri.parse('https://negade.biz/wp-json/myplugin/v1/sales-persons');

    try {
      final response = await http.get(
        uri,
        headers: <String, String>{
          'Authorization': basicAuth,
        },
      );
      printLog('this is the response ${json.decode(response.body)}');
      if (response.statusCode == 200) {
        printLog('success');
        final List<dynamic> data = json.decode(response.body);
        printLog('sales Persons: $data');
        setState(() {
          salesPersons = data;
        });
      } else {
        _showMessage('Failed to fetch Sales persons');
        throw Exception('Failed to load sales persons');
      }
    } catch (e) {
      printLog('Error fetching sales persons: $e');
      _showMessage('Failed to fetch Sales persons');
    }
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

  Future<void> _submitRegister({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? confirmPassword,
    String? password,
    String? companyName,
  }) async {
    if (firstName == null ||
        lastName == null ||
        phoneNumber == null ||
        password == null ||
        companyName == null) {
      _showMessage(S.of(context).pleaseInputFillAllFields);
    }
    else if (isChecked == false) {
      _showMessage(S.of(context).pleaseAgreeTerms);
    }
    if(password!=confirmPassword){
      _showMessage('Please Confirm Your Password!');
    }
    else if (_currentLocation == null) {
      _showMessage('Location permission denied. Please enable it in settings.');
    } else {
      if (password!.length < 8) {
        _showMessage(S.of(context).errorPasswordFormat);
        return;
      }

      try {
        final response = await http.post(
          Uri.parse(
              'https://negade.biz/wp-json/wp/v2/users'), // Update with your actual endpoint
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('admin@negade.biz:86Mk U4OH YX9g rgUI TlCZ 422w'))}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'username': phoneNumber,
            'phone': phoneNumber,
            'password': password,
            'full_name': '$firstName $lastName',
            'company_name': companyName,
            'sales_person': selectedSalesPerson,
            'lat': _currentLocation?.latitude,
            'lng': _currentLocation?.longitude,
            'street': '',
            'landmark': '',
          }),
        );
        printLog('register body: ${jsonEncode({
              'username': phoneNumber,
              'phone': phoneNumber,
              'password': password,
              'full_name': '$firstName $lastName',
              'company_name': companyName,
              'sales_person': selectedSalesPerson,
              'lat': _currentLocation?.latitude,
              'lng': _currentLocation?.longitude,
              'street': '',
              'landmark': '',
            })}');
        if (response.statusCode == 200) {
          printLog('success');
          _showMessage('Registered Successfully');
          await NavigateTools.navigateToLogin(context);
        } else {
          var resp = jsonDecode(response.body);
          _showMessage('Registration failed: ${resp['message']}');
        }
      } catch (e) {
        _showMessage('Error occurred: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context, listen: true);
    final themeConfig = appModel.themeConfig;

    if (_mapLoading) {
      _getLocation();
    }

    return ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0.0,
          ),
          body: SafeArea(
            child: GestureDetector(
              onTap: () => Tools.hideKeyboard(context),
              child: ListenableProvider.value(
                value: Provider.of<UserModel>(context),
                child: Consumer<UserModel>(
                  builder: (context, value, child) {
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: AutofillGroup(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Center(
                                child: FractionallySizedBox(
                                  widthFactor: 0.8,
                                  child: FluxImage(
                                    height: 50,
                                    useExtendedImage: false,
                                    imageUrl: themeConfig.logo,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5.0),

                              // Step 1: OTP Request
                              if (!otpRequested) ...[
                                CustomTextField(
                                  key: const Key('registerPhoneField'),
                                  focusNode: phoneNumberNode,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber
                                  ],
                                  onChanged: (value) => phoneNumber = value,
                                  decoration: InputDecoration(
                                    labelText: S.of(context).phone,
                                    hintText:
                                        S.of(context).enterYourPhoneNumber,
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 5.0),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10.0),
                                  child: MaterialButton(
                                    key: const Key('requestOtpButton'),
                                    onPressed: isLoadingOtp
                                        ? null
                                        : () async {
                                            setState(() {
                                              otpRequested =
                                                  true; // Update to show the verification UI
                                            });
                                            await _requestOtp(); // Request OTP
                                          },
                                    color: Theme.of(context).primaryColor,
                                    child: isLoadingOtp
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text('Request OTP',
                                            style:
                                                TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ]

                              // Step 2: OTP Verification
                              else if (!otpVerified) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10.0),
                                  child: MaterialButton(
                                    key: const Key('verifyOtpButton'),
                                    onPressed: () {
                                      _showOtpDialog(
                                          context); // Show OTP dialog for verification
                                    },
                                    color: Theme.of(context).primaryColor,
                                    child: const Text('Verify Phone',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ]

                              // Step 3: Registration Form
                              else ...[
                                // Existing registration form fields
                                CustomTextField(
                                  key: const Key('registerFirstNameField'),
                                  autofillHints: const [
                                    AutofillHints.givenName
                                  ],
                                  onChanged: (value) => firstName = value,
                                  textCapitalization: TextCapitalization.words,
                                  nextNode: lastNameNode,
                                  showCancelIcon: true,
                                  decoration: InputDecoration(
                                    labelText: S.of(context).firstName,
                                    hintText: S.of(context).enterYourFirstName,
                                  ),
                                ),
                                const SizedBox(height: 5.0),
                                CustomTextField(
                                  key: const Key('registerLastNameField'),
                                  autofillHints: const [
                                    AutofillHints.familyName
                                  ],
                                  focusNode: lastNameNode,
                                  onChanged: (value) => lastName = value,
                                  decoration: InputDecoration(
                                    labelText: S.of(context).lastName,
                                    hintText: S.of(context).enterYourLastName,
                                  ),
                                ),
                                const SizedBox(height: 5.0),
                                CustomTextField(
                                  key: const Key('registerPasswordField'),
                                  focusNode: passwordNode,
                                  autofillHints: const [AutofillHints.password],
                                  showEyeIcon: true,
                                  obscureText: true,
                                  onChanged: (value) => password = value,
                                  decoration: InputDecoration(
                                    labelText: S.of(context).enterYourPassword,
                                    hintText: S.of(context).enterYourPassword,

                                  ),
                                ),
                                const SizedBox(height: 5.0),
                                CustomTextField(
                                  key: const Key('confirmPasswordField'),
                                  focusNode: confirmNode,
                                  autofillHints: const [AutofillHints.password],
                                  showEyeIcon: true,
                                  obscureText: true,
                                  onChanged: (value) => confirmPassword = value,
                                  decoration: InputDecoration(
                                    labelText: S.of(context).confirmPassword,
                                    hintText: S.of(context).confirmPassword,
                                  ),
                                ),
                                const SizedBox(height: 5.0),
                                CustomTextField(
                                  key: const Key('registerCompanyField'),
                                  focusNode: companyNode,
                                  onChanged: (value) => companyName = value,
                                  decoration: const InputDecoration(
                                    labelText: 'Enter your Company name',
                                    hintText: 'Company name',
                                  ),
                                ),
                                const SizedBox(height: 5.0),
                                DropdownButtonFormField<String>(
                                  key: const Key('registerSalesPersonDropdown'),
                                  value: selectedSalesPerson,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Salesperson',
                                    hintText: 'Choose a salesperson',
                                  ),
                                  items: salesPersons.map((dynamic person) {
                                    return DropdownMenuItem<String>(
                                      value: person['id'],
                                      child: Text(person['name']),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedSalesPerson = newValue;
                                    });
                                  },
                                  validator: (value) => value == null
                                      ? 'Please select a salesperson'
                                      : null,
                                ),
                                if (_currentLocation != null)
                                  _mapLoading
                                      ? const CircularProgressIndicator()
                                      : Container(
                                          height: 300.0,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 20.0),
                                          child: FlutterMap(
                                            mapController: _mapController,
                                            options: MapOptions(
                                              center: _currentLocation,
                                              zoom: 15.0,
                                            ),
                                            children: [
                                              TileLayer(
                                                urlTemplate:
                                                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                subdomains: const [
                                                  'a',
                                                  'b',
                                                  'c'
                                                ],
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
                                        ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16.0),
                                  child: Material(
                                    color: value.loading
                                        ? Colors.grey
                                        : Theme.of(context).primaryColor,
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(5.0)),
                                    elevation: 0,
                                    child: MaterialButton(
                                      disabledColor: Colors.grey,
                                      key: const Key('registerSubmitButton'),
                                      onPressed: value.loading
                                          ? null
                                          : () async {
                                              await _submitRegister(
                                                firstName: firstName,
                                                lastName: lastName,
                                                phoneNumber: phoneNumber,
                                                password: password,
                                                companyName: companyName,
                                                confirmPassword: confirmPassword
                                              );
                                            },
                                      minWidth: 200.0,
                                      elevation: 0.0,
                                      height: 42.0,
                                      child: Text(
                                        value.loading
                                            ? S.of(context).loading
                                            : S.of(context).createAnAccount,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text('${S.of(context).or} '),
                                    InkWell(
                                      onTap: () {
                                        final canPop =
                                            ModalRoute.of(context)!.canPop;
                                        if (canPop) {
                                          Navigator.pop(context);
                                        } else {
                                          Navigator.of(context)
                                              .pushReplacementNamed(
                                                  RouteList.login);
                                        }
                                      },
                                      child: Text(
                                        S.of(context).loginToYourAccount,
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          decoration: TextDecoration.underline,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ));
  }
}
