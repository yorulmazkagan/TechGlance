import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const TechGlanceApp());
}

class TechGlanceApp extends StatefulWidget {
  const TechGlanceApp({super.key});

  @override
  State<TechGlanceApp> createState() => _TechGlanceAppState();
}

class _TechGlanceAppState extends State<TechGlanceApp> {
  Key _uniqueKey = UniqueKey();

  void restartApp() {
    setState(() {
      _uniqueKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _uniqueKey,
      debugShowCheckedModeBanner: false,
      title: 'TechGlance',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.tealAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: TechFeedScreen(onLanguageChanged: restartApp),
    );
  }
}

class TechFeedScreen extends StatefulWidget {
  final VoidCallback onLanguageChanged;
  const TechFeedScreen({super.key, required this.onLanguageChanged});

  @override
  State<TechFeedScreen> createState() => _TechFeedScreenState();
}

class _TechFeedScreenState extends State<TechFeedScreen> {
  GenerativeModel? _model;
  List<Map<String, String>> _newsList = [];
  bool _isLoading = false;
  String _statusMessage = "Initializing...";
  Timer? _refreshTimer;

  String _userApiKey = "";
  int _articleCount = 5;
  String _selectedLanguage = "tr";
  
  List<String> _rssUrls = [
    "https://news.ycombinator.com/rss",
    "https://github.blog/category/engineering/feed/",
    "http://export.arxiv.org/rss/cs.AI",
  ];

  final Map<String, Map<String, String>> _localizedStrings = {
    'tr': {
      'title': 'TechGlance',
      'settings': 'Ayarlar',
      'apiKey': 'Gemini API Anahtarı',
      'apiKeyHint': 'AI Studio anahtarını buraya yapıştır...',
      'articleCount': 'Kaynak Başına Haber:',
      'language': 'Dil / Language:',
      'rssSources': 'RSS Kaynakları:',
      'rssHint': 'RSS Linki ekle (https://...)',
      'save': 'KAYDET VE YENİLE',
      'noNews': 'Haber yok veya Ayar yapılmadı.',
      'openSettings': 'Ayarları Aç',
      'scanning': 'Taranıyor:',
      'aiError': 'Özetlenemedi (Orijinal Metin)',
      'generalError': 'Hata:',
      'missingKey': 'API Anahtarı Eksik!',
      'promptLang': 'TURKISH',
      'cacheLoaded': 'Önbellekten yüklendi (Offline)',
      'cacheCleared': 'Eski veriler temizlendi.',
    },
    'en': {
      'title': 'TechGlance',
      'settings': 'Settings',
      'apiKey': 'Gemini API Key',
      'apiKeyHint': 'Paste AI Studio key here...',
      'articleCount': 'News Per Source:',
      'language': 'Language / Dil:',
      'rssSources': 'RSS Sources:',
      'rssHint': 'Add RSS Link (https://...)',
      'save': 'SAVE & REFRESH',
      'noNews': 'No news or settings missing.',
      'openSettings': 'Open Settings',
      'scanning': 'Scanning:',
      'aiError': 'Summarization Failed (Original Text)',
      'generalError': 'Error:',
      'missingKey': 'API Key Missing!',
      'promptLang': 'ENGLISH',
      'cacheLoaded': 'Loaded from cache (Offline)',
      'cacheCleared': 'Old data cleared.',
    }
  };

  String t(String key) => _localizedStrings[_selectedLanguage]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndStart();

    _refreshTimer = Timer.periodic(const Duration(hours: 12), (Timer t) {
      debugPrint("⏰ [AUTO-REFRESH] 12 hours passed...");
      _fetchAndProcessNews();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettingsAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    
    setState(() {
      _userApiKey = prefs.getString('user_api_key') ?? "";
      _articleCount = prefs.getInt('user_article_count') ?? 5;
      _selectedLanguage = prefs.getString('user_language') ?? "tr";
      
      List<String>? savedRss = prefs.getStringList('user_rss_list');
      if (savedRss != null && savedRss.isNotEmpty) {
        _rssUrls = savedRss;
      }
    });

    await _loadCachedNews();

    if (_userApiKey.isEmpty) {
      if (_newsList.isEmpty) setState(() => _statusMessage = t('noNews'));
    } else {
      _initModelAndFetch();
    }
  }

  Future<void> _loadCachedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastSavedTime = prefs.getInt('news_timestamp');
    
    if (lastSavedTime != null) {
      final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSavedTime));
      if (diff.inHours >= 24) {
        await prefs.remove('cached_news');
        await prefs.remove('news_timestamp');
        return;
      }
    }

    final String? jsonString = prefs.getString('cached_news');
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final List<Map<String, String>> cachedList = decoded.map((item) {
          return Map<String, String>.from(item);
        }).toList();

        if (mounted) setState(() => _newsList = cachedList);
      } catch (e) {
        debugPrint("❌ [CACHE] Error: $e");
      }
    }
  }

  Future<void> _saveNewsToCache(List<Map<String, String>> news) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(news);
    
    await prefs.setString('cached_news', jsonString);
    await prefs.setInt('news_timestamp', DateTime.now().millisecondsSinceEpoch);
    
    try {
      await HomeWidget.updateWidget(
        name: 'NewsWidgetProvider',
        androidName: 'NewsWidgetProvider',
      );
      debugPrint("📲 [WIDGET] Widget update signal sent.");
    } catch (e) {
      debugPrint("❌ [WIDGET] Update failed: $e");
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_api_key', _userApiKey);
    await prefs.setInt('user_article_count', _articleCount);
    await prefs.setStringList('user_rss_list', _rssUrls);
    await prefs.setString('user_language', _selectedLanguage);
    
    widget.onLanguageChanged();
    _initModelAndFetch();
  }

  void _initModelAndFetch() {
    if (_userApiKey.isEmpty) {
      if (_newsList.isEmpty) setState(() => _statusMessage = t('missingKey'));
      return;
    }
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _userApiKey);
    _fetchAndProcessNews();
  }

  Future<void> _fetchAndProcessNews() async {
    if (_model == null) return;
    if (mounted) setState(() => _isLoading = true);

    List<Map<String, String>> tempNews = [];

    try {
      for (String url in _rssUrls) {
        if (!mounted) return;
        setState(() => _statusMessage = "${t('scanning')} ${_extractDomain(url)}");

        try {
          var response = await http.get(Uri.parse(url));
          
          if (response.statusCode == 200) {
            var rssFeed = RssFeed.parse(response.body);
            
            if (rssFeed.items != null) {
              for (var item in rssFeed.items!.take(_articleCount)) {
                String title = item.title ?? "Untitled";
                String link = item.link ?? "";
                String description = item.description ?? item.content?.value ?? "";

                await Future.delayed(const Duration(seconds: 2));

                String summary = await _getAiSummary(title, link, description);
                
                if (summary.contains("AI Hatası") || summary == "Empty") {
                   debugPrint("⚠️ AI Failed for $title, using fallback.");
                   summary = description.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                   if (summary.isEmpty) summary = title; 
                   if (summary.length > 150) summary = "${summary.substring(0, 150)}...";
                }

                if (!summary.contains("SKIP")) {
                  tempNews.add({
                    "source": _extractDomain(url),
                    "title": title,
                    "summary": summary,
                    "link": link,
                    "time": DateFormat('HH:mm').format(DateTime.now()),
                    "type": _determineType(title),
                  });
                }
              }
            }
          }
        } catch (e) {
          debugPrint("⚠️ RSS Fetch Error ($url): $e");
        }
      }

      if (mounted) {
        setState(() {
          _newsList = tempNews;
          _isLoading = false;
        });
        _saveNewsToCache(tempNews);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "${t('generalError')} $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _getAiSummary(String title, String link, String description) async {
    if (_model == null) return "AI Null";

    String targetLang = t('promptLang'); 

    final prompt = [
      Content.text("""
      ROLE: Tech Editor.
      TASK: Summarize for Engineers.
      
      DATA:
      Title: $title
      Snippet: $description

      RULES:
      1. FILTER: If shopping/gossip/stock -> Output 'SKIP'.
      2. SUMMARIZE: Write ONE sentence in **$targetLang**.
      3. TONE: Technical & Direct.

      OUTPUT: Only summary.
      """)
    ];

    try {
      final response = await _model!.generateContent(prompt);
      return response.text?.replaceAll("Özet:", "").trim() ?? "Empty";
    } catch (e) {
      debugPrint("❌ Gemini Error: $e");
      return "AI Hatası";
    }
  }

  String _extractDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      String domain = uri.host.replaceFirst("www.", "");
      return domain.split('.').first.toUpperCase();
    } catch (e) {
      return "RSS";
    }
  }

  String _determineType(String title) {
    String t = title.toLowerCase();
    if (t.contains("paper") || t.contains("arxiv")) return "science";
    if (t.contains("code") || t.contains("linux") || t.contains("github")) return "repo";
    if (t.contains("ai") || t.contains("gpt") || t.contains("llm")) return "ai";
    return "article";
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Link error: $url');
    }
  }

  void _showSettingsModal() {
    final apiKeyController = TextEditingController(text: _userApiKey);
    final rssController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 16
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("⚙️ ${t('settings')}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    Text(t('apiKey'), style: const TextStyle(color: Colors.blueAccent)),
                    TextField(
                      controller: apiKeyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: t('apiKeyHint'),
                        hintStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(t('language'), style: const TextStyle(color: Colors.blueAccent)),
                    DropdownButton<String>(
                      value: _selectedLanguage,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: "tr", child: Text("Türkçe")),
                        DropdownMenuItem(value: "en", child: Text("English")),
                      ],
                      onChanged: (String? newValue) {
                        setModalState(() {
                          _selectedLanguage = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    Text("${t('articleCount')} $_articleCount", style: const TextStyle(color: Colors.blueAccent)),
                    Slider(
                      value: _articleCount.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: Colors.blueAccent,
                      label: _articleCount.toString(),
                      onChanged: (double value) {
                        setModalState(() {
                          _articleCount = value.toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    Text(t('rssSources'), style: const TextStyle(color: Colors.blueAccent)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rssController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: t('rssHint'),
                              hintStyle: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () {
                            if (rssController.text.isNotEmpty) {
                              setModalState(() {
                                _rssUrls.add(rssController.text.trim());
                                rssController.clear();
                              });
                            }
                          },
                        )
                      ],
                    ),
                    
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _rssUrls.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_rssUrls[index], style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                              onPressed: () {
                                setModalState(() {
                                  _rssUrls.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                        onPressed: () {
                          setState(() {
                            _userApiKey = apiKeyController.text.trim();
                          });
                          _saveSettings();
                          Navigator.pop(context);
                        },
                        child: Text(t('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initModelAndFetch,
          )
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _newsList.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings_suggest, size: 60, color: Colors.grey),
                    const SizedBox(height: 20),
                    Text(t('noNews'), style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _showSettingsModal, 
                      child: Text(t('openSettings'), style: const TextStyle(color: Colors.blueAccent))
                    )
                  ],
                ),
              )
            : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _newsList.length,
              itemBuilder: (context, index) {
                final news = _newsList[index];
                return GestureDetector(
                  onTap: () => _launchURL(news["link"]!),
                  child: NewsCard(news: news),
                );
              },
            ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final Map<String, String> news;
  const NewsCard({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _getIcon(news["type"]!),
                  const SizedBox(width: 8),
                  Text(
                    news["source"]!.length > 15 ? "${news["source"]!.substring(0, 12)}..." : news["source"]!,
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
              Text(news["time"]!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            news["summary"]!,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _getIcon(String type) {
    switch (type) {
      case 'ai': return const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 18);
      case 'repo': return const Icon(Icons.code, color: Colors.greenAccent, size: 18);
      case 'science': return const Icon(Icons.science, color: Colors.tealAccent, size: 18);
      case 'hardware': return const Icon(Icons.memory, color: Colors.orangeAccent, size: 18);
      default: return const Icon(Icons.article, color: Colors.blue, size: 18);
    }
  }
}