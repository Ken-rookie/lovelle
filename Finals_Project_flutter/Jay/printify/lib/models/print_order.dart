import 'print_file.dart';

class PrintOrderDraft {
  PrintOrderDraft({
    required this.service,
    required this.files,
    required this.paperSize,
    required this.orientation,
    required this.colorMode,
    required this.sides,
    required this.paperType,
    required this.copies,
    required this.notes,
    required this.subtotal,
  });

  final String service;
  final List<PrintFileItem> files;
  final String paperSize;
  final String orientation;
  final String colorMode;
  final String sides;
  final String paperType;
  final int copies;
  final String notes;
  final double subtotal;

  Map<String, dynamic> toJson() => {
    'service_type': service,
    'paper_size': paperSize,
    'orientation': orientation,
    'color_mode': colorMode,
    'print_sides': sides,
    'paper_type': paperType,
    'copies': copies,
    'notes': notes,
    'subtotal': subtotal,
    'currency': 'PHP',
    'files': files.map((f) => f.toJson()).toList(),
  };
}
