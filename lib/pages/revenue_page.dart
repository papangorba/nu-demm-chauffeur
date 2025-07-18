import 'package:flutter/material.dart';
import '../theme/theme.dart'; // adapte si nécessaire

class RevenuePage extends StatefulWidget {
  const RevenuePage({Key? key}) : super(key: key);

  @override
  _RevenuePageState createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  double totalRevenue = 125000; // exemple
  double receivedAmount = 100000; // exemple

  List<Map<String, dynamic>> paymentHistory = [
    {
      "client": "Amadou Ndiaye",
      "price": 2500,
      "time": "10:30",
      "destination": "Dakar Plateau"
    },
    {
      "client": "Fatou Diop",
      "price": 3000,
      "time": "14:15",
      "destination": "Parc Hann"
    },
    {
      "client": "Moussa Fall",
      "price": 2000,
      "time": "17:45",
      "destination": "Yoff"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Revenus du jour",
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRevenueCard("Total des courses", totalRevenue),
            SizedBox(height: 12),
            _buildRevenueCard("Montant reçu", receivedAmount),
            SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Historique des paiements",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: paymentHistory.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  var item = paymentHistory[index];
                  return ListTile(
                    leading: Icon(Icons.person, color: AppColors.secondary),
                    title: Text(item["client"]),
                    subtitle: Text("${item["destination"]} à ${item["time"]}"),
                    trailing: Text("${item["price"]} FCFA",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700])),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(String title, double amount) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.secondary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.credit_card, color: AppColors.white),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 26,fontWeight: FontWeight.bold, color: AppColors.secondary)),
                SizedBox(height: 4),
                Text(
                  "$amount FCFA",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
