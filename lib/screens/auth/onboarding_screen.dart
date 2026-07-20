import 'package:flutter/material.dart';
import '../../utils/constants.dart';

// We create a data structure to hold each onboarding slide's content
// This is not a widget - it's just a simple class to group related data together
class OnboardingSlide {
  // 'final' means this value is set once and never changes
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  // Constructor - called when we create a new OnboardingSlide object
  // 'required' means you MUST provide this value when creating the object
  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // PageController controls our swipeable pages
  // It lets us programmatically jump to any page
  final PageController _pageController = PageController();

  // Tracks which slide we're currently on - starts at 0 (first slide)
  int _currentPage = 0;

  // Our list of onboarding slides - defined as a list of OnboardingSlide objects
  // 'final' because this list never changes
  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      title: 'Welcome to JC Sports Hub',
      description:
          'Your one-stop platform for all sports activities at Makerere University Jinja Campus.',
      icon: Icons.sports_soccer,
      color: Color(0xFF1B5E20),
    ),
    OnboardingSlide(
      title: 'Follow Live Matches',
      description:
          'Get real-time score updates, predict match winners, and never miss a game again.',
      icon: Icons.scoreboard,
      color: Color(0xFF1565C0),
    ),
    OnboardingSlide(
      title: 'Join the Community',
      description:
          'Post updates, vote on decisions, register as a player, and be part of the JC sports family.',
      icon: Icons.people,
      color: Color(0xFF6A1B9A),
    ),
  ];

  // Called when user taps Next or Get Started
  void _onNextPressed() {
    // Check if we're on the last slide
    if (_currentPage == _slides.length - 1) {
      // If last slide - go to signup screen
      Navigator.pushReplacementNamed(context, '/signup');
    } else {
      // If not last slide - animate to the next page
      // animateToPage smoothly scrolls to the given page index
      _pageController.animateToPage(
        _currentPage + 1, // next page index
        duration: const Duration(milliseconds: 300), // animation speed
        curve: Curves.easeInOut, // smooth in and out
      );
    }
  }

  // Called when user taps Skip - jumps straight to signup
  void _onSkipPressed() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  @override
  void dispose() {
    // Always dispose PageController to free memory
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We use a Stack to layer widgets on top of each other
      // Like layers in Photoshop - bottom layer first
      body: Stack(
        children: [
          // LAYER 1 - The swipeable pages (bottom layer)
          PageView.builder(
            controller: _pageController,

            // itemCount tells PageView how many pages exist
            itemCount: _slides.length,

            // onPageChanged fires every time user swipes to a new page
            // 'page' is the new page index
            onPageChanged: (page) {
              // setState() tells Flutter to redraw the screen with new data
              // Any variable change that affects UI must be inside setState
              setState(() {
                _currentPage = page;
              });
            },

            // itemBuilder builds each page on demand
            // 'index' is the current page number being built
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return _buildSlide(slide);
            },
          ),

          // LAYER 2 - Skip button (top right)
          Positioned(
            // Positioned places a widget at exact coordinates inside Stack
            top: 50,
            right: 20,
            child: _currentPage < _slides.length - 1
                // Ternary operator: condition ? valueIfTrue : valueIfFalse
                ? TextButton(
                    onPressed: _onSkipPressed,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: AppSizes.fontMedium,
                      ),
                    ),
                  )
                // Hide skip button on last slide
                : const SizedBox
                    .shrink(), // shrink() creates an invisible zero-size widget
          ),

          // LAYER 3 - Bottom controls (dots + button)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Dot indicators showing which slide we're on
                Row(
                  // Row arranges widgets horizontally
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    // List.generate creates a list of widgets
                    _slides.length, // how many dots to create
                    (index) => _buildDot(index), // build each dot
                  ),
                ),

                const SizedBox(height: 32),

                // Next / Get Started button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.paddingLarge,
                  ),
                  child: SizedBox(
                    // Make button full width
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _slides[_currentPage].color,
                        // Shape defines the button's border radius
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLarge,
                          ),
                        ),
                      ),
                      child: Text(
                        // Show different text on last slide
                        _currentPage == _slides.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: AppSizes.fontMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // This method builds a single onboarding slide
  // Extracting it into its own method keeps build() clean and readable
  Widget _buildSlide(OnboardingSlide slide) {
    return Container(
      // Fill the entire screen with the slide's color
      decoration: BoxDecoration(
        // Gradient blends two colors from top to bottom
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            slide.color,
            slide.color.withOpacity(0.7),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon inside a circular background
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(75),
              ),
              child: Icon(
                slide.icon,
                size: 80,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 48),

            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppSizes.fontXL,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: AppSizes.fontMedium,
                // height adds line spacing - 1.5 means 1.5x the font size
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a single dot indicator
  Widget _buildDot(int index) {
    // AnimatedContainer smoothly animates size/color changes
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      // Active dot is wider than inactive dots
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        // Active dot is white, inactive is semi-transparent
        color: _currentPage == index
            ? Colors.white
            : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
