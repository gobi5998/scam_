import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 768) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final FloatingActionButton? floatingActionButton;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;
  final GlobalKey<ScaffoldState>? key;
  final bool resizeToAvoidBottomInset;

  const ResponsiveScaffold({
    this.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: key,
      appBar: appBar,
      drawer: ResponsiveHelper.isMobile(context) ? drawer : null,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveHelper.screenWidth(context) * 0.9,
        ),
        child: Container(padding: padding, margin: margin, child: child),
      ),
    );
  }
}
