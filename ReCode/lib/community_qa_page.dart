import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityQAPage extends StatefulWidget {
  @override
  _CommunityQAPageState createState() => _CommunityQAPageState();
}

class _CommunityQAPageState extends State<CommunityQAPage> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Community Q&A'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showQuestionDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('questions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var question = snapshot.data!.docs[index];
              return QuestionCard(
                question: question,
                onAnswer: () => _showAnswerDialog(context, question.id),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showQuestionDialog(BuildContext context) async {
    _questionController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ask a Question'),
        content: TextField(
          controller: _questionController,
          decoration: InputDecoration(
            hintText: 'Type your question here...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_questionController.text.trim().isNotEmpty) {
                await _postQuestion();
                Navigator.pop(context);
              }
            },
            child: Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAnswerDialog(BuildContext context, String questionId) async {
    _answerController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Write an Answer'),
        content: TextField(
          controller: _answerController,
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_answerController.text.trim().isNotEmpty) {
                await _postAnswer(questionId);
                Navigator.pop(context);
              }
            },
            child: Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _postQuestion() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('questions').add({
        'text': _questionController.text.trim(),
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'answers': [],
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting question: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postAnswer(String questionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('questions').doc(questionId).update({
        'answers': FieldValue.arrayUnion([
          {
            'text': _answerController.text.trim(),
            'userId': user.uid,
            'userName': user.displayName ?? 'Anonymous',
            'timestamp': FieldValue.serverTimestamp(),
          }
        ]),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting answer: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class QuestionCard extends StatelessWidget {
  final DocumentSnapshot question;
  final VoidCallback onAnswer;

  const QuestionCard({
    Key? key,
    required this.question,
    required this.onAnswer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = question.data() as Map<String, dynamic>;
    final answers = List<Map<String, dynamic>>.from(data['answers'] ?? []);

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(data['userName'][0].toUpperCase()),
                ),
                SizedBox(width: 8),
                Text(
                  data['userName'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  _formatTimestamp(data['timestamp']),
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              data['text'],
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${answers.length} ${answers.length == 1 ? 'Answer' : 'Answers'}',
                  style: TextStyle(color: Colors.grey),
                ),
                TextButton.icon(
                  onPressed: onAnswer,
                  icon: Icon(Icons.reply),
                  label: Text('Answer'),
                ),
              ],
            ),
            if (answers.isNotEmpty) ...[
              Divider(),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: answers.length,
                itemBuilder: (context, index) {
                  final answer = answers[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              child: Text(answer['userName'][0].toUpperCase()),
                            ),
                            SizedBox(width: 8),
                            Text(
                              answer['userName'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Spacer(),
                            Text(
                              _formatTimestamp(answer['timestamp']),
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(answer['text']),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
} 