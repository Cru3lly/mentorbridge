import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class HelpCenter extends StatefulWidget {
  const HelpCenter({super.key});

  @override
  State<HelpCenter> createState() => _HelpCenterState();
}

class _HelpCenterState extends State<HelpCenter> {
  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'mentorbridgetoronto@gmail.com',
      query: Uri.encodeFull('subject=Support Request&body=Hello MentorBridge Team,'),
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening email client: $e')),
      );
    }
  }

  void _launchWebsite() async {
    final Uri websiteUri = Uri.parse('https://www.ctfcommunity.com/');
    try {
      if (await canLaunchUrl(websiteUri)) {
        await launchUrl(websiteUri);
      } else {
        throw 'Could not launch website';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening website: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Help Center'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'If you have questions, feel free to reach out to us anytime.',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _launchEmail,
              icon: const Icon(Icons.email),
              label: const Text('Email us'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _launchWebsite,
              icon: const Icon(Icons.public),
              label: const Text('Visit our website'),
            ),
          ],
        ),
      ),
    );
  }
}
