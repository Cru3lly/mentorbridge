import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationDebugDialog extends StatefulWidget {
  const NotificationDebugDialog({super.key});

  @override
  State<NotificationDebugDialog> createState() => _NotificationDebugDialogState();
}

class _NotificationDebugDialogState extends State<NotificationDebugDialog> {
  bool _isLoading = false;
  String _status = 'Checking...';
  String _details = '';

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking notification status...';
    });

    try {
      final isEnabled = await NotificationService.areNotificationsEnabled();
      final pendingNotifications = await NotificationService.getPendingNotifications();
      final fcmToken = await NotificationService.getFCMToken();

      setState(() {
        _status = isEnabled ? '✅ Notifications Enabled' : '❌ Notifications Disabled';
        _details = '''
📱 Status: ${isEnabled ? 'Enabled' : 'Disabled'}
📋 Pending: ${pendingNotifications.length} notifications
🔑 FCM Token: ${fcmToken != null ? '${fcmToken.substring(0, 20)}...' : 'None'}
📱 Platform: ${Theme.of(context).platform.name}
        '''.trim();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error checking status';
        _details = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting permission...';
    });

    try {
      final granted = await NotificationService.requestPermissions();
      
      if (granted) {
        setState(() {
          _status = '✅ Permission Granted!';
        });
        
        // Show test notification
        await NotificationService.showNotification(
          id: 999,
          title: '🎉 Test Notification',
          body: 'Notifications are working! You\'ll receive habit reminders.',
        );
      } else {
        setState(() {
          _status = '❌ Permission Denied';
          _details = 'Please enable notifications in device Settings > Apps > MentorBridge > Notifications';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error requesting permission';
        _details = 'Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
      await _checkNotificationStatus();
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: '🧪 Test Notification',
        body: 'This is a test notification from MentorBridge!',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications, color: Colors.blue),
          SizedBox(width: 8),
          Text('Notification Debug'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _details,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checkNotificationStatus,
          child: const Text('Refresh'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _requestPermission,
          child: const Text('Request Permission'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _sendTestNotification,
          child: const Text('Test Notification'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
