import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';

// Dashboard button visual styles. Default is minimal.
enum DashboardButtonStyle {
  glassPro,
  minimal, // 🆕 Modern minimal cards design
  vibrant,
  outline,
  neumorphic, // reserved for future
  acrylic, // reserved for future
  depth, // reserved for future
}

class RoleDashboardWrapper extends StatefulWidget {
  final String roleTitle;
  final Widget topWidget;
  final List<Map<String, dynamic>> menuItems;
  final VoidCallback? onTopWidgetTap;
  final bool isLoading;
  final DashboardButtonStyle buttonStyle;

  const RoleDashboardWrapper({
    super.key,
    required this.roleTitle,
    required this.topWidget,
    required this.menuItems,
    this.onTopWidgetTap,
    this.isLoading = false,
    this.buttonStyle = DashboardButtonStyle.minimal,
  });

  @override
  State<RoleDashboardWrapper> createState() => _RoleDashboardWrapperState();
}

class _RoleDashboardWrapperState extends State<RoleDashboardWrapper>
    with WidgetsBindingObserver {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clear any errors when app resumes
      if (mounted && _error != null) {
        setState(() => _error = null);
      }
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() => _error = error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isLargeScreen = screenWidth > 600;
            final isMediumScreen = screenWidth > 400;

            // Show loading state if needed
            if (widget.isLoading) {
              return _buildLoadingState(isLargeScreen, isMediumScreen);
            }

            // Show error state if there's an error
            if (_error != null) {
              return _buildErrorState(isLargeScreen, isMediumScreen);
            }

            return Column(
              children: [
                // Role Title positioned above widget - left aligned
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    left: isLargeScreen
                        ? 32
                        : 20, // Align with widget's left edge
                    right: isLargeScreen ? 24 : 16,
                    bottom: isLargeScreen ? 8 : 6, // Small gap before widget
                  ),
                  child: Text(
                    widget.roleTitle.replaceAll(' Dashboard', ''),
                    style: _buildRoleTitleStyle(isLargeScreen),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                ),

                // Fixed top widget area (sabit kalacak) - Responsive
                Container(
                  margin: EdgeInsets.fromLTRB(
                      isLargeScreen ? 24 : 16,
                      0, // No top margin since title is above
                      isLargeScreen ? 24 : 16,
                      isLargeScreen ? 16 : 10),
                  child: GlassmorphicContainer(
                    width: double.infinity,
                    height: isLargeScreen
                        ? 160
                        : isMediumScreen
                            ? 150
                            : 140,
                    borderRadius: isLargeScreen ? 24 : 20,
                    blur: 15,
                    border: 1.5,
                    linearGradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderGradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.4),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    child: Semantics(
                      label: '${widget.roleTitle} overview',
                      button: widget.onTopWidgetTap != null,
                      child: InkWell(
                        onTap: widget.onTopWidgetTap,
                        borderRadius:
                            BorderRadius.circular(isLargeScreen ? 24 : 20),
                        child: Padding(
                          padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
                          child: widget.topWidget,
                        ),
                      ),
                    ),
                  ),
                ),

                // Separator line to prevent overlap - Responsive
                Container(
                  height: isLargeScreen
                      ? 24
                      : 20, // Adjusted spacing for better button visibility
                  margin:
                      EdgeInsets.symmetric(horizontal: isLargeScreen ? 24 : 16),
                  child: Center(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.6),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Modern Hero Action + Quick Actions Layout
                Expanded(
                  child: ClipRect(
                    child: Transform.translate(
                      offset: Offset(
                          0,
                          isLargeScreen
                              ? -8
                              : -6), // Much less overlap - buttons more visible
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                            isLargeScreen ? 24 : 16,
                            isLargeScreen
                                ? 12
                                : 8, // Added top padding for better spacing
                            isLargeScreen ? 24 : 16,
                            isLargeScreen ? 24 : 16),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // All Actions as Circular Buttons (Apple iOS Style)
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: isLargeScreen
                                      ? 12
                                      : 10, // Better vertical spacing
                                  crossAxisSpacing: isLargeScreen
                                      ? 18
                                      : 14, // Better horizontal spacing
                                  childAspectRatio:
                                      0.88, // Optimized proportions
                                ),
                                itemCount: widget.menuItems.length,
                                itemBuilder: (context, index) =>
                                    _buildCircularActionItem(
                                        widget.menuItems[index],
                                        isLargeScreen,
                                        isMediumScreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Navigation bar now handled by AppShell
    );
  }

  // Loading state with skeleton UI
  Widget _buildLoadingState(bool isLargeScreen, bool isMediumScreen) {
    return Column(
      children: [
        // Role Title positioned above widget - left aligned (same as main state)
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(
            left: isLargeScreen ? 32 : 20, // Align with widget's left edge
            right: isLargeScreen ? 24 : 16,
            bottom: isLargeScreen ? 8 : 6, // Small gap before widget
          ),
          child: Text(
            widget.roleTitle
                .split(' ')[0], // Get first word (Director, Admin, etc.)
            style: TextStyle(
              fontSize: isLargeScreen ? 28 : 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.15),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),

        // Skeleton top widget
        Container(
          margin: EdgeInsets.fromLTRB(
              isLargeScreen ? 24 : 16,
              0, // No top margin since title is above
              isLargeScreen ? 24 : 16,
              isLargeScreen ? 16 : 10),
          child: _buildSkeletonContainer(
            width: double.infinity,
            height: isLargeScreen
                ? 160
                : isMediumScreen
                    ? 150
                    : 140,
            borderRadius: isLargeScreen ? 24 : 20,
          ),
        ),

        // Skeleton separator
        Container(
          height: isLargeScreen ? 24 : 20,
          margin: EdgeInsets.symmetric(horizontal: isLargeScreen ? 24 : 16),
          child: Center(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Skeleton buttons
        Expanded(
          child: Container(
            padding: EdgeInsets.fromLTRB(isLargeScreen ? 24 : 16, 0,
                isLargeScreen ? 24 : 16, isLargeScreen ? 24 : 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: isLargeScreen ? 16 : 12,
                crossAxisSpacing: isLargeScreen ? 16 : 12,
                childAspectRatio: 1.0,
              ),
              itemCount: 6, // Show 6 skeleton items
              itemBuilder: (context, index) =>
                  _buildSkeletonButton(isLargeScreen, isMediumScreen),
            ),
          ),
        ),
      ],
    );
  }

  // Error state with retry option
  Widget _buildErrorState(bool isLargeScreen, bool isMediumScreen) {
    return Column(
      children: [
        // Role Title positioned above widget - left aligned (same as main state)
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(
            left: isLargeScreen ? 32 : 20, // Align with widget's left edge
            right: isLargeScreen ? 24 : 16,
            bottom: isLargeScreen ? 8 : 6, // Small gap before content
          ),
          child: Text(
            widget.roleTitle
                .split(' ')[0], // Get first word (Director, Admin, etc.)
            style: TextStyle(
              fontSize: isLargeScreen ? 28 : 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.15),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),

        // Error content
        Expanded(
          child: Center(
            child: Container(
              margin: EdgeInsets.all(isLargeScreen ? 32 : 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: isLargeScreen ? 80 : 64,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  SizedBox(height: isLargeScreen ? 24 : 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 24 : 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isLargeScreen ? 16 : 12),
                  Text(
                    _error ?? 'An unexpected error occurred',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16 : 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isLargeScreen ? 32 : 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _error = null);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 24 : 20,
                        vertical: isLargeScreen ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Skeleton container with shimmer effect
  Widget _buildSkeletonContainer({
    required double width,
    required double height,
    required double borderRadius,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.3, end: 0.7),
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(value),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
      },
    );
  }

  // Skeleton button
  Widget _buildSkeletonButton(bool isLargeScreen, bool isMediumScreen) {
    final containerSize = isLargeScreen
        ? 110.0
        : isMediumScreen
            ? 100.0
            : 90.0;
    final iconContainerSize = isLargeScreen
        ? 70.0
        : isMediumScreen
            ? 64.0
            : 60.0;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.2, end: 0.5),
      builder: (context, value, child) {
        return SizedBox(
          width: containerSize,
          height: containerSize,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(value),
                  borderRadius: BorderRadius.circular(iconContainerSize / 2),
                ),
              ),
              SizedBox(height: isLargeScreen ? 8 : 6),
              Container(
                width: containerSize - 20,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(value * 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Apple iOS Style Rounded Square Buttons
  Widget _buildCircularActionItem(
      Map<String, dynamic> item, bool isLargeScreen, bool isMediumScreen) {
    final containerSize = isLargeScreen
        ? 120.0
        : isMediumScreen
            ? 110.0
            : 100.0; // Bigger containers
    final fontSize = isLargeScreen
        ? 18.0
        : isMediumScreen
            ? 17.0
            : 16.0; // Bigger text
    final iconContainerSize = isLargeScreen
        ? 80.0
        : isMediumScreen
            ? 74.0
            : 70.0; // Bigger icon containers

    return Semantics(
      label: '${item['label']} action',
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
            isLargeScreen ? 20 : 16), // Apple rounded corners
        child: InkWell(
          borderRadius: BorderRadius.circular(
              isLargeScreen ? 20 : 16), // Apple rounded corners
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          onTap: () async {
            try {
              HapticFeedback.lightImpact();
              final onTapCallback = item['onTap'] as VoidCallback?;
              if (onTapCallback != null && mounted) {
                onTapCallback.call();
              }
            } catch (e) {
              _handleError('Action failed: ${e.toString()}');
            }
          },
          child: SizedBox(
            width: containerSize,
            height: containerSize,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main container - adaptive styling based on button style
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: _buildMainContainerDecoration(isLargeScreen),
                  child: _buildIconTileByStyle(item, isLargeScreen),
                ),

                SizedBox(height: isLargeScreen ? 8 : 6), // Reduced text spacing

                // Text label with adaptive styling
                Container(
                  width: containerSize + 10, // More width for text
                  constraints: BoxConstraints(
                    minHeight: isLargeScreen ? 40 : 36,
                  ),
                  child: Text(
                    item['label'] as String,
                    style: _buildTextStyle(fontSize),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build role title style based on button style
  TextStyle _buildRoleTitleStyle(bool isLargeScreen) {
    switch (widget.buttonStyle) {
      case DashboardButtonStyle.minimal:
        // Strong, prominent title for minimal style
        return TextStyle(
          fontSize: isLargeScreen ? 34 : 30, // Larger for more impact
          fontWeight: FontWeight.w800, // Bolder weight
          color: Colors.grey[900], // Strong dark text
          letterSpacing: -0.6, // Tighter for modern look
          height: 1.05, // Tighter line height
        );
      case DashboardButtonStyle.glassPro:
      default:
        // Original white title with shadow for glass style
        return TextStyle(
          fontSize: isLargeScreen ? 28 : 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.4,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.15),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        );
    }
  }

  // Build text style based on button style
  TextStyle _buildTextStyle(double fontSize) {
    switch (widget.buttonStyle) {
      case DashboardButtonStyle.minimal:
        // Strong, readable text for minimal style
        return TextStyle(
          fontSize: fontSize + 1, // Slightly larger for better readability
          fontWeight: FontWeight.w700, // Bolder weight
          color: Colors.grey[900], // Stronger contrast
          letterSpacing: -0.2, // Tighter spacing
          height: 1.15, // Optimized line height
        );
      case DashboardButtonStyle.glassPro:
      default:
        // Original white text with shadow for glass style
        return TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
          height: 1.1,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.15),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        );
    }
  }

  // Build main container decoration based on style
  BoxDecoration _buildMainContainerDecoration(bool isLargeScreen) {
    switch (widget.buttonStyle) {
      case DashboardButtonStyle.minimal:
        // Enhanced minimal decoration with better depth
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
              isLargeScreen ? 22 : 18), // Slightly more rounded
          boxShadow: [
            // Primary shadow for depth
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
            // Secondary shadow for softness
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
              spreadRadius: 0,
            ),
            // Subtle ambient shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.12),
            width: 0.8,
          ),
        );
      case DashboardButtonStyle.glassPro:
      default:
        // Original glassmorphic style
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.3),
              Colors.white.withOpacity(0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isLargeScreen ? 18 : 14),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: isLargeScreen ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  // Build inner icon tile by style variant
  Widget _buildIconTileByStyle(Map<String, dynamic> item, bool isLargeScreen) {
    switch (widget.buttonStyle) {
      case DashboardButtonStyle.glassPro:
        return _buildIconTileGlassPro(item, isLargeScreen);
      case DashboardButtonStyle.minimal:
        return _buildIconTileMinimal(item, isLargeScreen);
      case DashboardButtonStyle.vibrant:
        return _buildIconTileVibrant(item, isLargeScreen);
      case DashboardButtonStyle.outline:
        return _buildIconTileOutline(item, isLargeScreen);
      case DashboardButtonStyle.neumorphic:
      case DashboardButtonStyle.acrylic:
      case DashboardButtonStyle.depth:
        // Fallback to minimal for now
        return _buildIconTileMinimal(item, isLargeScreen);
    }
  }

  Widget _buildIconTileGlassPro(Map<String, dynamic> item, bool isLargeScreen) {
    final double innerSize = isLargeScreen ? 58 : 54;
    final double iconSize = isLargeScreen ? 34 : 30;
    final Color baseColor = (item['color'] as Color?) ?? Colors.blue;
    final BorderRadius innerRadius =
        BorderRadius.circular(isLargeScreen ? 16 : 14);

    return Center(
      child: SizedBox(
        width: innerSize,
        height: innerSize,
        child: Stack(
          children: [
            // Tinted glossy tile
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: innerRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      baseColor.withOpacity(0.30),
                      baseColor.withOpacity(0.18),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            // Subtle top highlight for glossy effect
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: isLargeScreen ? 22 : 20,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: innerRadius.topLeft,
                    topRight: innerRadius.topRight,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Icon centered
            Center(
              child: Icon(
                item['icon'] as IconData,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconTileVibrant(Map<String, dynamic> item, bool isLargeScreen) {
    final double innerSize = isLargeScreen ? 60 : 56;
    final double iconSize = isLargeScreen ? 34 : 30;
    final Color base = (item['color'] as Color?) ?? Colors.blue;

    Color lighten(Color c, [double amount = 0.2]) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
          .toColor();
    }

    Color darken(Color c, [double amount = 0.2]) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
          .toColor();
    }

    return Center(
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lighten(base, 0.18), darken(base, 0.10)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
                color: base.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: Icon(
            item['icon'] as IconData,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildIconTileOutline(Map<String, dynamic> item, bool isLargeScreen) {
    final double innerSize = isLargeScreen ? 60 : 56;
    final double iconSize = isLargeScreen ? 32 : 28;
    final Color base = (item['color'] as Color?) ?? Colors.white;

    return Center(
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 14),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
        ),
        child: Center(
          child: Icon(
            item['icon'] as IconData,
            color: base.withOpacity(0.95),
            size: iconSize,
          ),
        ),
      ),
    );
  }

  // 🆕 Enhanced Minimal Style - Clean with subtle color tint
  Widget _buildIconTileMinimal(Map<String, dynamic> item, bool isLargeScreen) {
    final double innerSize = isLargeScreen ? 66 : 62; // Slightly larger
    final double iconSize = isLargeScreen ? 34 : 30; // Larger icons
    final Color baseColor = (item['color'] as Color?) ?? Colors.blue;

    return Center(
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: BoxDecoration(
          // Subtle tinted background for visual interest
          color: baseColor.withOpacity(0.03),
          borderRadius:
              BorderRadius.circular(isLargeScreen ? 18 : 16), // More rounded
          // Enhanced shadow system
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.08), // Color-tinted shadow
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
          // Subtle colored border
          border: Border.all(
            color: baseColor.withOpacity(0.15),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Icon(
            item['icon'] as IconData,
            color: baseColor.withOpacity(0.95), // Strong, vibrant color
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
