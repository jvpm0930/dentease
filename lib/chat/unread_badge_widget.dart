import 'dart:async';
import 'package:dentease/services/messaging_service.dart';
import 'package:flutter/material.dart';

/// Unread Badge Widget
/// Shows a real-time unread message count badge
/// Use this on dashboard icons to show pending messages
class UnreadBadge extends StatefulWidget {
  final String userId;
  final Widget child;
  final Color badgeColor;
  final Color textColor;
  final double size;
  final Offset offset;

  const UnreadBadge({
    super.key,
    required this.userId,
    required this.child,
    this.badgeColor = Colors.red,
    this.textColor = Colors.white,
    this.size = 18,
    this.offset = const Offset(0, 0),
  });

  @override
  State<UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<UnreadBadge> {
  final MessagingService _messagingService = MessagingService();
  StreamSubscription? _subscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToUnreadCount();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToUnreadCount() {
    _subscription = _messagingService
        .streamTotalUnreadCount(widget.userId)
        .listen((count) {
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_unreadCount > 0)
          Positioned(
            right: widget.offset.dx - (widget.size / 2),
            top: widget.offset.dy - (widget.size / 2),
            child: Container(
              padding: EdgeInsets.all(widget.size > 16 ? 4 : 2),
              constraints: BoxConstraints(
                minWidth: widget.size,
                minHeight: widget.size,
              ),
              decoration: BoxDecoration(
                color: widget.badgeColor,
                shape: _unreadCount > 9 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: _unreadCount > 9
                    ? BorderRadius.circular(widget.size / 2)
                    : null,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.badgeColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: widget.size > 16 ? 10 : 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple Unread Dot Indicator
/// Shows just a red dot when there are unread messages
class UnreadDot extends StatefulWidget {
  final String userId;
  final Widget child;
  final Color dotColor;
  final double size;
  final Offset offset;

  const UnreadDot({
    super.key,
    required this.userId,
    required this.child,
    this.dotColor = Colors.red,
    this.size = 10,
    this.offset = const Offset(0, 0),
  });

  @override
  State<UnreadDot> createState() => _UnreadDotState();
}

class _UnreadDotState extends State<UnreadDot> {
  final MessagingService _messagingService = MessagingService();
  StreamSubscription? _subscription;
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _subscribeToUnreadCount();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToUnreadCount() {
    _subscription = _messagingService
        .streamTotalUnreadCount(widget.userId)
        .listen((count) {
      if (mounted) {
        setState(() => _hasUnread = count > 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_hasUnread)
          Positioned(
            right: widget.offset.dx,
            top: widget.offset.dy,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.dotColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Inline Unread Count Widget
/// For use in list items or tabs
class InlineUnreadCount extends StatefulWidget {
  final String userId;
  final Color backgroundColor;
  final Color textColor;

  const InlineUnreadCount({
    super.key,
    required this.userId,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
  });

  @override
  State<InlineUnreadCount> createState() => _InlineUnreadCountState();
}

class _InlineUnreadCountState extends State<InlineUnreadCount> {
  final MessagingService _messagingService = MessagingService();
  StreamSubscription? _subscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToUnreadCount();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToUnreadCount() {
    _subscription = _messagingService
        .streamTotalUnreadCount(widget.userId)
        .listen((count) {
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unreadCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _unreadCount > 99 ? '99+' : '$_unreadCount',
        style: TextStyle(
          color: widget.textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
