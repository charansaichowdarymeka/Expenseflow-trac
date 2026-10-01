import 'package:flutter/material.dart';

class AppText {
  static Widget heading(String text, {TextStyle? style, TextAlign? textAlign}) =>
      Text(text, textAlign: textAlign, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700).merge(style));

  static Widget subheading(String text, {TextStyle? style, TextAlign? textAlign}) =>
      Text(text, textAlign: textAlign, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600).merge(style));

  static Widget title(String text, {TextStyle? style, TextAlign? textAlign}) =>
      Text(text, textAlign: textAlign, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600).merge(style));

  static Widget body(String text, {TextStyle? style, TextAlign? textAlign}) =>
      Text(text, textAlign: textAlign, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400).merge(style));

  static Widget caption(String text, {TextStyle? style, TextAlign? textAlign}) =>
      Text(text, textAlign: textAlign, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400).merge(style));

  static Widget small(String text, {TextStyle? style, TextAlign? textAlign}) =>
      Text(text, textAlign: textAlign, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400).merge(style));
}
