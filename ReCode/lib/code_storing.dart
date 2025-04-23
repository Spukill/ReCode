import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CodeStoringPage extends StatefulWidget {
  @override
  _CodeStoringPageState createState() => _CodeStoringPageState();
}

class _CodeStoringPageState extends State<CodeStoringPage> with SingleTickerProviderStateMixin {
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

  final List<String> _availableIcons = [
    'assets/icons/c++.svg',
    'assets/icons/java.svg',
    'assets/icons/python.svg',
    'assets/icons/c.svg',
    'assets/icons/html.svg',
    'assets/icons/flutter.svg',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    // Add listener to search controller
    _searchController.addListener(() {
      setState(() {}); // Rebuild the UI when search text changes
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Load folders from Firestore
  Future<void> _loadFolders() async {
    if (!mounted) return; // Check if the widget is still mounted
    
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('folders')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        // Sort folders locally after fetching
        List<Map<String, dynamic>> sortedFolders = snapshot.docs.map((doc) {
          // Handle both string and integer icon data
          dynamic iconData = doc['icon'];
          String icon;
          if (iconData is String) {
            icon = iconData;
          } else {
            // Default to C++ icon if the data is invalid
            icon = 'assets/icons/c++.svg';
          }

          return {
            'id': doc.id,
            'name': doc['name'],
            'icon': icon,
            'createdAt': doc['createdAt']?.toDate() ?? DateTime.now(),
          };
        }).toList();
        
        sortedFolders.sort((a, b) => (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime));
        
        if (mounted) { // Check again if the widget is still mounted
          setState(() {
            _folders = sortedFolders;
          });
        }
      } catch (e) {
        if (mounted) { // Check if the widget is still mounted
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

  // Load notes from a specific folder
  Future<void> _loadNotes(String folderId) async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
          .where('folderId', isEqualTo: folderId)
          .get();
      setState(() {
        _notes = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'title': doc['title'],
            'code': doc['code'],
            'imageUrl': doc['imageUrl'],
          };
        }).toList();
        _currentFolderId = folderId;
      });
    }
  }

  // Add new folder
  Future<void> _addFolder() async {
    final name = _folderNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a folder name'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
      });
      await _loadFolders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating folder: ${e.toString()}'),
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

  // Save note to Firestore
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

  try {
    String? imageUrl;
    
      if (_image != null) {
        try {
          print('Starting image upload process...');
          
          // Verify Firebase Storage instance
          if (_storage == null) {
            throw Exception('Firebase Storage instance is null');
          }
          
          // Create a unique filename for the image
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${user.uid}_$timestamp.jpg';
          print('Generated filename: $fileName');
          
          // Create a reference to the location where we'll store the image
          final storageRef = _storage.ref().child('note_images').child(fileName);
          print('Created storage reference: ${storageRef.fullPath}');
          
          // Create metadata for the image
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': user.uid,
              'timestamp': timestamp.toString(),
            },
          );
          
          print('Starting file upload...');
          // Upload the image
          final uploadTask = storageRef.putFile(_image!, metadata);
          
          // Monitor upload progress
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            print('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
          });
          
          // Wait for upload to complete
          final TaskSnapshot snapshot = await uploadTask;
          print('Upload completed. State: ${snapshot.state}');
          
          if (snapshot.state == TaskState.success) {
      imageUrl = await storageRef.getDownloadURL();
            print('Successfully got download URL: $imageUrl');
          } else {
            throw Exception('Failed to upload image: ${snapshot.state}');
          }
        } catch (e, stackTrace) {
          print('Error uploading image: $e');
          print('Stack trace: $stackTrace');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Save the note data
    if (_editingIndex != null) {
      final currentImageUrl = _notes[_editingIndex!]['imageUrl'];
      await _firestore.collection('notes').doc(_notes[_editingIndex!]['id']).update({
        'title': title,
        'code': codeSnippet,
        'imageUrl': imageUrl ?? currentImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('notes').add({
        'userId': user.uid,
          'folderId': _currentFolderId,
        'title': title,
        'code': codeSnippet,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    _resetForm();
      if (_currentFolderId != null) {
        await _loadNotes(_currentFolderId!);
      }
  } catch (e) {
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

  void _editNote(int index) {
    setState(() {
      _titleController.text = _notes[index]['title'];
      _codeController.text = _notes[index]['code'];
      _image = null;
      _isAddingNote = true;
      _editingIndex = index;
    });
  }

  Future<void> _deleteNote(int index) async {
    try {
      await _firestore.collection('notes').doc(_notes[index]['id']).delete();
      if (_notes[index]['imageUrl'] != null) {
        await _storage.refFromURL(_notes[index]['imageUrl']).delete();
      }
      setState(() {
        _notes.removeAt(index);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting note: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    try {
      // Delete all notes in the folder
      QuerySnapshot notesSnapshot = await _firestore
          .collection('notes')
          .where('folderId', isEqualTo: folderId)
          .get();
      
      for (var doc in notesSnapshot.docs) {
        if (doc['imageUrl'] != null) {
          await _storage.refFromURL(doc['imageUrl']).delete();
        }
        await doc.reference.delete();
      }

      // Delete the folder
      await _firestore.collection('folders').doc(folderId).delete();
      
      setState(() {
        _folders.removeWhere((folder) => folder['id'] == folderId);
        if (_currentFolderId == folderId) {
          _currentFolderId = null;
          _notes.clear();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting folder: ${e.toString()}')),
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

  // Get filtered folders based on search text
  List<Map<String, dynamic>> get _filteredFolders {
    if (_searchController.text.isEmpty) {
      return _folders;
    }
    return _folders.where((folder) => 
      folder['name'].toLowerCase().contains(_searchController.text.toLowerCase())
    ).toList();
  }

  // Get filtered notes based on search text
  List<Map<String, dynamic>> get _filteredNotes {
    if (_searchController.text.isEmpty) {
      return _notes;
    }
    return _notes.where((note) => 
      (note['title']?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false) ||
      (note['code']?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: _selectedNoteIndex != null && !_isAddingNote
              ? Text(
                  'Note Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _currentFolderId == null ? 'Search folders...' : 'Search notes...',
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
      body: _currentFolderId == null ? _buildFoldersView() : _buildNotesView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_currentFolderId == null) {
              _isAddingFolder = !_isAddingFolder;
              if (_isAddingFolder) {
                _animationController.forward();
              } else {
                _animationController.reverse();
                _folderNameController.clear();
              }
            } else {
              _isAddingNote = true;
            }
          });
        },
        child: AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: (_rotationAnimation.value * 3.14159) + (3.14159 / 2),
              child: Icon(_currentFolderId == null 
                ? (_isAddingFolder ? Icons.remove : Icons.add)
                : Icons.add),
            );
          },
        ),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            itemCount: _filteredFolders.length,
            itemBuilder: (context, index) {
              return Container(
                height: 70,
                margin: EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _loadNotes(_filteredFolders[index]['id']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: _buildFolderIcon(_filteredFolders[index]['icon']),
                        ),
                        Expanded(
                          child: Text(
                            _filteredFolders[index]['name'],
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _deleteFolder(_filteredFolders[index]['id']),
                          ),
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

  Widget _buildNotesView() {
    // Find the current folder's name
    String currentFolderName = _folders
        .firstWhere((folder) => folder['id'] == _currentFolderId,
            orElse: () => {'name': 'Unknown Folder'})['name'];

    if (_selectedNoteIndex != null && !_isAddingNote) {
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
                _currentFolderId = null;
                _notes.clear();
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
                            'Create New Note',
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
                              hintText: 'Enter your code here',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.code),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 8,
                          ),
                          SizedBox(height: 24),
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
                                        border: Border.all(color: Colors.grey.shade300),
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
                                        icon: Icon(Icons.close, color: Colors.white),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _image = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _pickImage,
                                icon: Icon(Icons.image),
                                label: Text("Pick Image"),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).primaryColor,
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _saveNote,
                                icon: Icon(_editingIndex != null ? Icons.edit : Icons.save),
                                label: Text(_editingIndex != null ? "Update Note" : "Save Note"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ),
        if (!_isAddingNote)
          Expanded(
            child: ListView.builder(
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) {
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
                              if (_filteredNotes[index]['imageUrl'] != null)
                                Container(
                            width: 50,
                            height: 50,
                                  margin: EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(_filteredNotes[index]['imageUrl']),
                            fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _filteredNotes[index]['title'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _filteredNotes[index]['code'],
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
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editNote(index),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteNote(index),
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
                              color: _selectedIcon == _availableIcons[j]
                                  ? Theme.of(context).primaryColor.withOpacity(0.1)
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
}
