import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
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
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ),
      ],
    );
  }
}

class CodeStoringPage extends StatefulWidget {
  @override
  _CodeStoringPageState createState() => _CodeStoringPageState();
}

class _CodeStoringPageState extends State<CodeStoringPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _folderNameController = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _folders = [];
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isAddingNote = false;
  bool _isAddingFolder = false;
  int? _editingIndex;
  String? _currentFolderId;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  String _selectedIcon = 'assets/icons/c++.svg';
  int? _selectedNoteIndex;
  bool _isLoading = false;
  String _selectedTag = 'dummies'; // Default tag value
  String _selectedConcept = ''; // e.g., 'printing', 'loops', etc.
  Set<String> _sharedFolderIds = {};
  int _currentFolderPage = 0;
  int _currentNotePage = 0;
  static const int _itemsPerPage = 10;

  final List<String> _availableIcons = [
    'assets/icons/c++.svg',
    'assets/icons/java.svg',
    'assets/icons/python.svg',
    'assets/icons/c.svg',
    'assets/icons/html.svg',
    'assets/icons/flutter.svg',
  ];

  final List<String> _availableTags = [
    'dummies',
    'basic',
    'advanced',
    'externalLibs',
  ];

  final List<String> _availableConcepts = [
    'printing',
    'variables',
    'loops',
    'conditionals',
    'functions',
    'arrays',
    'objects',
    // Add more concepts as needed
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _loadSharedFolders();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _searchController.addListener(() {
      setState(() {});
      _ensureNotePageInRange();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot =
            await _firestore
                .collection('folders')
          .where('userId', isEqualTo: user.uid)
          .get();

        List<Map<String, dynamic>> sortedFolders =
            snapshot.docs.map((doc) {
              dynamic iconData = doc['icon'];
              String icon;
              if (iconData is String) {
                icon = iconData;
              } else {
                icon = 'assets/icons/c++.svg';
              }

              return {
                'id': doc.id,
                'name': doc['name'],
                'icon': icon,
                'createdAt': doc['createdAt']?.toDate() ?? DateTime.now(),
              };
            }).toList();

        sortedFolders.sort(
          (a, b) => (a['createdAt'] as DateTime).compareTo(
            b['createdAt'] as DateTime,
          ),
        );

        if (mounted) {
      setState(() {
            _folders = sortedFolders;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading folders: ${e.toString()}'),
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
    }
  }

  Future<void> _loadNotes(String folderId) async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot snapshot =
          await _firestore
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .where('folderId', isEqualTo: folderId)
          .get();
      
      List<Map<String, dynamic>> sortedNotes = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'title': doc['title'],
            'code': doc['code'],
            'imageUrl': doc['imageUrl'],
          'tag': doc['tag'] ?? 'dummies',
          'createdAt': doc['createdAt']?.toDate() ?? DateTime.now(),
          };
        }).toList();
      
      // Sort by creation date, newest first
      sortedNotes.sort((a, b) => 
        (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime)
      );
      
      setState(() {
        _notes = sortedNotes;
        _currentFolderId = folderId;
        _currentNotePage = 0;
      });
    }
  }

  Future<void> _loadSharedFolders() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await _firestore
        .collection('sharedFolders')
        .where('ownerId', isEqualTo: user.uid)
        .get();
    setState(() {
      _sharedFolderIds = snapshot.docs
          .map((doc) => doc['originalFolderId'] as String)
          .toSet();
    });
  }

  Future<void> _addFolder() async {
    final name = _folderNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a folder name'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You must be logged in to create folders'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('folders').add({
        'userId': user.uid,
        'name': name,
        'icon': _selectedIcon,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _folderNameController.clear();
      setState(() {
        _isAddingFolder = false;
        _selectedIcon = 'assets/icons/c++.svg';
        _isLoading = false;
      });
      await _loadFolders();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating folder: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareFolder(
    String folderId,
    String folderName,
    String icon,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You must be logged in to share folders'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // First, get all notes from the folder
      QuerySnapshot notesSnapshot =
          await _firestore
              .collection('notes')
              .where('userId', isEqualTo: user.uid)
              .where('folderId', isEqualTo: folderId)
              .get();

      // Get the language from the folder's icon
      String language = _getLanguageFromIcon(icon);

      // Create the shared folder
      final sharedFolderRef = await _firestore.collection('sharedFolders').add({
        'name': folderName,
        'icon': icon,
        'ownerId': user.uid,
        'ownerName': user.email ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'originalFolderId': folderId,
        'language': language,
      });

      // Copy all notes to sharedNotes collection
      for (var doc in notesSnapshot.docs) {
        await _firestore.collection('sharedNotes').add({
          'sharedFolderId': sharedFolderRef.id,
          'originalNoteId': doc.id, // Store the original note ID
          'title': doc['title'],
          'code': doc['code'],
          'imageUrl': doc['imageUrl'],
          'tag': doc['tag'] ?? 'dummies', // Add tag field
          'createdAt': doc['createdAt'] ?? FieldValue.serverTimestamp(),
          'ownerId': user.uid,
          'ownerName': user.email ?? 'Anonymous',
          'language': language,
        });
      }

      setState(() => _isLoading = false);
      await _loadSharedFolders(); // Refresh shared folder ids
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folder shared successfully!'),
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
          content: Text('Error sharing folder: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

Future<void> _saveNote() async {
  final title = _titleController.text.trim();
  final codeSnippet = _codeController.text.trim();

  if (title.isEmpty && codeSnippet.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please add a title or code snippet')),
    );
    return;
  }

  final user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You must be logged in to save notes')),
    );
    return;
  }

    setState(() => _isLoading = true);
  try {
    String? imageUrl;
    
      // Handle image removal during editing
      if (_editingIndex != null && _image != null && _image!.path.isEmpty) {
        // Delete the old image if it exists
        if (_notes[_editingIndex!]['imageUrl'] != null) {
          try {
            final oldImageUrl = _notes[_editingIndex!]['imageUrl'];
            final storageRef = _storage.refFromURL(oldImageUrl);
            await storageRef.delete();
            print('Old image deleted successfully');
          } catch (e) {
            print('Error deleting old image: $e');
          }
        }
        imageUrl = null; // Set to null to remove the image
      }
      // Handle new image upload
      else if (_image != null && _image!.path.isNotEmpty) {
        try {
          // If editing a note and it has an old image, delete it first
          if (_editingIndex != null &&
              _notes[_editingIndex!]['imageUrl'] != null) {
            try {
              final oldImageUrl = _notes[_editingIndex!]['imageUrl'];
              final storageRef = _storage.refFromURL(oldImageUrl);
              await storageRef.delete();
              print('Old image deleted successfully');
            } catch (e) {
              print('Error deleting old image: $e');
              // Continue with the upload even if old image deletion fails
            }
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileExtension = _image!.path.split('.').last;
          final fileName = '${user.uid}_$timestamp.$fileExtension';

          final storageRef = _storage
              .ref()
              .child('note_images')
              .child(fileName);

          final metadata = SettableMetadata(
            contentType: 'image/$fileExtension',
            customMetadata: {
              'uploadedBy': user.uid,
              'timestamp': timestamp.toString(),
            },
          );

          final uploadTask = await storageRef.putFile(_image!, metadata);

          if (uploadTask.state == TaskState.success) {
      imageUrl = await storageRef.getDownloadURL();
            print('New image uploaded successfully: $imageUrl');
          } else {
            throw Exception('Failed to upload image: ${uploadTask.state}');
          }
        } catch (e) {
          setState(() => _isLoading = false);
          print('Error uploading image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading image: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
      }

    if (_editingIndex != null) {
        final noteId = _notes[_editingIndex!]['id'];
      final currentImageUrl = _notes[_editingIndex!]['imageUrl'];

        // Update the original note
        await _firestore.collection('notes').doc(noteId).update({
        'title': title,
        'code': codeSnippet,
        'imageUrl': imageUrl ?? currentImageUrl,
          'tag': _selectedTag, // Add tag field
        'updatedAt': FieldValue.serverTimestamp(),
      });

        // Find and update any shared versions of this note
        QuerySnapshot sharedNotesSnapshot =
            await _firestore
                .collection('sharedNotes')
                .where('originalNoteId', isEqualTo: noteId)
                .get();

        for (var doc in sharedNotesSnapshot.docs) {
          await doc.reference.update({
            'title': title,
            'code': codeSnippet,
            'imageUrl': imageUrl ?? currentImageUrl,
            'tag': _selectedTag, // Add tag field
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
    } else {
        // Get the language from the folder's icon
        final folderDoc =
            await _firestore.collection('folders').doc(_currentFolderId).get();
        final folderIcon = folderDoc.data()?['icon'] as String;
        final language = _getLanguageFromIcon(folderIcon);

        // Create the note with the concept field
        DocumentReference newNoteRef = await _firestore
            .collection('notes')
            .add({
        'userId': user.uid,
          'folderId': _currentFolderId,
        'title': title,
        'code': codeSnippet,
        'imageUrl': imageUrl,
          'tag': _selectedTag,
          'concept': _selectedConcept,
          'language': language,
        'createdAt': FieldValue.serverTimestamp(),
        });

        // If this note is in a shared folder, create a shared version
        QuerySnapshot sharedFoldersSnapshot =
            await _firestore
                .collection('sharedFolders')
                .where('originalFolderId', isEqualTo: _currentFolderId)
                .get();

        for (var folderDoc in sharedFoldersSnapshot.docs) {
          await _firestore.collection('sharedNotes').add({
            'sharedFolderId': folderDoc.id,
            'originalNoteId': newNoteRef.id,
            'title': title,
            'code': codeSnippet,
            'imageUrl': imageUrl,
            'tag': _selectedTag,
            'concept': _selectedConcept,
            'language': language,
            'createdAt': FieldValue.serverTimestamp(),
            'ownerId': user.uid,
            'ownerName': user.email ?? 'Anonymous',
          });
        }
      }

    _resetForm();
      if (_currentFolderId != null) {
        await _loadNotes(_currentFolderId!);
      }
      setState(() {
        _isLoading = false;
        _isAddingNote = false;
      });
  } catch (e) {
      setState(() => _isLoading = false);
      print('Error saving note: $e');
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving note: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
    );
  }
} 

void _resetForm() {
  _titleController.clear();
  _codeController.clear();
  _image = null;
  _isAddingNote = false;
  _editingIndex = null;
  _selectedTag = 'dummies'; // Reset tag to default value
}

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
          setState(() {
            _image = File(pickedFile.path);
          });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      if (_editingIndex != null) {
        // When editing, we need to track that we want to remove the image
        _image = File(''); // Set to empty file to indicate removal
      } else {
        _image = null;
      }
    });
  }

  void _editNote(int index) {
    setState(() {
      _titleController.text = _notes[index]['title'];
      _codeController.text = _notes[index]['code'];
      _selectedTag = _notes[index]['tag'] ?? 'dummies'; // Load existing tag
      _image = null;
      _isAddingNote = true;
      _editingIndex = index;
    });
  }

  Future<void> _deleteNote(int index) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('notes').doc(_notes[index]['id']).delete();
      print('Note deleted from Firestore');

      // Also delete from sharedNotes if it exists
      final sharedNotesSnapshot = await _firestore
        .collection('sharedNotes')
        .where('originalNoteId', isEqualTo: _notes[index]['id'])
        .get();
      for (var doc in sharedNotesSnapshot.docs) {
        await doc.reference.delete();
      }

      if (_notes[index]['imageUrl'] != null) {
        final imageUrl = _notes[index]['imageUrl'];
        try {
          print('Attempting to delete image: $imageUrl');

          final storageRef = _storage.refFromURL(imageUrl);
          print('Got storage reference');

          await storageRef.delete();
          print('Image deleted successfully');
        } catch (e) {
          print('Error deleting image: $e');
          try {
            final uri = Uri.parse(imageUrl);
            final path = uri.path.split('/o/')[1].split('?')[0];
            print('Extracted path: $path');

            final storageRef = _storage.ref().child(path);
            print('Created storage reference');

            await storageRef.delete();
            print('Image deleted successfully using alternative method');
          } catch (e2) {
            print('Error with alternative deletion method: $e2');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting image: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }

      setState(() {
        _notes.removeAt(index);
        _isLoading = false;
      });
      print('Note removed from local state');
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error deleting note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting note: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot notesSnapshot =
          await _firestore
              .collection('notes')
              .where('folderId', isEqualTo: folderId)
              .get();

      for (var doc in notesSnapshot.docs) {
        if (doc['imageUrl'] != null) {
          await _storage.refFromURL(doc['imageUrl']).delete();
        }
        await doc.reference.delete();
      }

      await _firestore.collection('folders').doc(folderId).delete();
      await _loadSharedFolders(); // Refresh shared folder ids
      setState(() {
        _folders.removeWhere((folder) => folder['id'] == folderId);
        if (_currentFolderId == folderId) {
          _currentFolderId = null;
          _notes.clear();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting folder: ${e.toString()}')),
      );
    }
  }

  void _onStopSharing(String folderId) async {
    // Remove from sharedFolders
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await _firestore
        .collection('sharedFolders')
        .where('ownerId', isEqualTo: user.uid)
        .where('originalFolderId', isEqualTo: folderId)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    await _loadSharedFolders();
    setState(() {});
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
      return _folders;
    }
    return _folders
        .where(
          (folder) => folder['name'].toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredNotes {
    if (_searchController.text.isEmpty) {
      return _notes;
    }
    return _notes
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

  List<Map<String, dynamic>> get _pagedFolders {
    final start = _currentFolderPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredFolders.length);
    return _filteredFolders.sublist(start, end);
  }
  int get _totalFolderPages => (_filteredFolders.length / _itemsPerPage).ceil();

  List<Map<String, dynamic>> get _pagedNotes {
    final start = _currentNotePage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredNotes.length);
    return _filteredNotes.sublist(start, end);
  }
  int get _totalNotePages => (_filteredNotes.length / _itemsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          title: Container(
            color: Colors.white,
            child: Row(
        children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _currentFolderId == null ? 'Search folders...' : 'Search notes...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    onChanged: (value) { setState(() {}); },
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentFolderId == null) {
                          setState(() {
                            _isAddingFolder = !_isAddingFolder;
                            if (_isAddingFolder) {
                              _animationController.forward();
                            } else {
                              _animationController.reverse();
                              _folderNameController.clear();
                            }
                          });
                        } else {
                          setState(() {
                            _isAddingNote = !_isAddingNote;
                            if (_isAddingNote) {
                              _animationController.forward();
                            } else {
                              _animationController.reverse();
                            }
                          });
                        }
                      },
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationAnimation.value * 1.5 * 3.141592653589793,
                            child: Icon(Icons.add, color: Colors.white, size: 22),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body:
            _currentFolderId == null ? _buildFoldersView() : _buildNotesView(),
      ),
    );
  }

  Widget _buildFoldersView() {
    return Column(
      children: [
        if (_isAddingFolder)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _folderNameController,
                        style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Folder Name',
                          labelStyle: TextStyle(fontSize: 16),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: _buildFolderIcon(_selectedIcon),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => _buildIconSelectionDialog(),
                        );
                      },
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addFolder,
                      child: Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _pagedFolders.length,
              itemBuilder: (context, index) {
              final folder = _pagedFolders[index];
              final isShared = _sharedFolderIds.contains(folder['id']);
              return Container(
                height: 70,
                margin: EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _loadNotes(folder['id']),
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
                        Row(
                          children: [
                            isShared
                              ? Icon(Icons.cloud_done, color: Colors.blue, size: 24)
                              : IconButton(
                                  icon: Icon(
                                    Icons.share,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  onPressed: () => _showShareConfirmationDialog(
                                    folder['id'],
                                    folder['name'],
                                    folder['icon'],
                                  ),
                                ),
                        IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _deleteFolder(folder['id']),
                            ),
                            if (isShared)
                        IconButton(
                                icon: Icon(Icons.remove_circle, color: Colors.orange, size: 22),
                                tooltip: 'Remove from Community',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Remove from Community'),
                                      content: Text('Are you sure you want to remove this folder from the community?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text('Remove', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) _onStopSharing(folder['id']);
                                },
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
        if (_totalFolderPages > 1)
            Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentFolderPage > 1) ...[
                  _pageButton(0, isNote: false),
                  if (_currentFolderPage > 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
                if (_currentFolderPage > 0) _pageButton(_currentFolderPage - 1, isNote: false),
                _pageButton(_currentFolderPage, isNote: false),
                if (_currentFolderPage < _totalFolderPages - 1) _pageButton(_currentFolderPage + 1, isNote: false),
                if (_currentFolderPage < _totalFolderPages - 2) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  _pageButton(_totalFolderPages - 1, isNote: false),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _showShareConfirmationDialog(
    String folderId,
    String folderName,
    String icon,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Share Folder'),
            content: Text(
              'Are you sure you want to share "$folderName" with the community?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _shareFolder(folderId, folderName, icon);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('Share'),
              ),
            ],
          ),
    );
  }

  Widget _buildNotesView() {
    String currentFolderName =
        _folders.firstWhere(
          (folder) => folder['id'] == _currentFolderId,
          orElse: () => {'name': 'Unknown Folder'},
        )['name'];

    if (_selectedNoteIndex != null && !_isAddingNote) {
      return _buildNoteDetails();
    }

    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                _currentFolderId = null;
                _notes.clear();
                _editingIndex = null;
                _isAddingNote = false;
                _titleController.clear();
                _codeController.clear();
                _image = null;
                  });
                },
              ),
          title: Text(currentFolderName),
            ),
          if (_isAddingNote)
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editingIndex != null
                                ? 'Edit Note'
                                : 'Create New Note',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              hintText: 'Enter a title for your note',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.title),
                            ),
                          ),
                          SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                            decoration: InputDecoration(
                              labelText: 'Code Snippet',
                              hintText:
                                  'Enter your code here. Use --- to create code blocks',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.code),
                              alignLabelWithHint: true,
                            ),
                            style: TextStyle(fontSize: 17),
                            maxLines: 8,
                          ),
                          SizedBox(height: 24),
                          // Add tag selection dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedTag,
                            decoration: InputDecoration(
                              labelText: 'Tag',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                _availableTags.map((String tag) {
                                  return DropdownMenuItem<String>(
                                    value: tag,
                                    child: Text(
                                      tag.substring(0, 1).toUpperCase() +
                                          tag.substring(1),
                                    ), // Capitalize first letter
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedTag = newValue;
                                });
                              }
                            },
                          ),
                          SizedBox(height: 16),
                          if (_editingIndex == null) ...[
                            Text(
                              'Add Image (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 12),
                  _image != null
                                ? Stack(
                                    children: [
                                      Container(
                                        height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _image!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black54,
                                          ),
                                          onPressed: _removeImage,
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image,
                                            size: 32,
                                            color: Colors.grey.shade400,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "No image selected",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ],
                          if (_editingIndex != null &&
                              (_notes[_editingIndex!]['imageUrl'] != null ||
                                  _image != null)) ...[
                            SizedBox(height: 24),
                            Stack(
                              children: [
                                Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image:
                                          _image != null
                                              ? FileImage(_image!)
                                                  as ImageProvider
                                              : NetworkImage(
                                                  _notes[_editingIndex!]['imageUrl'],
                                                ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                    onPressed: _removeImage,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                              if (_editingIndex == null ||
                                  _notes[_editingIndex!]['imageUrl'] != null ||
                                  _image != null ||
                                  _editingIndex != null)
                                TextButton.icon(
                        onPressed: _pickImage,
                                  icon: Icon(Icons.image),
                                  label: Text(
                                    _editingIndex != null
                                        ? "Change Image"
                                        : "Pick Image",
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).primaryColor,
                                  ),
                                ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                        onPressed: _saveNote,
                                icon: Icon(
                                  _editingIndex != null
                                      ? Icons.edit
                                      : Icons.save,
                                ),
                                label: Text(
                                  _editingIndex != null
                                      ? "Update Note"
                                      : "Save Note",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ],
                      ),
              ),
            ),
        ],
      ),
            ),
          )
          else
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(top: 8),
                    itemCount: _pagedNotes.length,
                    itemBuilder: (context, index) {
                      return _buildNoteCard(_pagedNotes[index], _currentNotePage * _itemsPerPage + index);
                    },
                  ),
                ),
                if (_totalNotePages > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentNotePage > 1) ...[
                        _pageButton(0, isNote: true),
                        if (_currentNotePage > 2)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                      if (_currentNotePage > 0) _pageButton(_currentNotePage - 1, isNote: true),
                      _pageButton(_currentNotePage, isNote: true),
                      if (_currentNotePage < _totalNotePages - 1) _pageButton(_currentNotePage + 1, isNote: true),
                      if (_currentNotePage < _totalNotePages - 2) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        _pageButton(_totalNotePages - 1, isNote: true),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
            note['title'] ?? '',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.compare_arrows),
                tooltip: 'Show similar notes in other languages',
                onPressed: () async {
                  // Get the current folder's icon to determine the language
                  DocumentSnapshot folderDoc =
                      await _firestore
                          .collection('folders')
                          .doc(_currentFolderId)
                          .get();
                  String icon = folderDoc.get('icon');
                  String language = _getLanguageFromIcon(icon);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => RelatedNotesPage(
                            originalNote: note,
                            currentLanguage: language,
                          ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => _editNote(_selectedNoteIndex!),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _deleteNote(_selectedNoteIndex!),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
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
                // Add tag chip in details view
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Chip(
                    label: Text(
                      (note['tag'] ?? 'dummies').substring(0, 1).toUpperCase() +
                          (note['tag'] ?? 'dummies').substring(1),
                      style: TextStyle(color: _getTagTextColor(note['tag'] ?? 'dummies'), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    backgroundColor: _getTagColor(note['tag'] ?? 'dummies'),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                if (note['code'] != null && note['code'].isNotEmpty)
                  _buildCodeBlock(note['code']),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedNoteIndex = index;
          });
        },
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note['imageUrl'] != null)
                Container(
                  width: 50,
                  height: 50,
                  margin: EdgeInsets.only(right: 12),
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
                      note['title'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Chip(
                      label: Text(
                        (note['tag'] ?? 'dummies').substring(0, 1).toUpperCase() +
                            (note['tag'] ?? 'dummies').substring(1),
                        style: TextStyle(
                          color: _getTagTextColor(note['tag'] ?? 'dummies'),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: _getTagColor(note['tag'] ?? 'dummies'),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () => _editNote(index),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () => _deleteNote(index),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'dummies':
        return Color(0xFFE8F5E9);
      case 'basic':
        return Color(0xFFE3F2FD);
      case 'advanced':
        return Color(0xFFFFF3E0);
      case 'externalLibs':
        return Color(0xFFF3E5F5);
      default:
        return Colors.grey[200]!;
    }
  }

  Color _getTagTextColor(String tag) {
    switch (tag) {
      case 'dummies':
        return Color(0xFF256029);
      case 'basic':
        return Color(0xFF0D47A1);
      case 'advanced':
        return Color(0xFF6D4C00);
      case 'externalLibs':
        return Color(0xFF4A148C);
      default:
        return Colors.black87;
    }
  }

  Widget _buildIconSelectionDialog() {
    return AlertDialog(
      title: Text('Select Programming Language'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < _availableIcons.length; i += 3)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var j = i; j < i + 3 && j < _availableIcons.length; j++)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = _availableIcons[j];
                        });
                        Navigator.pop(context);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  _selectedIcon == _availableIcons[j]
                                      ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.1)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SvgPicture.asset(
                              _availableIcons[j],
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _getIconName(_availableIcons[j]),
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderIcon(String iconPath) {
    double size = 60; // Default size for selection and creation
    if (iconPath.contains('flutter')) {
      size = 50; // Smaller size for Flutter
    } else if (iconPath.contains('html')) {
      size = 70; // Larger size for HTML
    }

    // If we're in the folder display view (not creating or selecting)
    if (!_isAddingFolder && _currentFolderId == null) {
      size = 60; // Default size for display
      if (iconPath.contains('flutter')) {
        size = 45; // Even smaller size for Flutter in display
      } else if (iconPath.contains('html')) {
        size = 70; // Keep HTML size
      }
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
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: HighlightView(
                  block.trim(),
                  language: 'cpp', // Default to C++ for now
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
                        height: 1.0,
                        color: Colors.black87,
                      ),
                    ),
                  );
                  spans.add(
                    TextSpan(
                      text: partsBefore[1],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.0,
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

              // Process underlined text
              while (currentText.contains('__')) {
                final partsBefore = currentText.split('__');
                if (partsBefore.length > 1) {
                  spans.add(
                    TextSpan(
                      text: partsBefore[0],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.0,
                        color: Colors.black87,
                      ),
                    ),
                  );
                  spans.add(
                    TextSpan(
                      text: partsBefore[1],
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.0,
                        color: Colors.black87,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  );
                  currentText = partsBefore.sublist(2).join('__');
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
                      height: 1.0,
                      color: Colors.black87,
                    ),
                  ),
                );
              }

              return SelectableText.rich(
                TextSpan(children: spans),
                style: TextStyle(
                  fontSize: 16,
                  height: 1.0,
                  color: Colors.black87,
                ),
              );
            }
          }).toList(),
    );
  }

  Widget _buildFormattedText(String text) {
    final spans = <TextSpan>[];
    var currentText = text;

    // Split text into lines and filter out empty ones
    final lines =
        currentText
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
    currentText = lines.join('\n');

    // Process bold text
    while (currentText.contains('**')) {
      final partsBefore = currentText.split('**');
      if (partsBefore.length > 1) {
        spans.add(
          TextSpan(
            text: partsBefore[0],
            style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87),
          ),
        );
        spans.add(
          TextSpan(
            text: partsBefore[1],
            style: TextStyle(
              fontSize: 16,
              height: 1.0,
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

    // Process underlined text
    while (currentText.contains('__')) {
      final partsBefore = currentText.split('__');
      if (partsBefore.length > 1) {
        spans.add(
          TextSpan(
            text: partsBefore[0],
            style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87),
          ),
        );
        spans.add(
          TextSpan(
            text: partsBefore[1],
            style: TextStyle(
              fontSize: 16,
              height: 1.0,
              color: Colors.black87,
              decoration: TextDecoration.underline,
            ),
          ),
        );
        currentText = partsBefore.sublist(2).join('__');
      } else {
        break;
      }
    }

    // Add any remaining text
    if (currentText.isNotEmpty) {
      spans.add(
        TextSpan(
          text: currentText,
          style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getLanguageFromIcon(String iconPath) {
    if (iconPath.contains('c++')) return 'C++';
    if (iconPath.contains('java')) return 'Java';
    if (iconPath.contains('python')) return 'Python';
    if (iconPath.contains('c.svg')) return 'C';
    if (iconPath.contains('html')) return 'HTML';
    if (iconPath.contains('flutter')) return 'Flutter';
    return 'Unknown';
  }

  Widget _pageButton(int i, {required bool isNote}) {
    final isCurrent = isNote ? i == _currentNotePage : i == _currentFolderPage;
    return GestureDetector(
      onTap: () => setState(() {
        if (isNote) {
          _currentNotePage = i;
        } else {
          _currentFolderPage = i;
        }
      }),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${i + 1}',
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Reset _currentNotePage if out of range after search or note changes
  void _ensureNotePageInRange() {
    final totalPages = _totalNotePages;
    if (_currentNotePage >= totalPages && totalPages > 0) {
      setState(() {
        _currentNotePage = 0;
      });
    }
  }
}
