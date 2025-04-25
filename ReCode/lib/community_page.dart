import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CodeSharingPage extends StatefulWidget {
  @override
  _CodeSharingPageState createState() => _CodeSharingPageState();
}

class _CodeSharingPageState extends State<CodeSharingPage> {
  List<Map<String, dynamic>> _sharedNotes = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSharedNotes();
  }

  Future<void> _loadSharedNotes() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('shared_notes')
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      _sharedNotes = snapshot.docs
          .map((doc) => {
        'id': doc.id,
        'title': doc['title'],
        'code': doc['code'],
        'icon': doc['icon'],
        'imageUrl': doc['imageUrl'],
        'likes': doc['likes'] ?? 0,
      })
          .toList();
    });
  }

  Future<void> _likeNote(String noteId) async {
    final docRef = FirebaseFirestore.instance.collection('shared_notes').doc(noteId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final newLikes = (snapshot['likes'] ?? 0) + 1;
      transaction.update(docRef, {'likes': newLikes});
    });
    _loadSharedNotes();
  }

  void _showCommentsDialog(String noteId) {
    final TextEditingController commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shared_notes')
                    .doc(noteId)
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  return ListView(
                    shrinkWrap: true,
                    children: snapshot.data!.docs.map((doc) {
                      return ListTile(
                        title: Text(doc['text']),
                        subtitle: Text(doc['user'] ?? 'Anonymous'),
                      );
                    }).toList(),
                  );
                },
              ),
              TextField(
                controller: commentController,
                decoration: InputDecoration(hintText: 'Add a comment...'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (commentController.text.trim().isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('shared_notes')
                        .doc(noteId)
                        .collection('comments')
                        .add({
                      'text': commentController.text.trim(),
                      'user': user?.email ?? 'Anonymous',
                      'timestamp': Timestamp.now(),
                    });
                    commentController.clear();
                  }
                },
                child: Text('Post'),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community Shared Notes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search shared notes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                // Optional: Add search logic later
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sharedNotes.length,
              itemBuilder: (context, index) {
                final note = _sharedNotes[index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: SvgPicture.asset(
                      note['icon'],
                      width: 40,
                      height: 40,
                    ),
                    title: Text(note['title']),
                    subtitle: Text(
                      note['code'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.thumb_up),
                          onPressed: () => _likeNote(note['id']),
                        ),
                        Text('${note['likes']}'),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(note['title']),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (note['imageUrl'] != null)
                                  Image.network(note['imageUrl']),
                                SizedBox(height: 10),
                                Text(note['code']),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: Text('Comment'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showCommentsDialog(note['id']);
                              },
                            ),
                            TextButton(
                              child: Text('Close'),
                              onPressed: () => Navigator.of(context).pop(),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

//Needs fields , shared_notes/{noteId}/comments (with fields text, user, timestamp)
//Likes field in each shared_notes document