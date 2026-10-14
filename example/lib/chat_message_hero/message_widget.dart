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

class MessageWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration? decoration;

  bool get readOnly => onSubmitted == null;

  MessageWidget.input({
    super.key,
    required ValueChanged<String> this.onSubmitted,
    TextEditingController? controller,
    this.focusNode,
    this.decoration,
  }) : controller = controller ?? TextEditingController();

  MessageWidget.readOnly({super.key, required String text, this.decoration})
    : controller = TextEditingController(text: text),
      focusNode = null,
      onSubmitted = null;

  @override
  Widget build(BuildContext context) => TextField(
    readOnly: onSubmitted == null,
    controller: controller,
    focusNode: focusNode,
    onSubmitted: onSubmitted,
    decoration: decoration,
    textInputAction: TextInputAction.done,
  );
}
