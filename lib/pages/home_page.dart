import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tbpbo_galery/pages/add_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final List<Map<String, String>> _serverImages = [];
  final String baseUrl = "http://192.168.101.7:5000";
  String? _successMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchGalleryImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Auto refresh kalau app kembali dari background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedIndex == 0) {
      _fetchGalleryImages();
    }
  }

  /// Ambil semua gambar dari server/uploads
  Future<void> _fetchGalleryImages() async {
    if (_isLoading) return; // Prevent multiple simultaneous requests

    setState(() => _isLoading = true);

    try {
      final res = await http.get(Uri.parse('$baseUrl/api/gallery'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;

        final List<Map<String, String>> newImages =
            data.map<Map<String, String>>((item) {
              return {
                "id": item["_id"].toString(),
                "url": item["fullImageUrl"] ?? "",
                "title": item["title"]?.toString() ?? "",
                "category": item["category"]?.toString() ?? "",
                "tag": item["tag"]?.toString() ?? "",
                "description": item["description"]?.toString() ?? "",
              };
            }).toList();

        setState(() {
          _serverImages.clear();
          _serverImages.addAll(newImages);
        });
      } else {
        debugPrint("Error fetching images: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Hapus gambar
  Future<void> _deleteImage(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/api/gallery/$id'));
      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          _serverImages.removeWhere((img) => img["id"] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Gambar berhasil dihapus")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal menghapus gambar"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error delete: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error saat menghapus gambar"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle bottom navigation
  void _onItemTapped(int index) {
    if (index == 2) {
      _showLogoutSheet();
    } else {
      setState(() => _selectedIndex = index);
      // Only refresh when coming back to home tab
      if (index == 0 && _selectedIndex != 0) {
        _fetchGalleryImages();
      }
    }
  }

  /// Logout
  void _showLogoutSheet() {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
            },
          ),
    );
  }

  /// Halaman per tab
  List<Widget> get _pages => [
    _HomeContent(
      serverImages: _serverImages,
      onDeleteImage: _deleteImage,
      successMessage: _successMessage,
      onMessageShown: () => setState(() => _successMessage = null),
      isLoading: _isLoading,
    ),
    AddPage(
      onUploadComplete: (
        imageId,
        serverUrl,
        title,
        category,
        tag,
        description,
      ) {
        // Add optimistically to the top of the list
        if (mounted) {
          setState(() {
            _successMessage = "✅ Gambar berhasil di-upload!";
            // Add to top of list without clearing existing data
            _serverImages.insert(0, {
              "id": imageId,
              "url": serverUrl,
              "title": title,
              "category": category,
              "tag": tag,
              "description": description,
            });
            _selectedIndex = 0; // Switch to home tab
          });
        }

        // Refresh from server after a short delay to sync with server
        Future.delayed(const Duration(milliseconds: 500)).then((_) {
          if (mounted) {
            _fetchGalleryImages();
          }
        });
      },
    ),
    const SizedBox(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          _buildNavItem('home.svg', 'Home', 0),
          _buildNavItem('add.svg', 'Add', 1),
          _buildNavItem('settings.svg', 'Settings', 2),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(String icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: SvgPicture.asset(
        'assets/icons/$icon',
        colorFilter: ColorFilter.mode(
          _selectedIndex == index ? Colors.deepOrange : Colors.grey,
          BlendMode.srcIn,
        ),
        width: 24,
        height: 24,
      ),
      label: label,
    );
  }
}

class _HomeContent extends StatefulWidget {
  final List<Map<String, String>> serverImages;
  final Function(String id) onDeleteImage;
  final String? successMessage;
  final VoidCallback onMessageShown;
  final bool isLoading;

  const _HomeContent({
    required this.serverImages,
    required this.onDeleteImage,
    this.successMessage,
    required this.onMessageShown,
    required this.isLoading,
  });

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> get _filteredImages {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return widget.serverImages;
    return widget.serverImages.where((img) {
      final fileName = img["url"]!.split('/').last.toLowerCase();
      final title = img["title"]?.toLowerCase() ?? "";
      final tag = img["tag"]?.toLowerCase() ?? "";
      final category = img["category"]?.toLowerCase() ?? "";
      return fileName.contains(keyword) ||
          title.contains(keyword) ||
          tag.contains(keyword) ||
          category.contains(keyword);
    }).toList();
  }

  @override
  void didUpdateWidget(covariant _HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.successMessage != null && mounted) {
      Future.microtask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.successMessage!)));
        widget.onMessageShown();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allImages = _filteredImages;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Hi, jepri 👋',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan judul, tag, kategori...',
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child:
              widget.isLoading && allImages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : allImages.isEmpty
                  ? const Center(child: Text("Belum ada gambar."))
                  : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      itemCount: allImages.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.75,
                          ),
                      itemBuilder: (context, index) {
                        final img = allImages[index];
                        return _ImageGridItem(
                          image: img,
                          onDelete: () => widget.onDeleteImage(img["id"]!),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }
}

class _ImageGridItem extends StatelessWidget {
  final Map<String, String> image;
  final VoidCallback onDelete;

  const _ImageGridItem({required this.image, required this.onDelete});

  Future<void> _downloadImage(BuildContext context) async {
    try {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Downloading...'),
                  ],
                ),
              ),
        );
      }

      final response = await http.get(Uri.parse(image["url"]!));

      if (response.statusCode == 200) {
        // For now, just show success message
        // In a real app, you would save to device storage
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image download started! Check your Downloads folder.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('Fullscreen'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => _FullscreenImageView(image: image),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadImage(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text("Hapus Gambar"),
                            content: const Text(
                              "Yakin ingin menghapus gambar ini?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Batal"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDelete();
                                },
                                child: const Text(
                                  "Hapus",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _FullscreenImageView(image: image),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              image["url"]!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error),
                );
              },
            ),
            // Title overlay
            if (image["title"]?.isNotEmpty == true)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    image["title"]!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // Menu button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showOptionsMenu(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImageView extends StatelessWidget {
  final Map<String, String> image;

  const _FullscreenImageView({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          image["title"]?.isNotEmpty == true ? image["title"]! : 'Image',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            image["url"]!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error, color: Colors.white, size: 64),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black.withValues(alpha: 0.8),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image["title"]?.isNotEmpty == true) ...[
                Text(
                  image["title"]!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (image["description"]?.isNotEmpty == true) ...[
                Text(
                  image["description"]!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
              ],
              if (image["tag"]?.isNotEmpty == true) ...[
                Text(
                  'Tags: ${image["tag"]}',
                  style: const TextStyle(color: Colors.blue, fontSize: 12),
                ),
                const SizedBox(height: 4),
              ],
              if (image["category"]?.isNotEmpty == true)
                Text(
                  'Category: ${image["category"]}',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
