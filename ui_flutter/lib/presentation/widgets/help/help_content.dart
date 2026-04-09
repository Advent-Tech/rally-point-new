import 'package:flutter/material.dart';

class HelpContent {
  final String title;
  final String content;
  final String? imagePath;
  final List<HelpStep>? steps;

  const HelpContent({
    required this.title,
    required this.content,
    this.imagePath,
    this.steps,
  });
}

class HelpStep {
  final String title;
  final String description;
  final String? iconName;

  const HelpStep({
    required this.title,
    required this.description,
    this.iconName,
  });
}

class HelpContentProvider {
  static List<HelpContent> getHomeScreenHelp() {
    return [
      const HelpContent(
        title: 'Dashboard Overview',
        content:
            'Your home screen shows quick stats, recent activity, and quick actions.',
      ),
      const HelpContent(
        title: 'Quick Actions',
        content:
            'Tap any quick action tile to start logging visits, deliveries, or prayer requests.',
      ),
    ];
  }

  static List<HelpContent> getTerritoryHelp() {
    return [
      const HelpContent(
        title: 'Territory Map',
        content: 'View and manage your assigned territories on the map.',
      ),
      const HelpContent(
        title: 'Completing Territories',
        content: 'Mark territories as completed after finishing your work.',
      ),
    ];
  }

  static List<HelpContent> getDeliveryHelp() {
    return [
      const HelpContent(
        title: 'Log Delivery',
        content: 'Record deliveries with recipient info and notes.',
      ),
    ];
  }

  static List<HelpContent> getPrayerHelp() {
    return [
      const HelpContent(
        title: 'Prayer Requests',
        content: 'Submit and track prayer requests for your community.',
      ),
    ];
  }
}
