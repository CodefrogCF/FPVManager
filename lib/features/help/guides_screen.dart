import 'package:flutter/material.dart';

import 'guide_topics.dart';
export 'guide_topics.dart' show GuideTopic;

Future<void> openGuide(BuildContext context, GuideTopic topic) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => GuideArticleScreen(topic: topic)),
    );

class GuideLink extends StatelessWidget {
  const GuideLink(this.topic, {super.key, this.label});
  final GuideTopic topic;
  final String? label;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => openGuide(context, topic),
    icon: const Icon(Icons.help_outline),
    label: Text(label ?? 'Kurzhilfe: ${guideArticles[topic]!.title}'),
  );
}

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guides und Hilfe')),
    body: ListView.builder(
      itemCount: GuideTopic.values.length,
      itemBuilder: (context, index) {
        final topic = GuideTopic.values[index];
        return ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(guideArticles[topic]!.title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openGuide(context, topic),
        );
      },
    ),
  );
}

class GuideArticleScreen extends StatelessWidget {
  const GuideArticleScreen({super.key, required this.topic});
  final GuideTopic topic;
  @override
  Widget build(BuildContext context) {
    final article = guideArticles[topic]!;
    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: PageStorageKey(topic),
          padding: const EdgeInsets.all(20),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in article.sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              section.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            section.text,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
