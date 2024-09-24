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

  String? firstName, lastName, emailAddress, phoneNumber, password, companyName;
  RegisterType? _registerType = RegisterType.customer;
  bool isChecked = true;
  bool _mapLoading = true;
  List<dynamic> salesPersons = [];
  String? selectedSalesPerson;
  String? otpCode;
  bool otpVerified = false;
  bool isLoadingOtp = false;

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
    const String username = 'admin@negade.biz'; // Replace with your Basic Auth username
    const String password = '86Mk U4OH YX9g rgUI TlCZ 422w'; // Replace with your Basic Auth password
    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    final Uri uri = Uri.parse('https://negade.biz/wp-json/myplugin/v1/sales-persons');

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
          salesPersons=data;
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

    if (emailAddress== null || emailAddress!.isEmpty) {
     _showMessage('please enter you phone number');
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
      'to': emailAddress!,
      'len': '6',
      't': '2',
      'sender': 'Bzu',
    };

    final Uri uri = Uri.parse(url).replace(queryParameters: queryParams);
    printLog('Constructed URI: $uri');

    // Define the bearer token
    const String token = 'eyJhbGciOiJIUzI1NiJ9.eyJpZGVudGlmaWVyIjoiZThnZExTcGwySk1KbUwyWUFTWHl1SUdBMFA5ajF5ZloiLCJleHAiOjE4NzM2MjU5MzksImlhdCI6MTcxNTg1OTUzOSwianRpIjoiZjk3NTRlMDgtMWE1Ni00NWJmLWEyNGYtYWZlYjIwYjkyNmIyIn0.PWyhsGn17hprc5sOga_q_3gyIqMl-8AD6QdzcyxWkqM';

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
            otpCode = responseJson['response']['code'];
          });

         _showMessage('Otp sent successfuly');
          await _showOtpDialog(context);
        } else {
          _showMessage('Failed to send Otp');
        }
      } else {
        _showMessage('Failed to send Otp');
      }
    } catch (error, stackTrace) {
      printLog('Error occurred: $error');
      printLog('Stack trace: $stackTrace');
      _showMessage('Failed to send Otp');
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
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Verify OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Enter the OTP sent to your phone'),
                  const SizedBox(height: 20.0),

                  // OTP Input Field
                  PinCodeTextField(
                    appContext: context,
                    length: 6, // Set the length of OTP
                    onChanged: (value) {
                      otpCode = value;
                    },
                    onCompleted: (value) {
                      otpCode = value;
                    },
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(5),
                      fieldHeight: 50,
                      fieldWidth: 40,
                      activeFillColor: Colors.white,
                      selectedFillColor: Colors.grey.shade200,
                      inactiveFillColor: Colors.grey.shade100,
                      activeColor: Colors.blue,
                    ),
                    enableActiveFill: true,
                  ),

                  const SizedBox(height: 20.0),

                  // Verify Button
                  MaterialButton(
                    onPressed: () async {
                      // Call OTP verification API or logic here
                      bool result = await _verifyOtp(otpCode); // Assuming _verifyOtp is an async function

                      if (result) {
                        Navigator.of(context).pop(); // Close the dialog
                        _showMessage('OTP Verified'); // Show success message
                        setState(() {
                          otpVerified = true; // Set OTP verified flag
                        });
                      } else {
                        _showMessage('OTP incorrect'); // Show error message
                      }
                    },
                    color: Theme.of(context).primaryColor,
                    minWidth: double.infinity,
                    child: const Text('Verify', style: TextStyle(color: Colors.white)),
                  ),

                  const SizedBox(height: 10.0),

                  // Resend Button
                  TextButton(
                    onPressed: () {
                      // Logic to resend OTP
                      _resendOtp(); // Implement this function to resend OTP
                      setState(() {
                        otpCode = ''; // Clear the OTP field after resend
                      });
                    },
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  bool _verifyOtp(String input){
    return otpCode==input;
  }
  Future<void> _submitRegister({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? emailAddress,
    String? password,
    String? companyName,
    bool? isVendor,
  }) async {
    if (firstName == null ||
        lastName == null ||
        emailAddress == null ||
        password == null ||
        (showPhoneNumberWhenRegister &&
            requirePhoneNumberWhenRegister &&
            phoneNumber == null) ||
        companyName == null) {
      _showMessage(S.of(context).pleaseInputFillAllFields);
    } else if (isChecked == false) {
      _showMessage(S.of(context).pleaseAgreeTerms);
    } else {
      if (password.length < 8) {
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
            'username': emailAddress,
            'phone': emailAddress,
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
          'username': emailAddress,
          'phone': emailAddress,
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
          var resp=jsonDecode(response.body);
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
                            CustomTextField(
                              key: const Key('registerEmailField'),
                              focusNode: emailNode,
                              autofillHints: const [AutofillHints.email],
                              nextNode: firstNameNode,
                              controller: _emailController,
                              onChanged: (value) => emailAddress = value,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Phone Number'),
                              hintText: 'phone Number',
                            ),
                            const SizedBox(height: 5.0),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10.0),
                              child: MaterialButton(
                                key: const Key('requestOtpButton'),
                                onPressed: isLoadingOtp ? null : _requestOtp,
                                color: Theme.of(context).primaryColor,
                                child: isLoadingOtp
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        'Request OTP',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 5.0),
                            CustomTextField(
                              key: const Key('registerFirstNameField'),
                              autofillHints: const [AutofillHints.givenName],
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
                              autofillHints: const [AutofillHints.familyName],
                              focusNode: lastNameNode,
                              nextNode: showPhoneNumberWhenRegister
                                  ? phoneNumberNode
                                  : emailNode,
                              showCancelIcon: true,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) => lastName = value,
                              decoration: InputDecoration(
                                labelText: S.of(context).lastName,
                                hintText: S.of(context).enterYourLastName,
                              ),
                            ),
                            if (showPhoneNumberWhenRegister)
                              const SizedBox(height: 5.0),
                            if (showPhoneNumberWhenRegister)
                              CustomTextField(
                                key: const Key('registerPhoneField'),
                                focusNode: phoneNumberNode,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber
                                ],
                                nextNode: emailNode,
                                showCancelIcon: true,
                                onChanged: (value) => phoneNumber = value,
                                decoration: InputDecoration(
                                  labelText: S.of(context).phone,
                                  hintText: S.of(context).enterYourPhoneNumber,
                                ),
                                keyboardType: TextInputType.phone,
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
                              key: const Key('registerCompanyField'),
                              focusNode: companyNode,
                              onChanged: (value) => companyName = value,
                              decoration: const InputDecoration(
                                labelText: 'Enter your Company name ',
                                hintText: 'Company name ',
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
                            if (kVendorConfig.vendorRegister &&
                                (appModel.isMultivendor ||
                                    ServerConfig().isListeoType))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${S.of(context).registerAs}:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                    Row(
                                      children: [
                                        Radio<RegisterType>(
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          value: RegisterType.customer,
                                          groupValue: _registerType,
                                          onChanged: (RegisterType? value) {
                                            setState(() {
                                              _registerType = value;
                                            });
                                          },
                                        ),
                                        Text(
                                          S.of(context).customer,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        )
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Radio<RegisterType>(
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          value: RegisterType.vendor,
                                          groupValue: _registerType,
                                          onChanged: (RegisterType? value) {
                                            setState(() {
                                              _registerType = value;
                                            });
                                          },
                                        ),
                                        Text(
                                          S.of(context).vendor,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        )
                                      ],
                                    ),
                                  ],
                                ),
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
                                            subdomains: const ['a', 'b', 'c'],
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                width: 80.0,
                                                height: 80.0,
                                                point: _currentLocation!,
                                                builder: (ctx) => const Icon(
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
                            RichText(
                              maxLines: 2,
                              text: TextSpan(
                                text: S.of(context).bySignup,
                                style: Theme.of(context).textTheme.bodyLarge,
                                children: <TextSpan>[
                                  TextSpan(
                                    text: S.of(context).agreeWithPrivacy,
                                    style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        decoration: TextDecoration.underline),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => FluxNavigate.push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const PrivacyTermScreen(
                                                showAgreeButton: false,
                                              ),
                                            ),
                                            forceRootNavigator: true,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5.0),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Material(
                                color: otpVerified?Theme.of(context).primaryColor:Colors.grey,
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(5.0)),
                                elevation: 0,
                                child: MaterialButton(
                                  disabledColor: Colors.grey,
                                  key: const Key('registerSubmitButton'),
                                  onPressed: value.loading == true && !otpVerified
                                      ? null
                                      : () async {
                                          await _submitRegister(
                                            firstName: firstName,
                                            lastName: lastName,
                                            phoneNumber: phoneNumber,
                                            emailAddress: emailAddress,
                                            password: password,
                                            companyName: companyName,
                                            isVendor: _registerType ==
                                                RegisterType.vendor,
                                          );
                                        },
                                  minWidth: 200.0,
                                  elevation: 0.0,
                                  height: 42.0,
                                  child: Text(
                                    otpVerified?
                                    value.loading == true
                                        ? S.of(context).loading
                                        : S.of(context).createAnAccount:'Verify Phone',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    '${S.of(context).or} ',
                                  ),
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
      ),
    );
  }
}