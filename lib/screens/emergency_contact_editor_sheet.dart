import 'dart:async';

import 'package:flutter/material.dart';

import '../services/emergency_contacts_service.dart';
import '../services/username_service.dart';
import '../ui_components.dart';

Future<bool> showEmergencyContactEditorSheet(
  BuildContext context, {
  EmergencyContact? contact,
  bool suggestPrimary = false,
  required Future<void> Function(EmergencyContact contact) onSave,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: contact?.name ?? '');
  final phoneController =
      TextEditingController(text: contact?.phoneNumber ?? '');
  final usernameController =
      TextEditingController(text: contact?.username ?? '');
  final usernameService = UsernameService();
  var isPrimary = contact?.isPrimary ?? suggestPrimary;
  var isSaving = false;
  var checkingUsername = false;
  var usernameSuggestions = <ProtegoUserSuggestion>[];
  String? usernameError;
  Timer? usernameDebounce;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final isDark = theme.brightness == Brightness.dark;

      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> loadUsernameSuggestions(String value) async {
            final query = value.trim();
            if (query.length < 2) {
              setModalState(() {
                checkingUsername = false;
                usernameError = null;
                usernameSuggestions = <ProtegoUserSuggestion>[];
              });
              return;
            }

            setModalState(() {
              checkingUsername = true;
            });

            try {
              final results = await usernameService.searchUsers(query);
              if (!sheetContext.mounted) {
                return;
              }
              setModalState(() {
                checkingUsername = false;
                usernameError = null;
                usernameSuggestions = results;
              });
            } catch (_) {
              if (!sheetContext.mounted) {
                return;
              }
              setModalState(() {
                checkingUsername = false;
                usernameError = null;
                usernameSuggestions = <ProtegoUserSuggestion>[];
              });
            }
          }

          ProtegoUserSuggestion? resolveExactUser(String username) {
            for (final item in usernameSuggestions) {
              if (item.username == username) {
                return item;
              }
            }
            return null;
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                MediaQuery.of(sheetContext).viewInsets.bottom + 12,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
                  ),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF353535)
                                    : const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  contact == null
                                      ? Icons.person_add_alt_1
                                      : Icons.edit_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact == null
                                          ? 'Add emergency contact'
                                          : 'Update contact',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Save someone you can reach quickly during an emergency.',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFA3A3A3)
                                            : const Color(0xFF6B7280),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tip: add a close family member first and mark them as primary.',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          buildTextField(
                            context: sheetContext,
                            label: 'Protego username',
                            hint: '',
                            controller: usernameController,
                            onChanged: (value) {
                              setModalState(() {
                                usernameError = null;
                              });
                              usernameDebounce?.cancel();
                              usernameDebounce =
                                  Timer(const Duration(milliseconds: 320), () {
                                loadUsernameSuggestions(value);
                              });
                            },
                            validator: (value) {
                              final normalized = (value ?? '').trim();
                              if (normalized.isEmpty) {
                                return 'Username is required';
                              }
                              if (!RegExp(r'^[a-z0-9._]{3,24}$')
                                  .hasMatch(normalized)) {
                                return 'Username must be 3-24 chars (a-z, 0-9, ., _)';
                              }
                              return null;
                            },
                          ),
                          if (checkingUsername)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Looking for users...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFA3A3A3)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          if (usernameSuggestions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: usernameSuggestions
                                    .map(
                                      (item) => ActionChip(
                                        avatar:
                                            const Icon(Icons.person, size: 16),
                                        label: Text('@${item.username}'),
                                        onPressed: () {
                                          usernameController.text =
                                              item.username;
                                          usernameController.selection =
                                              TextSelection.collapsed(
                                            offset: item.username.length,
                                          );
                                          if (nameController.text
                                              .trim()
                                              .isEmpty) {
                                            nameController.text =
                                                (item.displayName ??
                                                        item.username)
                                                    .trim();
                                          }
                                          if (phoneController.text
                                                  .trim()
                                                  .isEmpty &&
                                              (item.phoneNumber ?? '')
                                                  .trim()
                                                  .isNotEmpty) {
                                            phoneController.text =
                                                item.phoneNumber!.trim();
                                          }
                                          setModalState(() {
                                            usernameError = null;
                                            usernameSuggestions =
                                                <ProtegoUserSuggestion>[];
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (usernameError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                usernameError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          buildTextField(
                            context: sheetContext,
                            label: 'Contact name',
                            hint: '',
                            controller: nameController,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter a contact name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          buildTextField(
                            context: sheetContext,
                            label: 'Phone number',
                            hint: '',
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              final normalized = (value ?? '').trim();
                              if (normalized.isEmpty) {
                                return 'Enter a phone number';
                              }
                              if (normalized.length < 8) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111111)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Primary contact',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'This person will appear first in your emergency list.',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFA3A3A3)
                                              : const Color(0xFF6B7280),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: isPrimary,
                                  onChanged: (value) {
                                    setModalState(() => isPrimary = value);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () =>
                                          Navigator.of(sheetContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: buildButton(
                                  context: sheetContext,
                                  label: contact == null
                                      ? 'Save contact'
                                      : 'Update contact',
                                  isLoading: isSaving,
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!
                                              .validate()) {
                                            return;
                                          }

                                          final normalizedUsername =
                                              usernameService.normalizeForInput(
                                                  usernameController.text
                                                      .trim());
                                          var matchedUser = resolveExactUser(
                                              normalizedUsername);
                                          if (matchedUser == null) {
                                            final remoteSuggestions =
                                                await usernameService
                                                    .searchUsers(
                                              normalizedUsername,
                                              limit: 10,
                                            );
                                            for (final item
                                                in remoteSuggestions) {
                                              if (item.username ==
                                                  normalizedUsername) {
                                                matchedUser = item;
                                                break;
                                              }
                                            }
                                          }

                                          if (matchedUser == null) {
                                            setModalState(() {
                                              usernameError =
                                                  'Only existing Protego users can be added.';
                                            });
                                            return;
                                          }

                                          if (nameController.text
                                              .trim()
                                              .isEmpty) {
                                            nameController.text =
                                                (matchedUser.displayName ??
                                                        matchedUser.username)
                                                    .trim();
                                          }
                                          if (phoneController.text
                                                  .trim()
                                                  .isEmpty &&
                                              (matchedUser.phoneNumber ?? '')
                                                  .trim()
                                                  .isNotEmpty) {
                                            phoneController.text =
                                                matchedUser.phoneNumber!.trim();
                                          }
                                          if (phoneController.text
                                              .trim()
                                              .isEmpty) {
                                            setModalState(() {
                                              usernameError =
                                                  'Selected user has no phone number set yet.';
                                            });
                                            return;
                                          }

                                          setModalState(() => isSaving = true);
                                          try {
                                            await onSave(
                                              EmergencyContact(
                                                id: contact?.id,
                                                userId: contact?.userId ?? '',
                                                name:
                                                    nameController.text.trim(),
                                                phoneNumber:
                                                    phoneController.text.trim(),
                                                username: normalizedUsername,
                                                profilePhotoPath: matchedUser
                                                    .profilePhotoPath,
                                                isPrimary: isPrimary,
                                              ),
                                            );
                                            if (!sheetContext.mounted) {
                                              return;
                                            }
                                            Navigator.of(sheetContext)
                                                .pop(true);
                                          } catch (e) {
                                            if (!sheetContext.mounted) {
                                              return;
                                            }
                                            final raw = e.toString();
                                            final cleaned = raw
                                                .replaceFirst('Bad state: ', '')
                                                .replaceFirst('Exception: ', '')
                                                .trim();
                                            ScaffoldMessenger.of(sheetContext)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  cleaned.isEmpty
                                                      ? 'Could not save contact. Please try again.'
                                                      : cleaned,
                                                ),
                                              ),
                                            );
                                          } finally {
                                            if (sheetContext.mounted) {
                                              setModalState(
                                                  () => isSaving = false);
                                            }
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  usernameDebounce?.cancel();

  return saved ?? false;
}
