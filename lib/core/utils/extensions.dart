import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String get formattedDate => DateFormat('MMM dd, yyyy').format(this);
  String get formattedTime => DateFormat('HH:mm').format(this);
  String get formattedDateTime =>
      DateFormat('MMM dd, yyyy • HH:mm').format(this);
}
