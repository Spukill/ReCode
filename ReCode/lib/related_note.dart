import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'community_page.dart' as community_page;

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
    setState(() => _isLoading = true);
    try {
      // Fetch all current shared folder IDs
      QuerySnapshot foldersSnapshot = await _firestore.collection('sharedFolders').get();
      final activeFolderIds = foldersSnapshot.docs.map((doc) => doc.id).toSet();

      // Only fetch notes from sharedNotes collection whose sharedFolderId is active
      QuerySnapshot snapshot = await _firestore.collection('sharedNotes').get();
      final seenIds = <String>{};
      // Prepare keywords from the original note's title
      final originalTitle = widget.originalNote['title'].toString().toLowerCase();
      final keywords = originalTitle.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
      
      List<Map<String, dynamic>> notes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'],
          'code': data['code'],
          'imageUrl': data['imageUrl'],
          'tag': data['tag'] ?? 'dummies',
          'ownerName': data['ownerName'],
          'language': data['language'] ?? 'Unknown',
          'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
          'sharedFolderId': data['sharedFolderId'],
        };
      })
      // Only keep notes whose sharedFolderId is still active
      .where((note) => activeFolderIds.contains(note['sharedFolderId']))
      // Only keep notes with similar names
      .where((note) {
        final titleWords = note['title'].toString().toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
        return keywords.intersection(titleWords).isNotEmpty;
      })
      // Remove duplicates by title + ownerName + language
      .where((note) {
        final key = note['title'].toString() + note['ownerName'].toString() + note['language'].toString();
        if (seenIds.contains(key)) return false;
        seenIds.add(key);
        return true;
      }).toList();
      setState(() {
        _relatedNotes = notes;
        _availableLanguages = notes.map((n) => n['language'].toString()).toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading related notes: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
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
    // Always filter out the original note by id
    final originalId = widget.originalNote['id']?.toString();
    final filtered = _relatedNotes.where((note) => note['id']?.toString() != originalId).toList();
    if (_selectedLanguage == null) {
      return filtered;
    }
    return filtered.where((note) => note['language'] == _selectedLanguage).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Similar Notes'),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _selectedNoteIndex != null
              ? _buildSideBySideComparison()
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
        String username = note['ownerName']?.toString() ?? '';
        if (username.contains('@')) {
          username = username.split('@')[0];
        }
        if (username.length > 14) {
          username = username.substring(0, 11) + '...';
        }
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
                Text('By: $username'),
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

  Widget _buildSideBySideComparison() {
    final comparedNote = _filteredNotes[_selectedNoteIndex!];
    final originalNote = widget.originalNote;
    String username1 = originalNote['ownerName']?.toString() ?? '';
    if (username1.contains('@')) username1 = username1.split('@')[0];
    if (username1.length > 14) username1 = username1.substring(0, 11) + '...';
    String username2 = comparedNote['ownerName']?.toString() ?? '';
    if (username2.contains('@')) username2 = username2.split('@')[0];
    if (username2.length > 14) username2 = username2.substring(0, 11) + '...';
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(originalNote['title'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text('By $username1'),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      if (originalNote['imageUrl'] != null)
                        Container(
                          width: double.infinity,
                          height: 120,
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(originalNote['imageUrl']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: _buildCodeBlock(originalNote['code'] ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                color: Colors.grey[300],
              ),
              Expanded(
                child: Card(
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(comparedNote['title'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text('By $username2'),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      if (comparedNote['imageUrl'] != null)
                        Container(
                          width: double.infinity,
                          height: 120,
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(comparedNote['imageUrl']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: _buildCodeBlock(comparedNote['code'] ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String text) {
    final codeBlocks = text.split('---');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: codeBlocks.asMap().entries.map((entry) {
        final index = entry.key;
        final block = entry.value;
        if (index % 2 == 1) {
          // This is a code block (odd indices)
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.symmetric(vertical: 2),
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

          // Process underlined text
          while (currentText.contains('__')) {
            final partsBefore = currentText.split('__');
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
