import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Map<String, bool> _likingStates = {}; // Track animation states for each folder
  int? _selectedNoteIndex;

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
      QuerySnapshot snapshot = await _firestore
          .collection('sharedFolders')
          .get();
      
      List<Map<String, dynamic>> folders = snapshot.docs.map((doc) {
        dynamic iconData = doc['icon'];
        String icon;
        if (iconData is String) {
          icon = iconData;
        } else {
          icon = 'assets/icons/c++.svg';
        }

        // Initialize likes and likedBy if they don't exist
        if (!doc.data().toString().contains('likes')) {
          doc.reference.update({
            'likes': 0,
            'likedBy': [],
          });
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
      
      folders.sort((a, b) => (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime));
      
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
      final folderDoc = await _firestore.collection('sharedFolders').doc(folderId).get();
      if (!folderDoc.exists) {
        throw Exception('Folder not found');
      }

      // Get notes from sharedNotes collection
      QuerySnapshot snapshot = await _firestore
          .collection('sharedNotes')
          .where('sharedFolderId', isEqualTo: folderId)
        .get();

    setState(() {
        _folderNotes = snapshot.docs.map((doc) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
    return _sharedFolders.where((folder) => 
      folder['name'].toLowerCase().contains(_searchController.text.toLowerCase())
    ).toList();
  }

  List<Map<String, dynamic>> get _filteredNotes {
    if (_searchController.text.isEmpty) {
      return _folderNotes;
    }
    return _folderNotes.where((note) => 
      (note['title']?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false) ||
      (note['code']?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false)
    ).toList();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(top: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
              hintText: _selectedFolderId == null ? 'Search shared folders...' : 'Search notes...',
                prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {}); // Rebuild the UI when search text changes
            },
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _selectedFolderId == null ? _buildFoldersView() : _buildNotesView(),
    );
  }

  Widget _buildFoldersView() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredFolders.length,
              itemBuilder: (context, index) {
        final folder = _filteredFolders[index];
        final isLiked = folder['likedBy']?.contains(_auth.currentUser?.uid) ?? false;
        final isAnimating = _likingStates[folder['id']] ?? false;
        final isOwner = folder['ownerId'] == _auth.currentUser?.uid;
        
        return Container(
          height: 100,
          margin: EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _loadFolderNotes(folder['id']),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: _buildFolderIcon(folder['icon']),
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
                                icon: Icon(Icons.stop_circle, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Stop Sharing Folder'),
                                      content: Text('Are you sure you want to stop sharing this folder?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _stopSharingFolder(folder['id']);
                                          },
                                          child: Text('Stop Sharing', style: TextStyle(color: Colors.red)),
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
                                  isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
                                  color: isLiked ? Colors.blue : Colors.grey,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: isAnimating ? null : () => _toggleLike(folder['id']),
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

  Widget _buildNotesView() {
    String currentFolderName = _sharedFolders
        .firstWhere((folder) => folder['id'] == _selectedFolderId,
            orElse: () => {'name': 'Unknown Folder'})['name'];

    if (_selectedNoteIndex != null) {
      return Column(
        children: [
          ListTile(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedNoteIndex = null;
                });
              },
            ),
            title: Text(
              _filteredNotes[_selectedNoteIndex!]['title'],
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (_filteredNotes[_selectedNoteIndex!]['imageUrl'] != null)
                    Container(
                      width: double.infinity,
                      height: 200,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_filteredNotes[_selectedNoteIndex!]['imageUrl']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    child: SelectableText(
                      _filteredNotes[_selectedNoteIndex!]['code'],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _selectedFolderId = null;
                _folderNotes.clear();
                _selectedNoteIndex = null;
              });
            },
          ),
          title: Text(currentFolderName),
        ),
        Expanded(
          child: _folderNotes.isEmpty
              ? Center(
                  child: Text(
                    'No notes in this folder',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = _filteredNotes[index];
                    return Card(
                      margin: EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedNoteIndex = index;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (note['imageUrl'] != null)
                                    Container(
                                      width: 50,
                                      height: 50,
                                      margin: EdgeInsets.only(right: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: NetworkImage(note['imageUrl']),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note['title'] ?? 'Untitled',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          note['code'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFolderIcon(String iconPath) {
    double size = 60; // Default size for display
    if (iconPath.contains('flutter')) {
      size = 45; // Smaller size for Flutter
    } else if (iconPath.contains('html')) {
      size = 70; // Larger size for HTML
    }

    return Container(
      width: 60, // Fixed width for all icons
      height: 60, // Fixed height for all icons
      padding: EdgeInsets.all(8),
      child: Center(
        child: SvgPicture.asset(
          iconPath,
          color: Theme.of(context).primaryColor,
          width: size, // Variable icon size
          height: size, // Variable icon size
        ),
      ),
    );
  }
}

//Needs fields , shared_notes/{noteId}/comments (with fields text, user, timestamp)
//Likes field in each shared_notes document