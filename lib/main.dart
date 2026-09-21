import 'package:e_comerce_appliction/provider/authprovider.dart';
import 'package:e_comerce_appliction/provider/productprovider.dart';
import 'package:e_comerce_appliction/provider/userprovider.dart';
import 'package:e_comerce_appliction/screens/flashe_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Supabase.initialize(
    url: 'https://fujuqrcudkluovpcqbfl.supabase.co',
    publishableKey: 'sb_publishable_U-xo_RAYLv3OIED5fMFu1A_mAWGIvlm',
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (contex) => AthenDiction()),
        ChangeNotifierProvider(create: (contex) => Productprovider()),
        ChangeNotifierProvider(create: (contex)=> UserProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primaryColor: Colors.blue),
      home: const FlasheScreen(),
    );
  }
}
