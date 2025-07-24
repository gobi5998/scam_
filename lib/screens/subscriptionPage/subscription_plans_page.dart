
import 'package:flutter/material.dart';
import 'package:security_alert/screens/subscriptionPage/payment_validation.dart';


class SubscriptionPlansPage extends StatefulWidget {
  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  String? selectedSector;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription Plans'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Sector', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedSector,
              hint: Text('Select a Sector Type'),
              items: ['Banking', 'ATM', 'Online Payment', 'Fraud']
                  .map((sector) => DropdownMenuItem(
                        value: sector,
                        child: Text(sector),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => selectedSector = val),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Subscribe to Premium Alerts:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text('Basic', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text(' . '),
                Text('Advance', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text(' . '),
                Text('Premium', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('\$2', style: TextStyle(fontSize: 40, color: Colors.blue, fontWeight: FontWeight.bold)),
                    Text('User/Month', style: TextStyle(color: Colors.black54)),
                    SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _feature('Notifications on banking trojans'),
                        _feature('ATM skimmers'),
                        _feature('Online payment fraud'),
                        _feature('New instant attack vectors'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedSector == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PaymentValidationPage()),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Continue', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(String text) => Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 14)),
        ],
      );
}
