import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/local_storage_service.dart';
import '../../app/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _Page(Icons.explore, 'Explore Game Zones',
        'Enter distinct worlds from stylized offices to neon districts. Each zone has unique challenges, secrets, and rivals to discover.',
        AppColors.primary),
    _Page(Icons.person_search, 'Discover Villains',
        'Find fictional company-inspired villains hiding throughout each zone. Uncover their stories, hear their taunts, and prepare for battle.',
        AppColors.secondary),
    _Page(Icons.sports_mma, 'Choose & Fight',
        'Pick your hero team and battle in Solo, Duo, or Squad modes. Master abilities, defeat villains, and claim your victory!',
        AppColors.accent),
  ];

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  void _complete() async {
    await context.read<LocalStorageService>().setOnboardingComplete();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _complete,
                  child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            color: p.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(p.icon, size: 64, color: p.color),
                        ),
                        const SizedBox(height: 40),
                        Text(p.title, textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: p.color)),
                        const SizedBox(height: 16),
                        Text(p.desc, textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary, height: 1.6)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 32 : 8, height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == i ? _pages[i].color : AppColors.surface,
                  ),
                )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                        child: const Text('Back'))
                  else const SizedBox(width: 80),
                  ElevatedButton(
                    onPressed: _currentPage == _pages.length - 1
                        ? _complete
                        : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                    child: Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page {
  final IconData icon;
  final String title, desc;
  final Color color;
  const _Page(this.icon, this.title, this.desc, this.color);
}
