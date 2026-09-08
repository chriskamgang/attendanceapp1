import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/chatdetail_controller.dart';

class ChatdetailView extends GetView<ChatdetailController> {
  const ChatdetailView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ChatdetailView'), centerTitle: true),
      body: const Center(
        child: Text(
          'ChatdetailView is working',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
