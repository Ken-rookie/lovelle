import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'add_edit_pet_screen.dart';

class MyPetsScreen extends StatelessWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Pets')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 14),
              child: Text(
                '${demoPets.length} sample profiles · edits are preview-only',
                style: const TextStyle(
                  color: PawcheColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: demoPets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .74,
              ),
              itemBuilder: (context, index) {
                final pet = demoPets[index];
                return Card(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: PawcheColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: PawcheColors.blush,
                              child: Center(
                                child: PetAvatar(
                                  type: pet.type,
                                  size: 112,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filledTonal(
                                tooltip: 'Edit ${pet.name}',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEditPetScreen(
                                      existingName: pet.name,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pet.name,
                              style: const TextStyle(
                                color: PawcheColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              pet.breed,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PawcheColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              pet.age,
                              style: const TextStyle(
                                color: PawcheColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditPetScreen(),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add New Pet'),
            ),
          ],
        ),
      );
}
