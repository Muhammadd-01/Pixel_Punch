import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../services/audio_service.dart';
import '../../services/local_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _masterVolume = 1.0;
  double _musicVolume = 0.7;
  double _sfxVolume = 1.0;
  bool _isMuted = false;
  bool _reducedMotion = false;
  bool _vibration = true;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioService>();
    _masterVolume = audio.masterVolume;
    _musicVolume = audio.musicVolume;
    _sfxVolume = audio.sfxVolume;
    _isMuted = audio.isMuted;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = context.read<LocalStorageService>();
    final settings = await storage.loadSettings();
    if (mounted) {
      setState(() {
        _reducedMotion = settings['reduced_motion'] as bool? ?? false;
        _vibration = settings['vibration'] as bool? ?? true;
      });
    }
  }

  Future<void> _saveSetting(String key, dynamic val) async {
    final storage = context.read<LocalStorageService>();
    await storage.saveSetting(key, val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Audio', [
            _buildSwitchTile('Mute All Sounds', _isMuted, (v) {
              setState(() => _isMuted = v);
              context.read<AudioService>().toggleMute();
            }),
            _buildSliderTile('Master Volume', _masterVolume, (v) {
              setState(() => _masterVolume = v);
              context.read<AudioService>().setMasterVolume(v);
            }),
            _buildSliderTile('Music Volume', _musicVolume, (v) {
              setState(() => _musicVolume = v);
              context.read<AudioService>().setMusicVolume(v);
            }),
            _buildSliderTile('SFX Volume', _sfxVolume, (v) {
              setState(() => _sfxVolume = v);
              context.read<AudioService>().setSfxVolume(v);
            }),
          ]),
          const SizedBox(height: 16),
          _buildSection('Gameplay & Controls', [
            _buildSwitchTile('Reduced Motion', _reducedMotion, (v) {
              setState(() => _reducedMotion = v);
              _saveSetting('reduced_motion', v);
            }),
            _buildSwitchTile('Haptic Feedback (Vibration)', _vibration, (v) {
              setState(() => _vibration = v);
              _saveSetting('vibration', v);
            }),
          ]),
          const SizedBox(height: 16),
          _buildSection('Cloud & Data', [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done, color: AppColors.success),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sync Status', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Local progression stored safely offline',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Local progress is up to date!')),
                      );
                    },
                    child: const Text('Check Sync'),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('About PixelPunch', [
            ListTile(
              title: const Text('Game Version'),
              subtitle: const Text('1.0.0+1 (Release Vertical Slice)'),
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 6),
            ListTile(
              title: const Text('Fictional Company Inspiration'),
              subtitle: const Text('NexoVate Digital - All characters are computer-controlled and fictional'),
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSliderTile(String label, double value, ValueChanged<double> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textPrimary)),
              Text('${(value * 100).toInt()}%',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          Slider(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceLight,
          ),
        ],
      ),
    );
  }
}
