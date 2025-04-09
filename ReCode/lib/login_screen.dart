import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'bottom_navigation.dart';

class LoginScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Pushes groups to extremes
          children: [
            // SVG logo (PLACEHOLDER)
            Row(
              children: [
                SvgPicture.asset (
                  'assets/icons/logo.svg',
                  width: 30,
                  height: 25,
                ),
                
                SizedBox(width: 10),
                
                Text(
                  'ReCode',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 4,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        
        children: [
          
          Spacer(flex: 1),

          Column(
            children: [
              Icon(Icons.lock_open, size: 75, color: Colors.blue),
              Text(
                "Welcome to ReCode", 
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),       
          
          Spacer(flex: 1),

          Padding(
            padding: EdgeInsets.all(20), // 20px space on ALL sides
            child: Column(
              children: [
                // Button 1
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BottomNavigation(),
                      ),
                    );
                  },
                  child: Text("Log-in"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                SizedBox(height: 10),
                // Button 2
                ElevatedButton(
                  onPressed: () {
                    // Add Sign-in functionality here
                  },
                  child: Text("Sign-in"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20)
          ],
        ),
      );
  }
}
