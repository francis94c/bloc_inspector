extension StringExtension on String {
  String get humanized =>
      replaceAll('_\$', '').replaceAll(RegExp(r'Impl$'), '');
}
