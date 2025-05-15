import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

extension StringExtensions on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

class RecommendedNotesPage extends StatefulWidget {
  final String language;

  const RecommendedNotesPage({Key? key, required this.language})
    : super(key: key);

  @override
  _RecommendedNotesPageState createState() => _RecommendedNotesPageState();
}

class _RecommendedNotesPageState extends State<RecommendedNotesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  int? _selectedNoteIndex;
  String? _selectedTag;

  final List<String> _availableTags = [
    'dummies',
    'basic',
    'advanced',
    'externalLibs',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _filterNotes() {
    setState(() {
      if (_selectedTag == null) {
        _filteredNotes = List.from(_notes);
      } else {
        _filteredNotes =
            _notes.where((note) => note['tag'] == _selectedTag).toList();
      }
    });
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      // Get all shared folders first
      QuerySnapshot foldersSnapshot =
          await _firestore
              .collection('sharedFolders')
              .where('icon', isEqualTo: 'assets/icons/${widget.language}.svg')
              .get();

      List<String> folderIds =
          foldersSnapshot.docs.map((doc) => doc.id).toList();

      // Get notes from all matching folders
      List<Map<String, dynamic>> allNotes = [];
      for (String folderId in folderIds) {
        QuerySnapshot notesSnapshot =
            await _firestore
                .collection('sharedNotes')
                .where('sharedFolderId', isEqualTo: folderId)
                .get();

        allNotes.addAll(
          notesSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'title': doc['title'],
              'code': doc['code'],
              'imageUrl': doc['imageUrl'],
              'tag': doc['tag'] ?? 'dummies',
              'ownerName': doc['ownerName'],
              'createdAt': doc['createdAt']?.toDate() ?? DateTime.now(),
            };
          }).toList(),
        );
      }

      // Sort notes by creation date
      allNotes.sort(
        (a, b) =>
            (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime),
      );

      setState(() {
        _notes = allNotes;
        _filteredNotes = allNotes;
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

  Widget _buildTagFilters() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                'All',
                style: TextStyle(
                  color: _selectedTag == null ? Colors.white : Colors.black87,
                ),
              ),
              selected: _selectedTag == null,
              onSelected: (bool selected) {
                setState(() {
                  _selectedTag = null;
                  _filterNotes();
                });
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Theme.of(context).primaryColor,
            ),
          ),
          ..._availableTags.map((tag) {
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  tag.substring(0, 1).toUpperCase() + tag.substring(1),
                  style: TextStyle(
                    color: _selectedTag == tag ? Colors.white : Colors.black87,
                  ),
                ),
                selected: _selectedTag == tag,
                onSelected: (bool selected) {
                  setState(() {
                    _selectedTag = selected ? tag : null;
                    _filterNotes();
                  });
                },
                backgroundColor: Colors.grey[200],
                selectedColor: _getTagColor(tag),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${(widget.language).capitalize()} Notes'),
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
              : Column(
                children: [
                  _buildTagFilters(),
                  Expanded(child: _buildNotesList()),
                ],
              ),
    );
  }

  Widget _buildNotesList() {
    if (_filteredNotes.isEmpty) {
      return Center(
        child: Text(
          'No notes found',
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
                  language: widget.language == 'c++' ? 'cpp' : widget.language,
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
}
