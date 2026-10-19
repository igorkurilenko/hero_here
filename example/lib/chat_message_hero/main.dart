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

import 'package:flutter/material.dart';
import 'package:hero_here/hero_here.dart';

import 'message.dart';
import 'message_widget.dart';

void main() => runApp(
  MaterialApp(
    title: 'HeroHere Chat Message Example',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    home: const ChatMessageExample(),
  ),
);

class ChatMessageExample extends StatefulWidget {
  const ChatMessageExample({super.key});

  @override
  State<ChatMessageExample> createState() => _ChatMessageExampleState();
}

class _ChatMessageExampleState extends State<ChatMessageExample> {
  final _messages = <Message>[];
  // The message being typed. Sending it starts a new one, so the input's
  // hero hands its tag to the sent message, which flies into the list.
  var _draft = Message();
  // The input stays the same field through every send, so it keeps its focus
  // and what is typed. Only the hero over it changes with the draft.
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HeroHereSwitcher(
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(forceMaterialTransparency: true),
      // The scaffold shrinks its body above the keyboard, so the input rides
      // on the keyboard. It reads the keyboard's height below the switcher, so
      // the keyboard sliding in doesn't rebuild the switcher and run a switch.
      body: Builder(
        builder: (context) => Column(
          children: [
            Expanded(
              // The input below the list keeps it off the screen's bottom edge.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const _KeepNewestInView(),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: _buildMessage(_messages[index]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: _buildMessageInput(),
            ),
          ],
        ),
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
      child: Stack(
        children: [
          // Where the draft flies from once sent. It paints nothing: the
          // field shows the text until the flight's shuttle does.
          Positioned.fill(
            child: HeroHere(
              tag: '$_draft',
              key: ValueKey('$_draft'),
              child: const SizedBox.expand(),
            ),
          ),
          MessageWidget.input(
            controller: _inputController,
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
        ],
      ),
    ),
  );

  void _onMessageSubmitted(String text) {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_draft..text = text);
      _draft = Message();
    });

    // The message flies after this frame, so the field shows it until then,
    // and keeps anything typed after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final value = _inputController.value;
      if (!value.text.startsWith(text)) return;
      _inputController.value = value.replaced(
        TextRange(start: 0, end: text.length),
        '',
      );
    });

    // The list scrolls to the message after the frame of the send and the
    // next one, by when the message's flight is under way.
    _afterTwoFrames(_scrollToBottom);
  }

  void _scrollToBottom() => _scrollController.animateTo(
    _scrollController.position.maxScrollExtent,
    duration: HeroHere.defaultFlightAnimationDuration,
    curve: HeroHere.defaultFlightAnimationCurve,
  );

  /// Runs [work] after this frame and the next.
  void _afterTwoFrames(VoidCallback work) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => work());
    });
  }
}

/// Keeps a list that shows its newest message showing it when its viewport
/// changes size, as when the keyboard opens or closes. A list scrolled back to
/// older messages stays where it is.
class _KeepNewestInView extends ScrollPhysics {
  const _KeepNewestInView({super.parent});

  @override
  _KeepNewestInView applyTo(ScrollPhysics? ancestor) =>
      _KeepNewestInView(parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final showedNewest = oldPosition.extentAfter < 1;
    final resized =
        oldPosition.viewportDimension != newPosition.viewportDimension;
    if (showedNewest && resized) return newPosition.maxScrollExtent;
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
