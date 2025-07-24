import 'package:flutter/material.dart';

class PaymentSuccessPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(''),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: Icon(Icons.share), onPressed: () {})],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 10),
            Text('Payment Success!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20)),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _row('Ref Number', '00086752637'),
                  _row('Payment Time', '25-03-2023, 13:22:19'),
                  _row('Payment Method', 'Bank Transfer'),
                  _row('Sender Name', 'Antonio Roberto'),
                  _row('Amount', '\$2'),
                  _row('Admin Fee', '\$0.5'),
                  _row('Payment Status', 'Success', valueColor: Colors.green),
                ],
              ),
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.picture_as_pdf),
              label: Text('Get PDF Receipt'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                side: BorderSide(color: Colors.blue),
              ),
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
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

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.black54)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      );
}