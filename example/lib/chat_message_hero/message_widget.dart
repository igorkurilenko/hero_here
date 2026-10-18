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

/// A message: a text field to type it in, or, once sent, its text where
/// that field would show it.
class MessageWidget extends StatelessWidget {
  final String? text;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;

  const MessageWidget.input({
    super.key,
    required TextEditingController this.controller,
    required ValueChanged<String> this.onSubmitted,
    this.focusNode,
    this.decoration,
  }) : text = null;

  const MessageWidget.readOnly({
    super.key,
    required String this.text,
    this.decoration,
  }) : controller = null,
       focusNode = null,
       onSubmitted = null;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    if (text == null) {
      return TextField(
        controller: controller,
        focusNode: focusNode,
        // Enter sends, and the field stays focused for the next message.
        onEditingComplete: () {},
        onSubmitted: onSubmitted,
        decoration: decoration,
        textInputAction: TextInputAction.done,
      );
    }

    // A sent message lays out and paints as a read-only text field would,
    // in a few elements rather than a field's 44, which a switch walks.
    final style = Theme.of(context).textTheme.bodyLarge!;
    return InputDecorator(
      decoration: decoration ?? const InputDecoration(),
      isEmpty: text.isEmpty,
      child: Text(
        text,
        style: style,
        // The field's line height, as EditableText forces it, so glyphs taller
        // than the line, as some scripts have, don't make the message taller.
        strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      ),
    );
  }
}
