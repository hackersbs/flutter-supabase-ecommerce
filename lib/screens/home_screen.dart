import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              context.read<AthenDiction>().logOut(context);
            },
            child: Text('hellow'),
          ),
        ],
      ),
    );
  }
}
