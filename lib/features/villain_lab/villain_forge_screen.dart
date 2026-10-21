import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../app/app_theme.dart';
import '../../game/models/custom_villain.dart';
import '../../services/custom_villain_service.dart';
import '../../services/face_villain/face_cartoonizer.dart';
import '../../services/face_villain/face_detector_service.dart';
import '../../services/face_villain/villain_generator.dart';
import '../../services/game_state_service.dart';
import 'widgets/villain_avatar.dart';

enum _Stage { picking, analyzing, editing, failed }

/// Takes a face photo, analyses it and forges a 2D cartoon villain.
/// Also used to edit an existing villain (pass [editId]).
class VillainForgeScreen extends StatefulWidget {
  final ImageSource? source;
  final String? editId;

  const VillainForgeScreen({super.key, this.source, this.editId});

  @override
  State<VillainForgeScreen> createState() => _VillainForgeScreenState();
}

class _VillainForgeScreenState extends State<VillainForgeScreen>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.picking;
  String _status = 'Opening camera...';
  String? _error;
  Uint8List? _photo;
  CartoonResult? _face;
  CustomVillain? _villain;
  bool _saving = false;

  final _personName = TextEditingController();
  final _villainName = TextEditingController();
  final _title = TextEditingController();
  String _archetype = 'balanced';
  String _suggestedArchetype = 'balanced';
  String _zoneId = 'zone_office';
  bool _nameEdited = false;

  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _scan.dispose();
    _personName.dispose();
    _villainName.dispose();
    _title.dispose();
    super.dispose();
  }

  void _start() {
    final editId = widget.editId;
    if (editId != null) {
      final existing = context.read<CustomVillainService>().byId(editId);
      if (existing == null) {
        _fail('That villain no longer exists.');
        return;
      }
      setState(() {
        _villain = existing;
        _villainName.text = existing.name;
        _title.text = existing.title;
        _archetype = existing.archetype;
        _suggestedArchetype = existing.archetype;
        _zoneId = existing.zoneId;
        _nameEdited = true;
        _stage = _Stage.editing;
      });
      return;
    }
    _pick(widget.source ?? ImageSource.gallery);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _error = message;
    });
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _stage = _Stage.picking;
      _status = source == ImageSource.camera ? 'Opening camera...' : 'Opening gallery...';
    });
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.front,
      );
    } catch (e) {
      _fail(source == ImageSource.camera
          ? 'Could not open the camera. Check camera permission or pick a photo from the gallery instead.'
          : 'Could not open the photo gallery: $e');
      return;
    }
    if (!mounted) return;
    if (file == null) {
      // User cancelled.
      if (_face == null) {
        context.pop();
      } else {
        setState(() => _stage = _Stage.editing);
      }
      return;
    }
    await _analyze(file);
  }

  Future<void> _analyze(XFile file) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = bytes;
      _stage = _Stage.analyzing;
      _status = 'Finding the face...';
    });

    FaceBox? box;
    try {
      box = await FaceDetectorService().detect(file.path);
    } catch (_) {
      box = null;
    }
    if (!mounted) return;
    setState(() => _status = box != null
        ? 'Face found! Drawing the cartoon...'
        : 'No face detected, using a centre crop...');

    try {
      final result = await compute(cartoonizeFace, CartoonRequest(bytes, box));
      if (!mounted) return;
      final gs = context.read<GameStateService>();
      final suggested = VillainGenerator.inferArchetype(result);
      setState(() {
        _face = result;
        _suggestedArchetype = suggested;
        _archetype = suggested;
        _zoneId = gs.selectedZoneId;
        if (!_nameEdited) {
          _villainName.text = VillainGenerator.suggestName(_personName.text, result.seed);
        }
        _title.text = VillainGenerator.suggestTitle(suggested, result.seed);
        _villain = _buildVillain();
        _stage = _Stage.editing;
      });
    } catch (e) {
      _fail('Could not process that photo. Try a different picture.\n($e)');
    }
  }

  String _zoneName(String id) =>
      context.read<GameStateService>().getZone(id)?.name ?? 'the arena';

  CustomVillain? _buildVillain() {
    final face = _face;
    final name = _villainName.text.trim().isEmpty ? 'Mystery Face' : _villainName.text.trim();
    final title = _title.text.trim().isEmpty
        ? VillainGenerator.suggestTitle(_archetype, face?.seed ?? 0)
        : _title.text.trim();
    if (face != null) {
      return VillainGenerator.create(
        id: _villain?.id ?? 'custom_${const Uuid().v4()}',
        face: face,
        name: name,
        title: title,
        archetype: _archetype,
        zoneId: _zoneId,
        zoneName: _zoneName(_zoneId),
      );
    }
    final existing = _villain;
    if (existing == null) return null;
    return VillainGenerator.restyle(
      existing,
      name: name,
      title: title,
      archetype: _archetype,
      zoneId: _zoneId,
      zoneName: _zoneName(_zoneId),
    );
  }

  void _refresh() => setState(() => _villain = _buildVillain());

  Future<void> _save({required bool fight}) async {
    final villain = _buildVillain();
    if (villain == null || _saving) return;
    setState(() => _saving = true);
    await context.read<CustomVillainService>().save(villain);
    if (!mounted) return;
    if (fight) {
      final gs = context.read<GameStateService>();
      final heroes = gs.selectedHeroIds.isNotEmpty
          ? gs.selectedHeroIds.take(gs.selectedMode.friendlyCount).toList()
          : [gs.heroes.first.id];
      context.pushReplacement('/game', extra: {
        'zoneId': villain.zoneId,
        'mode': gs.selectedMode.name,
        'heroIds': heroes,
        'villainIds': [villain.id],
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${villain.name} joined the villain roster!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.editId != null ? 'Edit Villain' : 'Villain Forge'),
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.picking => _buildWaiting(),
          _Stage.analyzing => _buildAnalyzing(),
          _Stage.failed => _buildFailed(),
          _Stage.editing => _buildEditor(),
        },
      ),
    );
  }

  Widget _buildWaiting() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _buildFailed() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick a Photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Use Camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildAnalyzing() {
    final photo = _photo;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(photo, fit: BoxFit.cover),
                      AnimatedBuilder(
                        animation: _scan,
                        builder: (context, _) => Align(
                          alignment: Alignment(0, _scan.value * 2 - 1),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.8),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Everything happens on this device. Your photo is never uploaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final villain = _villain;
    if (villain == null) return _buildWaiting();
    final gs = context.watch<GameStateService>();
    final face = _face;
    final traits = villain.traits;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Preview card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                traits.accentColor.withValues(alpha: 0.45),
                AppColors.surface,
              ],
            ),
            border: Border.all(color: traits.accentColor.withValues(alpha: 0.7), width: 2),
          ),
          child: Row(
            children: [
              VillainAvatar.of(villain, size: 170),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      villain.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      villain.title,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _statBar('Health', villain.baseHealth, 160, Colors.redAccent),
                    _statBar('Attack', villain.attackDamage, 30, Colors.orangeAccent),
                    _statBar('Speed', villain.moveSpeed.round(), 240, Colors.cyanAccent),
                    _statBar('Defense', villain.defense, 30, Colors.blueAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          villain.biography,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
        ),

        // Analysis
        const SizedBox(height: 16),
        _sectionTitle('Face analysis'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              traits.faceDetected ? Icons.face_retouching_natural : Icons.crop_free,
              traits.faceDetected ? 'Face detected' : 'Centre crop',
              traits.faceDetected ? AppColors.success : AppColors.warning,
            ),
            if (traits.smiling != null)
              _chip(Icons.sentiment_satisfied_alt,
                  'Smile ${(traits.smiling! * 100).round()}%', AppColors.accent),
            _chip(
              Icons.crop_portrait,
              traits.faceAspect >= 0.9
                  ? 'Wide face'
                  : traits.faceAspect < 0.75
                      ? 'Narrow face'
                      : 'Balanced face',
              AppColors.secondary,
            ),
            _swatch('Skin', traits.skinTone),
            _swatch('Hair', traits.hairColor),
            _swatch('Villain colour', traits.accentColor),
            _chip(Icons.auto_awesome,
                'Suggested: ${VillainGenerator.archetypeLabels[_suggestedArchetype]}',
                AppColors.primary),
          ],
        ),
        if (face != null && !face.faceDetected) ...[
          const SizedBox(height: 8),
          Text(
            FaceDetectorService.isSupported
                ? 'Tip: a clear, front-facing photo with good light gives the best cartoon.'
                : 'Automatic face detection runs on Android and iOS. Here the photo centre was used.',
            style: const TextStyle(color: AppColors.warning, fontSize: 11),
          ),
        ],

        // Identity
        const SizedBox(height: 16),
        _sectionTitle('Identity'),
        if (face != null) ...[
          TextField(
            controller: _personName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "Person's name (optional)",
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (v) {
              if (!_nameEdited) {
                _villainName.text = VillainGenerator.suggestName(v, face.seed);
              }
              _refresh();
            },
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _villainName,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Villain name',
            prefixIcon: Icon(Icons.badge),
          ),
          onChanged: (_) {
            _nameEdited = true;
            _refresh();
          },
        ),
        TextField(
          controller: _title,
          maxLength: 32,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Villain title',
            prefixIcon: const Icon(Icons.military_tech),
            suffixIcon: IconButton(
              tooltip: 'New title',
              icon: const Icon(Icons.casino),
              onPressed: () {
                final seed = DateTime.now().millisecondsSinceEpoch;
                _title.text = VillainGenerator.suggestTitle(_archetype, seed);
                _refresh();
              },
            ),
          ),
          onChanged: (_) => _refresh(),
        ),

        // Fighting style
        const SizedBox(height: 8),
        _sectionTitle('Fighting style'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in VillainGenerator.archetypes)
              ChoiceChip(
                label: Text(VillainGenerator.archetypeLabels[a]!),
                avatar: a == _suggestedArchetype
                    ? const Icon(Icons.auto_awesome, size: 16)
                    : null,
                selected: _archetype == a,
                onSelected: (_) {
                  _archetype = a;
                  _refresh();
                },
              ),
          ],
        ),

        // Zone
        const SizedBox(height: 16),
        _sectionTitle('Lair (zone)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final z in gs.zones)
              ChoiceChip(
                label: Text(z.name),
                avatar: gs.isZoneUnlocked(z) ? null : const Icon(Icons.lock, size: 16),
                selected: _zoneId == z.id,
                onSelected: gs.isZoneUnlocked(z)
                    ? (_) {
                        _zoneId = z.id;
                        _refresh();
                      }
                    : null,
              ),
          ],
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(fight: false),
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : () => _save(fight: true),
                icon: const Icon(Icons.sports_mma),
                label: Text('Save & Fight (${gs.selectedMode.shortName})'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
        if (face != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.refresh),
              label: const Text('Use a different photo'),
            ),
          ),
        ],
        const SizedBox(height: 4),
        const Text(
          'Only use photos of people who are happy to become a cartoon villain.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      );

  Widget _swatch(String label, Color color) => Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _statBar(String label, int value, int max, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (value / max).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.black26,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text('$value',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

/// Shared helper: shows the camera/gallery chooser and opens the forge.
Future<void> showVillainSourcePicker(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Forge a villain from a face',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Take a selfie / photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.secondary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  context.push('/villain-lab/create', extra: {'source': source.name});
}
