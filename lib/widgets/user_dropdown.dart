import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';

/// قائمة منسدلة لاختيار مستخدم بدور معيّن (زبون / موظف تنفيذ ...).
class UserDropdown extends StatelessWidget {
  final UserRole role;
  final String? selectedUid;
  final String label;
  final IconData icon;
  final bool optional;
  final ValueChanged<AppUser?> onChanged;

  const UserDropdown({
    super.key,
    required this.role,
    required this.selectedUid,
    required this.label,
    required this.onChanged,
    this.icon = Icons.person_outline,
    this.optional = true,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<AppUser>>(
      stream: fs.usersByRole(role),
      builder: (context, snapshot) {
        final users = snapshot.data ?? [];
        // قيمة آمنة: تُهمل إن لم تعد موجودة في القائمة.
        final value =
            users.any((u) => u.uid == selectedUid) ? selectedUid : null;
        return DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceAlt,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
          items: [
            if (optional)
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('بدون تحديد'),
              ),
            ...users.map((u) => DropdownMenuItem<String?>(
                  value: u.uid,
                  child: Text(u.name.isEmpty ? u.email : u.name),
                )),
          ],
          onChanged: (uid) {
            if (uid == null) {
              onChanged(null);
            } else {
              onChanged(users.firstWhere((u) => u.uid == uid));
            }
          },
          validator: optional
              ? null
              : (v) => v == null ? 'الرجاء الاختيار' : null,
        );
      },
    );
  }
}
