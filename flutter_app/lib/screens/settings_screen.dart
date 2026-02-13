import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';
import '../services/wake_word_service.dart';
import '../services/camera_service.dart';
import '../services/onnx_service.dart';

/// Settings screen (All features)
/// Allows user to customize speech, detection, haptic, and navigation settings
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Speech Settings
              _buildSectionHeader(context, 'Speech'),
              const SizedBox(height: 8),
              _buildSliderTile(
                context,
                title: 'Speech Speed',
                subtitle: _speechSpeedLabel(settings.speechRate),
                value: settings.speechRate,
                min: 0.1,
                max: 1.0,
                onChanged: (value) async {
                  await settings.setSpeechRate(value);
                  await context.read<TTSService>().updateSettings();
                },
              ),
              _buildSliderTile(
                context,
                title: 'Volume',
                subtitle: '${(settings.speechVolume * 100).toInt()}%',
                value: settings.speechVolume,
                min: 0.0,
                max: 1.0,
                onChanged: (value) async {
                  await settings.setSpeechVolume(value);
                  await context.read<TTSService>().updateSettings();
                },
              ),
              _buildSliderTile(
                context,
                title: 'Path Clear Interval',
                subtitle: '${settings.pathClearInterval} seconds',
                value: settings.pathClearInterval.toDouble(),
                min: 3,
                max: 30,
                divisions: 27,
                onChanged: (value) {
                  settings.setPathClearInterval(value.toInt());
                },
              ),
              
              const Divider(height: 32),
              
              // Week 2: Verbosity Level
              _buildSectionHeader(context, 'Verbosity'),
              const SizedBox(height: 8),
              _buildVerbosityTile(context, settings),
              
              const Divider(height: 32),
              
              // Week 3: Language
              _buildSectionHeader(context, 'Language'),
              const SizedBox(height: 8),
              _buildLanguageTile(context, settings),
              
              const Divider(height: 32),
              
              // Navigation Mode
              _buildSectionHeader(context, 'Navigation'),
              const SizedBox(height: 8),
              _buildNavigationModeTile(context, settings),
              
              const Divider(height: 32),
              
              // Detection Settings (Features 1, 2, 14)
              _buildSectionHeader(context, 'Detection'),
              const SizedBox(height: 8),
              _buildSwitchTile(
                context,
                title: 'High Resolution',
                subtitle: 'Better accuracy, slower (Feature 14)',
                value: context.watch<CameraService>().isHighResolution,
                onChanged: (value) {
                  context.read<CameraService>().setHighResolution(value);
                },
              ),
              // Note: Multi-scale detection removed - YOLOv8n requires fixed 640x640 input
              
              const Divider(height: 32),
              
              // Accessibility
              _buildSectionHeader(context, 'Accessibility'),
              const SizedBox(height: 8),
              _buildSwitchTile(
                context,
                title: 'High Contrast Mode',
                subtitle: 'Yellow on black for low vision',
                value: settings.highContrast,
                onChanged: (value) {
                  settings.setHighContrast(value);
                },
              ),
              _buildSwitchTile(
                context,
                title: 'Vibration Feedback',
                subtitle: 'Haptic alerts for obstacles',
                value: settings.vibrationEnabled,
                onChanged: (value) {
                  settings.setVibrationEnabled(value);
                },
              ),
              _buildSwitchTile(
                context,
                title: 'Voice Commands',
                subtitle: 'Control with voice',
                value: settings.voiceCommandsEnabled,
                onChanged: (value) {
                  settings.setVoiceCommandsEnabled(value);
                },
              ),
              
              const Divider(height: 32),
              
              // Emergency Contact
              _buildSectionHeader(context, 'Emergency'),
              const SizedBox(height: 8),
              _buildEmergencyContactTile(context, settings),
              
              const Divider(height: 32),
              
              // Reset
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await settings.resetToDefaults();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings reset to defaults')),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset to Defaults'),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required Function(double) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18)),
                Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildVerbosityTile(BuildContext context, SettingsService settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Announcement Style: ${settings.verbosityLevel.displayName}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              settings.verbosityLevel.description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    context,
                    icon: Icons.volume_off,
                    label: 'Minimal',
                    selected: settings.verbosityLevel == VerbosityLevel.minimal,
                    onTap: () => settings.setVerbosityLevel(VerbosityLevel.minimal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    context,
                    icon: Icons.volume_down,
                    label: 'Normal',
                    selected: settings.verbosityLevel == VerbosityLevel.normal,
                    onTap: () => settings.setVerbosityLevel(VerbosityLevel.normal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    context,
                    icon: Icons.volume_up,
                    label: 'Detailed',
                    selected: settings.verbosityLevel == VerbosityLevel.detailed,
                    onTap: () => settings.setVerbosityLevel(VerbosityLevel.detailed),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Week 3: Language selection tile
  Widget _buildLanguageTile(BuildContext context, SettingsService settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Language: ${settings.language.displayName}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Changes voice commands and speech output',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    context,
                    icon: Icons.language,
                    label: 'English',
                    selected: settings.language == AppLanguage.english,
                    onTap: () {
                      settings.setLanguage(AppLanguage.english);
                      context.read<TTSService>().setLanguage(AppLanguage.english);
                      context.read<VoiceCommandService>().setListeningLocale('en-US');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeButton(
                    context,
                    icon: Icons.translate,
                    label: 'हिन्दी',
                    selected: settings.language == AppLanguage.hindi,
                    onTap: () {
                      settings.setLanguage(AppLanguage.hindi);
                      context.read<TTSService>().setLanguage(AppLanguage.hindi);
                      context.read<VoiceCommandService>().setListeningLocale('hi-IN');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationModeTile(BuildContext context, SettingsService settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Navigation Mode', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    context,
                    icon: Icons.home,
                    label: 'Indoor',
                    selected: settings.navigationMode == AppNavigationMode.indoor,
                    onTap: () => settings.setNavigationMode(AppNavigationMode.indoor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeButton(
                    context,
                    icon: Icons.directions_walk,
                    label: 'Outdoor',
                    selected: settings.navigationMode == AppNavigationMode.outdoor,
                    onTap: () => settings.setNavigationMode(AppNavigationMode.outdoor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected 
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactTile(BuildContext context, SettingsService settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.emergency, size: 32, color: Colors.red),
        title: const Text('Emergency Contact', style: TextStyle(fontSize: 18)),
        subtitle: Text(
          settings.emergencyContact.isEmpty 
            ? 'Not set' 
            : settings.emergencyContact,
        ),
        trailing: const Icon(Icons.edit),
        onTap: () => _showContactDialog(context, settings),
      ),
    );
  }

  void _showContactDialog(BuildContext context, SettingsService settings) {
    final controller = TextEditingController(text: settings.emergencyContact);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter phone number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              settings.setEmergencyContact(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _speechSpeedLabel(double rate) {
    if (rate < 0.3) return 'Slow';
    if (rate < 0.5) return 'Normal';
    if (rate < 0.7) return 'Fast';
    return 'Very Fast';
  }
}
