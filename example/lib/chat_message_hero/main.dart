// Copyright 2024 Igor Kurilenko
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:example/chat_message_hero/message_widget.dart';
import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import 'message.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Chat Message Example',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: const HeroHereExample(),
  ),
);

class HeroHereExample extends StatefulWidget {
  const HeroHereExample({super.key});

  @override
  State<HeroHereExample> createState() => _HeroHereExampleState();
}

class _HeroHereExampleState extends State<HeroHereExample> {
  final _messages = <Message>[];
  // The message being typed. Sending it starts a new one, so the input's
  // hero hands its tag to the sent message, which flies into the list.
  var _draft = Message();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) => HeroHereSwitcher(
    child: Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(forceMaterialTransparency: true),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _messages.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _buildMessage(_messages[index]),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: _buildMessageInput(),
      ),
    ),
  );

  Widget _buildMessage(Message message) => HeroHere(
    tag: '$message',
    key: ValueKey('published-$message'),
    child: MessageWidget.readOnly(
      text: message.textOrEmpty,
      decoration: const InputDecoration(
        border: OutlineInputBorder(borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _buildMessageInput() => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HeroHere(
        tag: '$_draft',
        key: ValueKey('$_draft'),
        child: MessageWidget.input(
          focusNode: _focusNode,
          onSubmitted: _onMessageSubmitted,
          decoration: const InputDecoration(
            hintText: 'Message',
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(32)),
            ),
          ),
        ),
      ),
    ),
  );

  void _onMessageSubmitted(String text) {
    if (text.isEmpty) return;

    _focusNode.unfocus();

    setState(() {
      _messages.add(_draft..text = text);
      _draft = Message();
    });

    afterBuild(() {
      _focusNode.requestFocus();
      _scrollToBottom();
    });
  }

  void _scrollToBottom() => _scrollController.animateTo(
    _scrollController.position.maxScrollExtent,
    duration: HeroHere.defaultFlightAnimationDuration,
    curve: HeroHere.defaultFlightAnimationCurve,
  );
}

extension _State on State {
  void afterBuild(VoidCallback cb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cb());
    });
  }
}
