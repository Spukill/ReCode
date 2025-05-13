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
  bool _hasMoreQuestions = true;
  DocumentSnapshot? _lastDocument;
  static const int _questionsPerPage = 5;
  List<DocumentSnapshot> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadInitialQuestions();
  }

  Future<void> _loadInitialQuestions() async {
    setState(() => _isLoading = true);
    try {
      final querySnapshot = await _firestore
          .collection('questions')
          .orderBy('timestamp', descending: true)
          .limit(_questionsPerPage)
          .get();

      setState(() {
        _questions = querySnapshot.docs;
        _lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
        _hasMoreQuestions = querySnapshot.docs.length == _questionsPerPage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading questions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMoreQuestions() async {
    if (!_hasMoreQuestions || _isLoading || _lastDocument == null) return;

    setState(() => _isLoading = true);
    try {
      final querySnapshot = await _firestore
          .collection('questions')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_questionsPerPage)
          .get();

      setState(() {
        _questions.addAll(querySnapshot.docs);
        _lastDocument = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
        _hasMoreQuestions = querySnapshot.docs.length == _questionsPerPage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading more questions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('questions').doc(questionId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Question deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting question: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(String questionId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Question'),
          content: Text('Are you sure you want to delete this question? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteQuestion(questionId);
              },
            ),
          ],
        );
      },
    );
  }

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
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadInitialQuestions();
        },
        child: _questions.isEmpty && !_isLoading
            ? Center(
                child: Text(
                  'No questions yet. Be the first to ask!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: _questions.length + (_hasMoreQuestions ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _questions.length) {
                    return _buildLoadMoreButton();
                  }
                  return QuestionCard(
                    question: _questions[index],
                    onAnswer: () => _showAnswerDialog(context, _questions[index].id),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _loadMoreQuestions,
                child: Text('Load More Questions'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
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
      // First get the current question document
      final questionDoc = await _firestore.collection('questions').doc(questionId).get();
      if (!questionDoc.exists) {
        throw Exception('Question not found');
      }

      // Get current answers array
      final currentAnswers = List<Map<String, dynamic>>.from(questionDoc.data()?['answers'] ?? []);
      
      // Add new answer with current timestamp
      currentAnswers.add({
        'text': _answerController.text.trim(),
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });

      // Update the document with the new answers array
      await _firestore.collection('questions').doc(questionId).update({
        'answers': currentAnswers,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Answer posted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting answer: $e'),
          backgroundColor: Colors.red,
        ),
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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final data = question.data() as Map<String, dynamic>;
    final answers = List<Map<String, dynamic>>.from(data['answers'] ?? []);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isQuestionOwner = currentUser?.uid == data['userId'];
    final userName = data['userName'] as String? ?? 'Anonymous';

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
                  child: Text(_getInitials(userName)),
                ),
                SizedBox(width: 8),
                Text(
                  userName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                if (isQuestionOwner)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Delete Question'),
                            content: Text('Are you sure you want to delete this question? This action cannot be undone.'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              TextButton(
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  FirebaseFirestore.instance
                                      .collection('questions')
                                      .doc(question.id)
                                      .delete()
                                      .then((_) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Question deleted successfully'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }).catchError((error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error deleting question: $error'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                Text(
                  _formatTimestamp(data['timestamp']),
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              data['text'] ?? '',
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
                  final answerUserName = answer['userName'] as String? ?? 'Anonymous';
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              child: Text(_getInitials(answerUserName)),
                            ),
                            SizedBox(width: 8),
                            Text(
                              answerUserName,
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
                        Text(answer['text'] ?? ''),
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
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
} 