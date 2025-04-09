import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _saveNote() {
    String title = _titleController.text;
    String codeSnippet = _codeController.text;
    if (title.isNotEmpty || codeSnippet.isNotEmpty || _image != null) {
      setState(() {
        if (_editingIndex != null) {
          _notes[_editingIndex!] = {'title': title, 'code': codeSnippet, 'image': _image};
          _editingIndex = null;
        } else {
          _notes.add({'title': title, 'code': codeSnippet, 'image': _image});
        }
        _titleController.clear();
        _codeController.clear();
        _image = null;
        _isAddingNote = false;
      });
    }
  }

  void _editNote(int index) {
    setState(() {
      _titleController.text = _notes[index]['title'];
      _codeController.text = _notes[index]['code'];
      _image = _notes[index]['image'];
      _isAddingNote = true;
      _editingIndex = index;
    });
  }

  void _deleteNote(int index) {
    setState(() {
      if (_editingIndex == index) {
        _titleController.clear();
        _codeController.clear();
        _image = null;
        _isAddingNote = false;
        _editingIndex = null;
      }
      _notes.removeAt(index);
    });
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
                    leading: _notes[index]['image'] != null
                        ? Image.file(
                      _notes[index]['image'],
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
