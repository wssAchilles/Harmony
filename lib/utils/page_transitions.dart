import 'package:flutter/material.dart';

import '../ui/motion/motion.dart';

/// 自定义页面过渡动画
class SlidePageRoute extends PageRouteBuilder {
  final Widget page;
  final Duration duration;
  final Offset beginOffset;

  SlidePageRoute({
    required this.page,
    this.duration = AppMotion.page,
    this.beginOffset = AppMotion.pageRight,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var tween = Tween(
              begin: beginOffset,
              end: Offset.zero,
            ).chain(CurveTween(curve: AppMotion.standardCurve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
}

/// 渐显页面过渡动画
class FadePageRoute extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  FadePageRoute({
    required this.page,
    this.duration = AppMotion.slow,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation.drive(
                Tween(
                  begin: 0.0,
                  end: 1.0,
                ).chain(CurveTween(curve: AppMotion.emphasizedCurve)),
              ),
              child: child,
            );
          },
        );
}

/// 缩放页面过渡动画
class ScalePageRoute extends PageRouteBuilder {
  final Widget page;
  final Duration duration;

  ScalePageRoute({
    required this.page,
    this.duration = AppMotion.slow,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var tween = Tween(
              begin: 0.5,
              end: 1.0,
            ).chain(CurveTween(curve: AppMotion.emphasizedCurve));

            return ScaleTransition(
              scale: animation.drive(tween),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        );
}

/// Hero动画辅助组件
class HeroDialogRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  HeroDialogRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog = false,
  });

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  bool get maintainState => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(Tween(begin: 0.0, end: 1.0)),
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  String? get barrierLabel => 'Dismiss';
}
