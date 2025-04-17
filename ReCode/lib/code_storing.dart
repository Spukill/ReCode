import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CodeStoringPage extends StatefulWidget {
  @override
  _CodeStoringPageState createState() => _CodeStoringPageState();
}

class _CodeStoringPageState extends State<CodeStoringPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isAddingNote = false;
  int? _editingIndex;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  // Load notes from Firestore
  Future<void> _loadNotes() async {
    User? user = _auth.currentUser;
    if (user != null) {
      QuerySnapshot snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: user.uid)
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
      });
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
        print('Starting image upload...');
        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = _storage.ref().child('note_images/$fileName');
        
        print('Uploading image...');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
        );
        await storageRef.putFile(_image!, metadata);
        
        imageUrl = await storageRef.getDownloadURL();
        print('Image uploaded successfully. URL: $imageUrl');
      }

      if (_editingIndex != null) {
        print('Updating existing note...');
        final currentImageUrl = _notes[_editingIndex!]['imageUrl'];
        await _firestore.collection('notes').doc(_notes[_editingIndex!]['id']).update({
          'title': title,
          'code': codeSnippet,
          'imageUrl': imageUrl ?? currentImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        print('Creating new note...');
        await _firestore.collection('notes').add({
          'userId': user.uid,
          'title': title,
          'code': codeSnippet,
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _resetForm();
      await _loadNotes();
      print('Note saved successfully');

    } catch (e) {
      print('Error saving note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving note: ${e.toString()}'),
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

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    try {
      print('Starting image picker...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        print('Image picked successfully: ${pickedFile.path}');
        setState(() {
          _image = File(pickedFile.path);
        });
      } else {
        print('No image was picked');
      }
    } catch (e) {
      print("Image picker error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  // Function to edit an existing note
  void _editNote(int index) {
    setState(() {
      _titleController.text = _notes[index]['title'];
      _codeController.text = _notes[index]['code'];
      _image = null;
      _isAddingNote = true;
      _editingIndex = index;
    });
  }

  // Function to delete an existing note
  void _deleteNote(int index) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('notes').doc(_notes[index]['id']).delete();
      setState(() {
        _notes.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Code Notes')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(_notes[index]['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_notes[index]['code'], maxLines: 2, overflow: TextOverflow.ellipsis),
                    leading: _notes[index]['imageUrl'] != null
                        ? Image.network(
                            _notes[index]['imageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
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
                  ),
                );
              },
            ),
          ),
          if (!_isAddingNote)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isAddingNote = true;
                  });
                },
                child: Text("Add Note"),
              ),
            ),
          if (_isAddingNote)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: 'Enter note title'),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(labelText: 'Enter your code snippet'),
                    maxLines: 5,
                  ),
                  SizedBox(height: 10),
                  _image != null
                      ? Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color.fromARGB(255, 255, 16, 16)),
                          ),
                          child: Image.file(
                            _image!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Text("No image selected"),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: Text("Pick Image"),
                      ),
                      ElevatedButton(
                        onPressed: _saveNote,
                        child: Text(_editingIndex != null ? "Update Note" : "Save Note"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
