import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel_agency/widgets/confirmed.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({Key? key, required String country, required String city, required String package, required String price, required String days}) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  List<String> _countries = [];
  String? _selectedCountry;
  String? _selectedPackage;
  String? _selectedCity;
  int? _price;
  int? _days;
  DateTime? _selectedDate;
  int _numberOfPersons = 1;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  Future<void> _fetchCountries() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('packages').get();

      final countries =
          snapshot.docs.map((doc) => doc['country'] as String).toSet().toList();

      setState(() {
        _countries = countries;
      });
    } catch (e) {
      print('Error fetching countries: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load countries. Please try again.')),
      );
    }
  }

  Future<void> _fetchPackageDetails() async {
    if (_selectedCountry == null) return;

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('packages')
          .where('country', isEqualTo: _selectedCountry)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        setState(() {
          _selectedPackage = doc['package'] as String;
          _selectedCity = doc['city'] as String;
          _price = doc['price'] as int;
          _days = doc['days'] as int;
        });
      }
    } catch (e) {
      print('Error fetching package details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load package details. Please try again.')),
      );
    }
  }

  void _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<bool> _processStripePayment() async {
    // This is a mock implementation. In a real app, you would integrate with Stripe SDK here.
    await Future.delayed(Duration(seconds: 2)); // Simulate network delay
    return true; // Always return success for this example
  }

  void _navigateToConfirmScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ConfirmScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPrice = (_price ?? 0) * _numberOfPersons;

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Page'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                items: _countries.map((String country) {
                  return DropdownMenuItem<String>(
                    value: country,
                    child: Text(country),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCountry = newValue;
                    _selectedPackage = null;
                    _selectedCity = null;
                    _price = null;
                    _days = null;
                  });
                  _fetchPackageDetails();
                },
                decoration: InputDecoration(
                  labelText: 'Select Country',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              if (_selectedCountry != null) ...[
                Text(
                  'Country: $_selectedCountry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'City: ${_selectedCity ?? "N/A"}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Package: ${_selectedPackage ?? "N/A"}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Duration: ${_days ?? "N/A"} days',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Total Price: $totalPrice',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(
                  'Select Date:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    _selectedDate == null
                        ? 'Select Date'
                        : 'Selected Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Number of Persons:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () {
                        if (_numberOfPersons > 1) {
                          setState(() {
                            _numberOfPersons--;
                          });
                        }
                      },
                    ),
                    Text(
                      '$_numberOfPersons',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          _numberOfPersons++;
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please select a date!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        bool paymentSuccess = await _processStripePayment();
                        if (paymentSuccess) {
                          String? userEmail =
                              FirebaseAuth.instance.currentUser?.email;
                          if (userEmail != null) {
                            await FirebaseFirestore.instance
                                .collection('bookings')
                                .add({
                              'country': _selectedCountry,
                              'city': _selectedCity,
                              'package': _selectedPackage,
                              'days': _days,
                              'price': totalPrice,
                              'date': _selectedDate,
                              'numberOfPersons': _numberOfPersons,
                              'email': userEmail,
                            });
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Payment successful!')),
                          );
                          _navigateToConfirmScreen();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Payment failed!')),
                          );
                        }
                      }
                    },
                    child: Text('Book Now with Stripe'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
