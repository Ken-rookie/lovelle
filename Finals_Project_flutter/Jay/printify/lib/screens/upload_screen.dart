import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_file_preview/native_file_preview.dart';

import '../models/print_file.dart';
import '../models/print_order.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_title.dart';
import 'order_summary_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<PrintFileItem> files = [];
  String service = 'Documents';

  Future<void> pickFiles() async {
    final pickedFiles = await FilePicker.pickFiles();
    if (pickedFiles.isEmpty) return;
    final selectedFiles = await Future.wait(
      pickedFiles.map(
        (file) async => PrintFileItem(
          name: file.name,
          bytes: (await file.length()) ?? 0,
          extension: (file.extension ?? '').toLowerCase(),
          previewUri: file.uri.toString(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      files.addAll(selectedFiles);
    });
  }

  Future<void> previewFile(PrintFileItem file) async {
    final uri = file.previewUri;
    if (uri == null) {
      showPreviewMessage(
        'This file is unavailable for preview on this device.',
      );
      return;
    }

    try {
      await NativeFilePreview().previewFile(uri);
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'NO_APP_FOUND' =>
          'No app is installed to preview ${file.extension.toUpperCase()} files. '
              'Install a compatible viewer or convert the file to PDF.',
        'FILE_NOT_FOUND' =>
          'The selected file is no longer available. Upload it again to preview.',
        _ => 'Could not preview this file: ${error.message ?? error.code}',
      };
      showPreviewMessage(message);
    } on MissingPluginException {
      if (!mounted) return;
      showPreviewMessage(
        'File preview is available on Android and iOS. '
        'Use a mobile device to preview this file.',
      );
    }
  }

  void showPreviewMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload files',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose service',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: service,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: const [
              'Documents',
              'Photos',
              'ID & Passports',
              'Tarpaulin',
              'Stickers',
              'Others',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => service = v ?? service),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: pickFiles,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFF8BB8FF),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: Color(0xFF0866F5),
                    size: 44,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tap to upload or browse files',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'PDF, images, DOCX and PPTX (compatible viewer may be required)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(
            'Selected files (${files.length})',
            trailing: TextButton(
              onPressed: files.isEmpty ? null : () => setState(files.clear),
              child: const Text('Clear all'),
            ),
          ),
          const SizedBox(height: 8),
          if (files.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Your selected files will appear here.'),
              ),
            )
          else
            ...files.asMap().entries.map((entry) {
              final i = entry.key;
              final file = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: SelectedPrintFileTile(
                    file: file,
                    onPreview: () => previewFile(file),
                    onRemove: () => setState(() => files.removeAt(i)),
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Continue to print settings',
            icon: Icons.arrow_forward,
            onPressed: files.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrintSettingsScreen(
                          service: service,
                          files: List.of(files),
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class SelectedPrintFileTile extends StatelessWidget {
  const SelectedPrintFileTile({
    super.key,
    required this.file,
    required this.onPreview,
    required this.onRemove,
  });

  final PrintFileItem file;
  final VoidCallback onPreview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isPdf = file.extension == 'pdf';
    return ListTile(
      onTap: onPreview,
      leading: CircleAvatar(
        backgroundColor: isPdf
            ? const Color(0xFFFFE8E8)
            : const Color(0xFFE5F1FF),
        child: Icon(
          isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file_outlined,
          color: isPdf ? Colors.red : const Color(0xFF0866F5),
        ),
      ),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${file.extension.toUpperCase()} • ${file.readableSize} • Tap to preview',
      ),
      trailing: IconButton(
        tooltip: 'Remove ${file.name}',
        onPressed: onRemove,
        icon: const Icon(Icons.close),
      ),
    );
  }
}

class PrintSettingsScreen extends StatefulWidget {
  const PrintSettingsScreen({
    super.key,
    required this.service,
    required this.files,
  });
  final String service;
  final List<PrintFileItem> files;

  @override
  State<PrintSettingsScreen> createState() => _PrintSettingsScreenState();
}

class _PrintSettingsScreenState extends State<PrintSettingsScreen> {
  String size = 'A4';
  String orientation = 'Portrait';
  String color = 'Color';
  String sides = 'Single-sided';
  String paper = 'Standard (80 gsm)';
  int copies = 1;
  final notes = TextEditingController();

  double get estimatedSubtotal {
    const rate = 1.0;
    return widget.files.length * rate * copies;
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Widget choice(
    String title,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: options
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Print settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Files to print',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...widget.files.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            color: Color(0xFF0866F5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            f.readableSize,
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          choice(
            'Paper size',
            [
              'A4',
              'A3',
              'Letter',
              'Legal',
              'Long (8.5 × 13 in)',
              'Short (8.5 × 11 in)',
              'Custom',
            ],
            size,
            (v) => setState(() => size = v),
          ),
          const SizedBox(height: 16),
          choice(
            'Orientation',
            ['Portrait', 'Landscape'],
            orientation,
            (v) => setState(() => orientation = v),
          ),
          const SizedBox(height: 16),
          choice(
            'Color mode',
            ['Color', 'Black & White'],
            color,
            (v) => setState(() => color = v),
          ),
          const SizedBox(height: 16),
          choice(
            'Print sides',
            ['Single-sided', 'Double-sided'],
            sides,
            (v) => setState(() => sides = v),
          ),
          const SizedBox(height: 16),
          choice(
            'Paper type',
            ['Standard (80 gsm)', 'Premium (100 gsm)', 'Photo glossy', 'Matte'],
            paper,
            (v) => setState(() => paper = v),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Copies per file',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: copies > 1
                        ? () => setState(() => copies--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$copies',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: copies < 100
                        ? () => setState(() => copies++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Additional notes (optional)',
              hintText: 'Stapling, binding, special instructions...',
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Estimated subtotal',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${estimatedSubtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: Color(0xFF0866F5),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Estimate only. Server must calculate final price.',
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Review order',
            onPressed: () {
              final draft = PrintOrderDraft(
                service: widget.service,
                files: widget.files,
                paperSize: size,
                orientation: orientation,
                colorMode: color,
                sides: sides,
                paperType: paper,
                copies: copies,
                notes: notes.text.trim(),
                subtotal: estimatedSubtotal,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderSummaryScreen(draft: draft),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
