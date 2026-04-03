import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    title: 'ReadLoop',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: Scaffold(
      appBar: AppBar(
        title: Text('ReadLoop'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text('ReadLoop App', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Authentication & Books Working!', style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: Text('Test App'),
            ),
          ],
        ),
      ),
    ),
  ));
}
