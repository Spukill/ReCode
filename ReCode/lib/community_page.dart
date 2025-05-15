import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'raccomandad_note.dart';
import 'related_note.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({Key? key, required this.isLoading, required this.child})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class CodeSharingPage extends StatefulWidget {
  @override
  _CodeSharingPageState createState() => _CodeSharingPageState();
}

class _CodeSharingPageState extends State<CodeSharingPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _sharedFolders = [];
  String? _selectedFolderId;
  List<Map<String, dynamic>> _folderNotes = [];
  bool _isLoading = false;
  Map<String, bool> _likingStates =
      {}; // Track animation states for each folder
  int? _selectedNoteIndex;

  final List<Map<String, String>> _availableLanguages = [
    {'icon': 'assets/icons/c++.svg', 'name': 'C++'},
    {'icon': 'assets/icons/java.svg', 'name': 'Java'},
    {'icon': 'assets/icons/python.svg', 'name': 'Python'},
    {'icon': 'assets/icons/c.svg', 'name': 'C'},
    {'icon': 'assets/icons/html.svg', 'name': 'HTML'},
    {'icon': 'assets/icons/flutter.svg', 'name': 'Flutter'},
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadSharedFolders();
    _searchController.addListener(() {
      setState(() {}); // Rebuild the UI when search text changes
    });
  }

  Future<void> _loadSharedFolders() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot =
          await _firestore.collection('sharedFolders').get();

      List<Map<String, dynamic>> folders =
          snapshot.docs.map((doc) {
            dynamic iconData = doc['icon'];
            String icon;
            if (iconData is String) {
              icon = iconData;
            } else {
              icon = 'assets/icons/c++.svg';
            }

            // Initialize likes and likedBy if they don't exist
            if (!doc.data().toString().contains('likes')) {
              doc.reference.update({'likes': 0, 'likedBy': []});
            }

            return {
              'id': doc.id,
              'name': doc['name'],
              'icon': icon,
              'createdAt': doc['createdAt']?.toDate() ?? DateTime.now(),
              'ownerId': doc['ownerId'],
              'ownerName': doc['ownerName'],
              'likes': doc['likes'] ?? 0,
              'likedBy': List<String>.from(doc['likedBy'] ?? []),
            };
          }).toList();

      folders.sort(
        (a, b) =>
            (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime),
      );

      setState(() {
        _sharedFolders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading shared folders: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleLike(String folderId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _likingStates[folderId] = true);
    try {
      final folderRef = _firestore.collection('sharedFolders').doc(folderId);
      final folderIndex = _sharedFolders.indexWhere((f) => f['id'] == folderId);
      if (folderIndex == -1) return;

      final folder = _sharedFolders[folderIndex];
      final likedBy = List<String>.from(folder['likedBy'] ?? []);
      final isLiked = likedBy.contains(user.uid);

      if (isLiked) {
        likedBy.remove(user.uid);
        await folderRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': likedBy,
        });
        setState(() {
          _sharedFolders[folderIndex]['likes'] = (folder['likes'] ?? 0) - 1;
          _sharedFolders[folderIndex]['likedBy'] = likedBy;
        });
      } else {
        likedBy.add(user.uid);
        await folderRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': likedBy,
        });
        setState(() {
          _sharedFolders[folderIndex]['likes'] = (folder['likes'] ?? 0) + 1;
          _sharedFolders[folderIndex]['likedBy'] = likedBy;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating like: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => _likingStates.remove(folderId));
    }
  }

  Future<void> _loadFolderNotes(String folderId) async {
    setState(() => _isLoading = true);
    try {
      // First get the shared folder to get the original folder ID
      final folderDoc =
          await _firestore.collection('sharedFolders').doc(folderId).get();
      if (!folderDoc.exists) {
        throw Exception('Folder not found');
      }

      // Get notes from sharedNotes collection
      QuerySnapshot snapshot =
          await _firestore
              .collection('sharedNotes')
              .where('sharedFolderId', isEqualTo: folderId)
              .get();

      setState(() {
        _folderNotes =
            snapshot.docs.map((doc) {
              return {
                'id': doc.id,
                'title': doc['title'],
                'code': doc['code'],
                'imageUrl': doc['imageUrl'],
                'ownerName': doc['ownerName'],
              };
            }).toList();
        _selectedFolderId = folderId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _selectedFolderId = folderId;
      });
      print('Error loading folder notes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading folder notes: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _getIconName(String iconPath) {
    if (iconPath.contains('c++')) return 'C++';
    if (iconPath.contains('java')) return 'Java';
    if (iconPath.contains('python')) return 'Python';
    if (iconPath.contains('c.svg')) return 'C';
    if (iconPath.contains('html')) return 'HTML';
    if (iconPath.contains('flutter')) return 'Flutter';
    return 'Unknown';
  }

  List<Map<String, dynamic>> get _filteredFolders {
    if (_searchController.text.isEmpty) {
      return _sharedFolders;
    }
    return _sharedFolders
        .where(
          (folder) => folder['name'].toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredNotes {
    if (_searchController.text.isEmpty) {
      return _folderNotes;
    }
    return _folderNotes
        .where(
          (note) =>
              (note['title']?.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ) ??
                  false) ||
              (note['code']?.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  Future<void> _stopSharingFolder(String folderId) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('sharedFolders').doc(folderId).delete();

      setState(() {
        _sharedFolders.removeWhere((folder) => folder['id'] == folderId);
        if (_selectedFolderId == folderId) {
          _selectedFolderId = null;
          _folderNotes.clear();
        }
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder is no longer shared'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping folder sharing: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Programming Language',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Container(
                  width: double.maxFinite,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children:
                        _availableLanguages.map((language) {
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => RecommendedNotesPage(
                                        language:
                                            language['name']!.toLowerCase(),
                                      ),
                                ),
                              );
                            },
                            child: Container(
                              width: 80,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SvgPicture.asset(
                                      language['icon']!,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    language['name']!,
                                    style: TextStyle(fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search folders...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Language selection button
            Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _showLanguageSelectionDialog,
                icon: Icon(Icons.code),
                label: Text('Select Programming Language'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildFoldersView()),
          ],
        ),
      ),
    );
  }

  Widget _buildFoldersView() {
    if (_filteredFolders.isEmpty) {
      return Center(
        child: Text(
          'No folders found',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredFolders.length,
      itemBuilder: (context, index) {
        final folder = _filteredFolders[index];
        final isLiked =
            folder['likedBy']?.contains(_auth.currentUser?.uid) ?? false;
        final isAnimating = _likingStates[folder['id']] ?? false;
        final isOwner = folder['ownerId'] == _auth.currentUser?.uid;

        return Container(
          height: 100,
          margin: EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderNotesPage(folder: folder),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      padding: EdgeInsets.all(8),
                      child: SvgPicture.asset(
                        folder['icon'],
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                folder['name'],
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOwner)
                              IconButton(
                                icon: Icon(
                                  Icons.stop_circle,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: Text('Stop Sharing Folder'),
                                          content: Text(
                                            'Are you sure you want to stop sharing this folder?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _stopSharingFolder(
                                                  folder['id'],
                                                );
                                              },
                                              child: Text(
                                                'Stop Sharing',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                              ),
                          ],
                        ),
                        Text(
                          'Shared by: ${folder['ownerName']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: IconButton(
                                key: ValueKey(isLiked),
                                icon: Icon(
                                  isLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_off_alt,
                                  color: isLiked ? Colors.blue : Colors.grey,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed:
                                    isAnimating
                                        ? null
                                        : () => _toggleLike(folder['id']),
                              ),
                            ),
                            Text(
                              '${folder['likes'] ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FolderNotesPage extends StatefulWidget {
  final Map<String, dynamic> folder;

  const FolderNotesPage({Key? key, required this.folder}) : super(key: key);

  @override
  _FolderNotesPageState createState() => _FolderNotesPageState();
}

class _FolderNotesPageState extends State<FolderNotesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  int? _selectedNoteIndex;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(() {
      setState(() {}); // Rebuild the UI when search text changes
    });
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('sharedNotes')
              .where('sharedFolderId', isEqualTo: widget.folder['id'])
              .get();

      setState(() {
        _notes =
            snapshot.docs.map((doc) {
              return {
                'id': doc.id,
                'title': doc['title'],
                'code': doc['code'],
                'imageUrl': doc['imageUrl'],
                'ownerName': doc['ownerName'],
                'tag': doc['tag'] ?? 'dummies',
              };
            }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading notes: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredNotes {
    if (_searchController.text.isEmpty) {
      return _notes;
    }
    return _notes
        .where(
          (note) =>
              note['title'].toLowerCase().contains(
                _searchController.text.toLowerCase(),
              ) ||
              note['code'].toLowerCase().contains(
                _searchController.text.toLowerCase(),
              ),
        )
        .toList();
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'dummies':
        return Colors.green;
      case 'basic':
        return Colors.blue;
      case 'advanced':
        return Colors.orange;
      case 'externalLibs':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCodeBlock(String text) {
    final codeBlocks = text.split('---');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children:
          codeBlocks.asMap().entries.map((entry) {
            final index = entry.key;
            final block = entry.value;

            if (index % 2 == 1) {
              // This is a code block (odd indices)
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: HighlightView(
                  block.trim(),
                  language: 'cpp', // Default to C++
                  theme: githubTheme,
                  padding: EdgeInsets.zero,
                  textStyle: TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              );
            } else {
              // This is regular text (even indices)
              final spans = <TextSpan>[];
              var currentText = block;

              // Process bold text
              while (currentText.contains('**')) {
                final partsBefore = currentText.split('**');
                if (partsBefore.length > 1) {
                  spans.add(
                    TextSpan(
                      text: partsBefore[0],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  );
                  spans.add(
                    TextSpan(
                      text: partsBefore[1],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                  currentText = partsBefore.sublist(2).join('**');
                } else {
                  break;
                }
              }

              // Add any remaining text
              if (currentText.isNotEmpty) {
                spans.add(
                  TextSpan(
                    text: currentText,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SelectableText.rich(TextSpan(children: spans)),
              );
            }
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search notes...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _selectedNoteIndex != null
              ? _buildNoteDetails()
              : _buildNotesList(),
    );
  }

  Widget _buildNotesList() {
    if (_filteredNotes.isEmpty) {
      return Center(
        child: Text(
          'No notes in this folder',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              setState(() => _selectedNoteIndex = index);
            },
            child: ListTile(
              leading:
                  note['imageUrl'] != null
                      ? Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(note['imageUrl']),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      : null,
              title: Text(
                note['title'],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By ${note['ownerName']}'),
                  SizedBox(height: 4),
                  Chip(
                    label: Text(
                      note['tag'].toString().substring(0, 1).toUpperCase() +
                          note['tag'].toString().substring(1),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: _getTagColor(note['tag'].toString()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteDetails() {
    final note = _filteredNotes[_selectedNoteIndex!];
    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() => _selectedNoteIndex = null);
            },
          ),
          title: Text(
            note['title'],
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          subtitle: Text('By ${note['ownerName']}'),
          trailing: IconButton(
            icon: Icon(Icons.compare_arrows),
            tooltip: 'Show similar notes in other languages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => RelatedNotesPage(
                        originalNote: note,
                        currentLanguage:
                            widget.folder['icon'].toString().contains('c++')
                                ? 'C++'
                                : widget.folder['icon'].toString().contains(
                                  'java',
                                )
                                ? 'Java'
                                : widget.folder['icon'].toString().contains(
                                  'python',
                                )
                                ? 'Python'
                                : widget.folder['icon'].toString().contains(
                                  'c.svg',
                                )
                                ? 'C'
                                : widget.folder['icon'].toString().contains(
                                  'html',
                                )
                                ? 'HTML'
                                : widget.folder['icon'].toString().contains(
                                  'flutter',
                                )
                                ? 'Flutter'
                                : 'Unknown',
                      ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note['imageUrl'] != null)
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(note['imageUrl']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                _buildCodeBlock(note['code']),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

//Needs fields , shared_notes/{noteId}/comments (with fields text, user, timestamp)
//Likes field in each shared_notes document
