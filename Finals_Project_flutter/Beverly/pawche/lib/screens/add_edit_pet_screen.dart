import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AddEditPetScreen extends StatefulWidget {
  final String? existingName;

  const AddEditPetScreen({super.key, this.existingName});

  @override
  State<AddEditPetScreen> createState() => _AddEditPetScreenState();
}

class _AddEditPetScreenState extends State<AddEditPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  String _type = 'Dog';
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    _name.text = widget.existingName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDate:
          _birthday ?? DateTime(today.year - 2, today.month, today.day),
    );
    if (date != null) setState(() => _birthday = date);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingName != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Pet' : 'Add Pet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Center(
              child: Text(
                'Add details to personalize your pet’s profile. Changes are preview-only and are not saved yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PawcheColors.muted),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 134,
                    height: 134,
                    decoration: const BoxDecoration(
                      color: PawcheColors.blush,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: PetAvatar(type: _type, size: 134),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: PawcheColors.pink,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Change pet photo',
                      constraints: const BoxConstraints.tightFor(
                        width: 38,
                        height: 38,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => showMessage(
                        context,
                        'Photo uploads require image-picker setup.',
                      ),
                      icon: const Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Dog',
                  label: Text('Dog'),
                  icon: Icon(Icons.pets_rounded),
                ),
                ButtonSegment(
                  value: 'Cat',
                  label: Text('Cat'),
                  icon: Icon(Icons.cruelty_free_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Pet Name',
                prefixIcon: Icon(Icons.pets_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your pet’s name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _breed,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Breed',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _selectBirthday,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _birthday == null
                    ? 'Select birthdate (optional)'
                    : '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}',
              ),
            ),
            const SizedBox(height: 22),
            PinkButton(
              label: 'Save',
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                showMessage(
                  context,
                  'Demo only: connect the pets table to save this profile.',
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
