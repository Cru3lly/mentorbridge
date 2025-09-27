import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

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
      backgroundColor: Colors.grey[50],
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
                  child: Container(
                    width: double.infinity,
                    height: isLargeScreen
                        ? 160
                        : isMediumScreen
                            ? 150
                            : 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(isLargeScreen ? 24 : 20),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
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
                              // Clean Apple-Style Action Buttons Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: AppSpacing.lg,
                                  crossAxisSpacing: AppSpacing.md,
                                  childAspectRatio:
                                      0.85, // Optimized for square buttons + text
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

  // Modern Premium Card-Style Action Buttons
  Widget _buildCircularActionItem(
      Map<String, dynamic> item, bool isLargeScreen, bool isMediumScreen) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color itemColor = (item['color'] as Color?) ?? AppColors.primary;

    // Responsive sizing for premium feel
    final double cardSize = isLargeScreen ? 84.0 : 80.0;
    final double iconSize = isLargeScreen ? 30.0 : 28.0;
    final double borderRadius = isLargeScreen ? 20.0 : 18.0;
    final double fontSize = isLargeScreen ? 11.0 : 10.5;

    // Calculate total height with 3-line text support
    final double totalHeight = cardSize + 60; // Card + spacing + 3-line text

    // Helper function to break text into max 3 lines
    List<String> _breakTextIntoLines(String text) {
      final words = text.split(' ');
      if (words.length <= 1) return [text];
      if (words.length == 2) return words;
      if (words.length >= 3) return words.take(3).toList();
      return words;
    }

    final textLines = _breakTextIntoLines(item['label'] as String);

    return Semantics(
      label: '${item['label']} action',
      button: true,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 150),
        tween: Tween(begin: 1.0, end: 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: itemColor.withOpacity(0.2),
                highlightColor: itemColor.withOpacity(0.1),
                onTapDown: (_) {
                  // Scale down effect on tap
                  HapticFeedback.lightImpact();
                },
                onTap: () async {
                  try {
                    final onTapCallback = item['onTap'] as VoidCallback?;
                    if (onTapCallback != null && mounted) {
                      onTapCallback.call();
                    }
                  } catch (e) {
                    _handleError('Action failed: ${e.toString()}');
                  }
                },
                child: Container(
                  height: totalHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Premium card-style icon container
                      Container(
                        width: cardSize,
                        height: cardSize,
                        decoration: BoxDecoration(
                          // Soft gradient background based on item color
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    itemColor.withOpacity(0.15),
                                    itemColor.withOpacity(0.08),
                                  ]
                                : [
                                    itemColor.withOpacity(0.12),
                                    itemColor.withOpacity(0.06),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(borderRadius),
                          // Defined border with subtle color tint
                          border: Border.all(
                            color: isDark
                                ? itemColor.withOpacity(0.2)
                                : itemColor.withOpacity(0.15),
                            width: 1.2,
                          ),
                          // Premium shadow system for depth
                          boxShadow: [
                            // Primary colored shadow
                            BoxShadow(
                              color: itemColor.withOpacity(isDark ? 0.2 : 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                            // Secondary depth shadow
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                            // Subtle ambient shadow
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            item['icon'] as IconData,
                            color: itemColor,
                            size: iconSize,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 3-line text layout with consistent alignment
                      SizedBox(
                        height: 42, // Fixed height for 3 lines
                        width: cardSize + 12,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: textLines.asMap().entries.map((entry) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    entry.key < textLines.length - 1 ? 1 : 0,
                              ),
                              child: Text(
                                entry.value,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                  height: 1.1, // Tight line height
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build role title style based on button style
  TextStyle _buildRoleTitleStyle(bool isLargeScreen) {
    switch (widget.buttonStyle) {
      case DashboardButtonStyle.minimal:
        // Strong, prominent title for minimal style using global colors
        return TextStyle(
          fontSize: isLargeScreen ? 34 : 30,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimaryLight, // Use global text color
          letterSpacing: -0.6,
          height: 1.05,
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

  // Build text style based on button style (LEGACY - not currently used)
  /*
  TextStyle _buildTextStyle(double fontSize) {
    switch (widget.buttonStyle) {
      case DashboardButtonStyle.minimal:
        // Strong, readable text for minimal style using global colors
        return TextStyle(
          fontSize: fontSize + 1,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight, // Use global text color
          letterSpacing: -0.2,
          height: 1.15,
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
  */

  // Build main container decoration based on style (LEGACY - not currently used)
  /*
  BoxDecoration _buildMainContainerDecoration(bool isLargeScreen) {
    switch (widget.buttonStyle) {
      case DashboardButtonStyle.minimal:
        // Enhanced minimal decoration using global colors
        return BoxDecoration(
          color: AppColors.surfaceLight, // Use global surface color
          borderRadius: BorderRadius.circular(isLargeScreen ? 22 : 18),
          boxShadow: [
            // Primary shadow for depth with theme color tint
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
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
            color: AppColors.borderLight, // Use global border color
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
  */

  // Build inner icon tile by style variant (LEGACY - not currently used)
  /*
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
  */

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

  // 🆕 Enhanced Minimal Style - Using CleanCard system with global colors
  Widget _buildIconTileMinimal(Map<String, dynamic> item, bool isLargeScreen) {
    final double innerSize = isLargeScreen ? 66 : 62;
    final double iconSize = isLargeScreen ? 34 : 30;
    final Color baseColor = (item['color'] as Color?) ?? AppColors.primary;

    return Center(
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: BoxDecoration(
          // Use global theme color with subtle tint
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(isLargeScreen ? 18 : 16),
          // Enhanced shadow system using AppColors
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
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
          // Subtle border using global theme color
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Icon(
            item['icon'] as IconData,
            color: baseColor, // Use the item's specific color
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
