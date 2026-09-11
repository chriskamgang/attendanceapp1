import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/trip_controller.dart';

class TripView extends GetView<TripController> {
  const TripView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TripView'), centerTitle: true),
      body: const Center(
        child: Text('TripView is working', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
