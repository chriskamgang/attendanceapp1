import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/seeting_controller.dart';

class SeetingView extends GetView<SeetingController> {
  const SeetingView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SeetingView'), centerTitle: true),
      body: const Center(
        child: Text('SeetingView is working', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}
