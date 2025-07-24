import 'package:flutter/material.dart';
import 'payment_summary_page.dart';

class PaymentValidationPage extends StatefulWidget {
  @override
  State<PaymentValidationPage> createState() => _PaymentValidationPageState();
}

class _PaymentValidationPageState extends State<PaymentValidationPage> {
  bool isDebit = true;
  final cardNumberController = TextEditingController(text: '1234 5678 8765 4765');
  final cardHolderController = TextEditingController(text: 'IVAN IVANOV');
  final expiryController = TextEditingController(text: '11/23');
  final cvcController = TextEditingController(text: '123');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Validation'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(icon: Icon(Icons.more_vert, color: Colors.black), onPressed: () {})],
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Card visual
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [Colors.purple, Colors.deepPurpleAccent]),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Row(
                      children: [
                        Icon(Icons.credit_card, color: Colors.white, size: 40),
                        SizedBox(width: 8),
                        Icon(Icons.credit_card, color: Colors.orange, size: 40),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 30,
                    child: Text('**** **** **** 4765', style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 10,
                    child: Text('11/23', style: TextStyle(color: Colors.white)),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 10,
                    child: Text('IVAN IVANOV', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    value: true,
                    groupValue: isDebit,
                    onChanged: (v) => setState(() => isDebit = v!),
                    title: Text('Debit card'),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    value: false,
                    groupValue: isDebit,
                    onChanged: (v) => setState(() => isDebit = v!),
                    title: Text('Credit card'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: cardNumberController,
              decoration: InputDecoration(labelText: 'Card number', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            TextField(
              controller: cardHolderController,
              decoration: InputDecoration(labelText: 'Card holder', border: OutlineInputBorder()),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: expiryController,
                    decoration: InputDecoration(labelText: 'Expiry date', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: cvcController,
                    decoration: InputDecoration(labelText: 'CVC', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaymentSummaryPage()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Confirm & Pay \$2.5', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
