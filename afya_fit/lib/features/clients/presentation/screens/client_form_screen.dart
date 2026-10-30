import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/access/api_errors.dart';
import 'package:afya_fit/features/clients/providers/client_provider.dart';

class ClientFormScreen extends HookConsumerWidget {
  final String? clientId;
  final Map<String, dynamic>? client;

  const ClientFormScreen({
    super.key,
    this.clientId,
    this.client,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = clientId != null;
    final formKey = GlobalKey<FormState>();
    
    final firstNameController = TextEditingController(text: client?['first_name'] ?? '');
    final lastNameController = TextEditingController(text: client?['last_name'] ?? '');
    final emailController = TextEditingController(text: client?['email'] ?? '');
    final phoneController = TextEditingController(text: client?['phone'] ?? '');
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Client' : 'Add Client'),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isEditing, // Email cannot be changed when editing
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (!isEditing) ...[
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      final clientData = {
                        'first_name': firstNameController.text.trim(),
                        'last_name': lastNameController.text.trim(),
                        'email': emailController.text.trim(),
                        if (!isEditing) 'password': passwordController.text,
                        if (phoneController.text.isNotEmpty) 'phone': phoneController.text.trim(),
                      };

                      if (isEditing && clientId != null) {
                        await ref.read(clientRepositoryProvider).updateClient(
                              clientId!,
                              clientData,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Client updated successfully')),
                          );
                          Navigator.pop(context);
                        }
                      } else {
                        await ref.read(clientRepositoryProvider).createClient(clientData);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Client created successfully')),
                          );
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      await showApiError(context, ref, e);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditing ? 'Update Client' : 'Create Client'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

