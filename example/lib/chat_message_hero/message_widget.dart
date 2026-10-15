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

class MessageWidget extends StatefulWidget {
  final String? text;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;

  bool get readOnly => onSubmitted == null;

  const MessageWidget.input({
    super.key,
    required ValueChanged<String> this.onSubmitted,
    this.focusNode,
    this.decoration,
  }) : text = null;

  const MessageWidget.readOnly({
    super.key,
    required String this.text,
    this.decoration,
  }) : focusNode = null,
       onSubmitted = null;

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget> {
  // Owned by the state, so a rebuild keeps what is typed.
  late final _controller = TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(MessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.text;
    if (text != null && text != _controller.text) _controller.text = text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    readOnly: widget.readOnly,
    controller: _controller,
    focusNode: widget.focusNode,
    onSubmitted: widget.onSubmitted,
    decoration: widget.decoration,
    textInputAction: TextInputAction.done,
  );
}
