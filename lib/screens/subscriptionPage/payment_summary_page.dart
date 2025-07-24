import 'package:flutter/material.dart';
import 'payment_success_page.dart';

class PaymentSummaryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: Icon(Icons.more_vert), onPressed: () {})],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('\$2', style: TextStyle(fontSize: 40, color: Colors.blue, fontWeight: FontWeight.bold)),
                  Text('User/Month', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            SizedBox(height: 30),
            _row('Ref Number', '00086752637'),
            _row('Payment Time', '25-03-2023, 13:22:19'),
            _row('Payment Method', 'Bank Transfer'),
            _row('Sender Name', 'Antonio Roberto'),
            _row('Amount', '\$2'),
            _row('Admin Fee', '\$0.5'),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaymentSuccessPage()),
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

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.black54)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}