import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

class RelatedNotesPage extends StatefulWidget {
  final Map<String, dynamic> originalNote;
  final String currentLanguage;

  const RelatedNotesPage({
    Key? key,
    required this.originalNote,
    required this.currentLanguage,
  }) : super(key: key);

  @override
  _RelatedNotesPageState createState() => _RelatedNotesPageState();
}

class _RelatedNotesPageState extends State<RelatedNotesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _relatedNotes = [];
  bool _isLoading = true;
  String? _selectedLanguage;
  Set<String> _availableLanguages = {};
  int? _selectedNoteIndex;

  @override
  void initState() {
    super.initState();
    _loadRelatedNotes();
  }

  Future<void> _loadRelatedNotes() async {
    try {
      setState(() => _isLoading = true);

      // Get the current note title and split it into keywords
      String currentTitle =
          widget.originalNote['title'].toString().toLowerCase();
      List<String> keywords =
          currentTitle.split(' ').where((word) => word.length > 3).toList();

      // Get all shared folders to determine their languages
      QuerySnapshot foldersSnapshot =
          await _firestore.collection('sharedFolders').get();

      Map<String, String> folderLanguages = {};
      for (var folder in foldersSnapshot.docs) {
        String icon = folder.get('icon');
        String language = _getLanguageFromIcon(icon);
        folderLanguages[folder.id] = language;
      }

      // Get all notes
      QuerySnapshot allNotesSnapshot =
          await _firestore.collection('sharedNotes').get();

      // Filter and score related notes
      List<Map<String, dynamic>> relatedNotes = [];
      Set<String> languages = {};

      for (var doc in allNotesSnapshot.docs) {
        String noteTitle = doc.get('title').toString().toLowerCase();
        String folderId = doc.get('sharedFolderId');
        String noteLanguage = folderLanguages[folderId] ?? 'Unknown';

        // Skip notes from the same language as the original note
        if (noteLanguage == widget.currentLanguage) continue;

        // Calculate similarity score
        int matchingKeywords =
            keywords.where((keyword) => noteTitle.contains(keyword)).length;

        if (matchingKeywords > 0) {
          languages.add(noteLanguage);
          relatedNotes.add({
            'id': doc.id,
            'title': doc.get('title'),
            'code': doc.get('code'),
            'imageUrl': doc.get('imageUrl'),
            'tag': doc.get('tag') ?? 'dummies',
            'ownerName': doc.get('ownerName'),
            'language': noteLanguage,
            'similarity': matchingKeywords,
            'createdAt': doc.get('createdAt')?.toDate() ?? DateTime.now(),
          });
        }
      }

      // Sort by similarity score
      relatedNotes.sort((a, b) => b['similarity'].compareTo(a['similarity']));

      setState(() {
        _relatedNotes = relatedNotes;
        _availableLanguages = languages;
        _isLoading = false;
      });
    } catch (e) {
      print('Error finding related notes: $e');
      setState(() => _isLoading = false);
    }
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

  List<Map<String, dynamic>> get _filteredNotes {
    if (_selectedLanguage == null) {
      return _relatedNotes;
    }
    return _relatedNotes
        .where((note) => note['language'] == _selectedLanguage)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Similar Notes'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Filter by language: '),
                SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('All'),
                          selected: _selectedLanguage == null,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedLanguage = null;
                            });
                          },
                        ),
                        SizedBox(width: 8),
                        ..._availableLanguages.map((language) {
                          return Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(language),
                              selected: _selectedLanguage == language,
                              onSelected: (bool selected) {
                                setState(() {
                                  _selectedLanguage =
                                      selected ? language : null;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          'No similar notes found' +
              (_selectedLanguage != null ? ' in $_selectedLanguage' : ''),
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredNotes.length,
      padding: EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(
              note['title'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('Language: ${note['language']}'),
                Text('By: ${note['ownerName']}'),
              ],
            ),
            onTap: () {
              setState(() {
                _selectedNoteIndex = index;
              });
            },
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
                HighlightView(
                  note['code'],
                  language: note['language'].toString().toLowerCase(),
                  theme: githubTheme,
                  padding: EdgeInsets.all(12),
                  textStyle: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
