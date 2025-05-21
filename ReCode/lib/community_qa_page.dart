import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

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

class CommunityQAPage extends StatefulWidget {
  @override
  _CommunityQAPageState createState() => _CommunityQAPageState();
}

class _CommunityQAPageState extends State<CommunityQAPage> with SingleTickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  static const int _questionsPerPage = 10;
  List<DocumentSnapshot> _questions = [];
  int _currentPage = 0;
  int _totalPages = 0;
  List<DocumentSnapshot> _pageMarkers = [];
  AnimationController? _animationController;
  Animation<double>? _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
    _loadInitialQuestions();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _loadInitialQuestions() async {
    setState(() => _isLoading = true);
    try {
      final totalQuery = await _firestore
          .collection('questions')
          .count()
          .get();
      
      final totalQuestions = totalQuery.count ?? 0;
      _totalPages = (totalQuestions / _questionsPerPage).ceil();

      final querySnapshot = await _firestore
          .collection('questions')
          .orderBy('timestamp', descending: true)
          .limit(_questionsPerPage)
          .get();

      setState(() {
        _questions = querySnapshot.docs;
        _pageMarkers = [querySnapshot.docs.last];
        _currentPage = 0;
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

  Future<void> _loadPage(int page) async {
    if (page < 0 || page >= _totalPages) return;
    
    setState(() => _isLoading = true);
    try {
      Query query = _firestore
          .collection('questions')
          .orderBy('timestamp', descending: true)
          .limit(_questionsPerPage);

      // If we're loading a page after the current one, use startAfterDocument
      if (page > _currentPage && _pageMarkers.length > page - 1) {
        query = query.startAfterDocument(_pageMarkers[page - 1]);
      }
      // If we're loading a page before the current one, we need to reload from the start
      else if (page < _currentPage) {
        await _loadInitialQuestions();
        for (int i = 0; i < page; i++) {
          await _loadNextPage();
        }
        setState(() => _isLoading = false);
        return;
      }

      final querySnapshot = await query.get();

      setState(() {
        _questions = querySnapshot.docs;
        if (querySnapshot.docs.isNotEmpty) {
          if (page >= _pageMarkers.length) {
            _pageMarkers.add(querySnapshot.docs.last);
          } else {
            _pageMarkers[page] = querySnapshot.docs.last;
          }
        }
        _currentPage = page;
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

  Future<void> _loadNextPage() async {
    if (_questions.isEmpty) return;
    
    try {
      final querySnapshot = await _firestore
          .collection('questions')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_questions.last)
          .limit(_questionsPerPage)
          .get();

      setState(() {
        _questions = querySnapshot.docs;
        if (querySnapshot.docs.isNotEmpty) {
          _pageMarkers.add(querySnapshot.docs.last);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading next page: $e'),
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

  List<DocumentSnapshot> get _filteredQuestions {
    if (_searchController.text.isEmpty) {
      return _questions;
    }
    return _questions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final text = data['text'] as String? ?? '';
      final userName = data['userName'] as String? ?? '';
      return text.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          userName.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();
  }

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
                      hintText: 'Search questions...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    _animationController!.forward();
                    await _showQuestionDialog(context);
                    _animationController!.reverse();
                  },
                  child: AnimatedBuilder(
                    animation: _animationController!,
                    builder: (context, child) {
                      return Container(
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
                          child: Transform.rotate(
                            angle: _rotationAnimation!.value * 1.5 * 3.141592653589793,
                            child: Icon(Icons.add, color: Colors.white, size: 22),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
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
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredQuestions.length,
                        itemBuilder: (context, index) {
                          return QuestionPreviewCard(
                            question: _filteredQuestions[index],
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuestionDetailPage(
                                    questionDoc: _filteredQuestions[index],
                                    onAnswerPosted: _loadInitialQuestions,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (_totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_currentPage > 1) ...[
                              _pageButton(0),
                              if (_currentPage > 2) Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                            if (_currentPage > 0) _pageButton(_currentPage - 1),
                            _pageButton(_currentPage),
                            if (_currentPage < _totalPages - 1) _pageButton(_currentPage + 1),
                            if (_currentPage < _totalPages - 2) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              _pageButton(_totalPages - 1),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _pageButton(int page) {
    return GestureDetector(
      onTap: () => _loadPage(page),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        decoration: BoxDecoration(
          color: page == _currentPage ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${page + 1}',
          style: TextStyle(
            color: page == _currentPage ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
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
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          style: TextStyle(fontSize: 14),
          maxLines: 3,
          textAlignVertical: TextAlignVertical.top,
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

  Future<void> _postQuestion() async {
    final user = _auth.currentUser;
    if (user == null) return;
    String username = (user.displayName ?? '').trim();
    if (username.isEmpty) {
      username = user.email != null && user.email!.contains('@')
          ? user.email!.split('@')[0]
          : 'Anonymous';
    }
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('questions').add({
        'text': _questionController.text.trim(),
        'userId': user.uid,
        'userName': username,
        'timestamp': FieldValue.serverTimestamp(),
        'answers': [],
      });
      await _loadInitialQuestions(); // Reload questions after posting
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting question: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class QuestionPreviewCard extends StatelessWidget {
  final DocumentSnapshot question;
  final VoidCallback onTap;
  const QuestionPreviewCard({Key? key, required this.question, required this.onTap}) : super(key: key);

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final data = question.data() as Map<String, dynamic>;
    final answers = List<Map<String, dynamic>>.from(data['answers'] ?? []);
    final userName = data['userName'] as String? ?? 'Anonymous';
    final userId = data['userId'] as String?;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isYou = currentUser?.uid == userId;
    // Use the same logic as _buildUserInfo for username
    String username = userName;
    if (isYou && currentUser != null) {
      username = (currentUser.displayName ?? '').trim();
      if (username.isEmpty) {
        username = currentUser.email != null && currentUser.email!.contains('@')
            ? currentUser.email!.split('@')[0]
            : 'Anonymous';
      }
    } else {
      if (username.contains('@')) {
        username = username.split('@')[0];
      }
    }
    if (username.length > 14) {
      username = username.substring(0, 11) + '...';
    }
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(_getInitials(username))),
        title: Text(
          data['text'] ?? '',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text('By $username'),
            if (isYou)
              Container(
                margin: EdgeInsets.only(left: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.question_answer, color: Colors.grey, size: 18),
            SizedBox(width: 4),
            Text('${answers.length}'),
          ],
        ),
      ),
    );
  }
}

class QuestionDetailPage extends StatefulWidget {
  final DocumentSnapshot questionDoc;
  final VoidCallback? onAnswerPosted;
  const QuestionDetailPage({Key? key, required this.questionDoc, this.onAnswerPosted}) : super(key: key);

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  final TextEditingController _answerController = TextEditingController();
  bool _isLoading = false;
  late Map<String, dynamic> data;
  late List<Map<String, dynamic>> answers;
  int _currentAnswerPage = 0;
  static const int _answersPerPage = 10;

  @override
  void initState() {
    super.initState();
    data = widget.questionDoc.data() as Map<String, dynamic>;
    answers = List<Map<String, dynamic>>.from(data['answers'] ?? []);
  }

  List<Map<String, dynamic>> get _pagedAnswers {
    final start = _currentAnswerPage * _answersPerPage;
    final end = (start + _answersPerPage).clamp(0, answers.length);
    return answers.sublist(start, end);
  }

  int get _totalPages => (answers.length / _answersPerPage).ceil();

  Future<void> _postAnswer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String username = (user.displayName ?? '').trim();
    if (username.isEmpty) {
      username = user.email != null && user.email!.contains('@')
          ? user.email!.split('@')[0]
          : 'Anonymous';
    }
    setState(() => _isLoading = true);
    try {
      final questionRef = FirebaseFirestore.instance.collection('questions').doc(widget.questionDoc.id);
      final questionDoc = await questionRef.get();
      if (!questionDoc.exists) throw Exception('Question not found');
      final currentAnswers = List<Map<String, dynamic>>.from(questionDoc.data()?['answers'] ?? []);
      currentAnswers.add({
        'text': _answerController.text.trim(),
        'userId': user.uid,
        'userName': username,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
      await questionRef.update({'answers': currentAnswers});
      setState(() {
        answers = currentAnswers;
        _answerController.clear();
        _isLoading = false;
      });
      if (widget.onAnswerPosted != null) widget.onAnswerPosted!();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Answer posted successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting answer: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteQuestion() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('questions').doc(widget.questionDoc.id).delete();
      Navigator.of(context).pop(); // Close detail page
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Question deleted successfully'), backgroundColor: Colors.green),
      );
      if (widget.onAnswerPosted != null) widget.onAnswerPosted!();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting question: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Question'),
        content: Text('Are you sure you want to delete this question? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteQuestion();
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
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

  Widget _buildCodeBlock(String text) {
    final codeBlocks = text.split('---');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: codeBlocks.asMap().entries.map((entry) {
        final index = entry.key;
        final block = entry.value;
        if (index % 2 == 1) {
          // Code block (ultra minimal margin)
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
              language: 'cpp',
              theme: githubTheme,
              padding: EdgeInsets.zero,
              textStyle: TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          );
        } else {
          // Regular text with bold/underline
          final spans = <TextSpan>[];
          var currentText = block;
          while (currentText.contains('**')) {
            final partsBefore = currentText.split('**');
            if (partsBefore.length > 1) {
              spans.add(TextSpan(
                text: partsBefore[0],
                style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87),
              ));
              spans.add(TextSpan(
                text: partsBefore[1],
                style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87, fontWeight: FontWeight.bold),
              ));
              currentText = partsBefore.sublist(2).join('**');
            } else {
              break;
            }
          }
          while (currentText.contains('__')) {
            final partsBefore = currentText.split('__');
            if (partsBefore.length > 1) {
              spans.add(TextSpan(
                text: partsBefore[0],
                style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87),
              ));
              spans.add(TextSpan(
                text: partsBefore[1],
                style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87, decoration: TextDecoration.underline),
              ));
              currentText = partsBefore.sublist(2).join('__');
            } else {
              break;
            }
          }
          if (currentText.isNotEmpty) {
            spans.add(TextSpan(
              text: currentText,
              style: TextStyle(fontSize: 16, height: 1.0, color: Colors.black87),
            ));
          }
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: SelectableText.rich(TextSpan(children: spans)),
          );
        }
      }).toList(),
    );
  }

  Widget _buildUserInfo(String userName, bool isOP, bool isYou, {String? userId}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    String username = userName;
    if (userId != null && currentUser != null && userId == currentUser.uid) {
      username = (currentUser.displayName ?? '').trim();
      if (username.isEmpty) {
        username = currentUser.email != null && currentUser.email!.contains('@')
            ? currentUser.email!.split('@')[0]
            : 'Anonymous';
      }
    } else {
      if (username.contains('@')) {
        username = username.split('@')[0];
      }
    }
    if (username.length > 14) {
      username = username.substring(0, 11) + '...';
    }
    return Row(
      children: [
        CircleAvatar(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?')),
        SizedBox(width: 8),
        if (isOP)
          Container(
            margin: EdgeInsets.only(right: 4),
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'OP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (isYou)
          Container(
            margin: EdgeInsets.only(right: 4),
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'YOU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] as String? ?? 'Anonymous';
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == data['userId'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Question'),
        actions: [
          if (isOwner)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Question',
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildUserInfo(userName, true, isOwner, userId: data['userId']),
                      ),
                      Text(_formatTimestamp(data['timestamp']), style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildCodeBlock(data['text'] ?? ''),
                  SizedBox(height: 24),
                  Text('Answers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  SizedBox(height: 8),
                  if (answers.isEmpty)
                    Text('No answers yet.', style: TextStyle(color: Colors.grey)),
                  ..._pagedAnswers.map((answer) {
                    final answerUserName = answer['userName'] as String? ?? 'Anonymous';
                    final isAnswerOP = answer['userId'] == data['userId'];
                    final isAnswerYou = currentUser?.uid == answer['userId'];
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildUserInfo(answerUserName, isAnswerOP, isAnswerYou, userId: answer['userId']),
                              ),
                              Text(_formatTimestamp(answer['timestamp']), style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          SizedBox(height: 4),
                          _buildCodeBlock(answer['text'] ?? ''),
                        ],
                      ),
                    );
                  }).toList(),
                  if (_totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_currentAnswerPage > 1) ...[
                            _pageButton(0),
                            if (_currentAnswerPage > 2) Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                          if (_currentAnswerPage > 0) _pageButton(_currentAnswerPage - 1),
                          _pageButton(_currentAnswerPage),
                          if (_currentAnswerPage < _totalPages - 1) _pageButton(_currentAnswerPage + 1),
                          if (_currentAnswerPage < _totalPages - 2) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            _pageButton(_totalPages - 1),
                          ],
                        ],
                      ),
                    ),
                  SizedBox(height: 24),
                  TextField(
                    controller: _answerController,
                    decoration: InputDecoration(
                      labelText: 'Your Answer',
                      labelStyle: TextStyle(fontSize: 14),
                      border: OutlineInputBorder(),
                      hintText: 'Your answer',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      alignLabelWithHint: true,
                    ),
                    style: TextStyle(fontSize: 14),
                    maxLines: 3,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _postAnswer,
                      icon: Icon(Icons.send),
                      label: Text('Post Answer'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _pageButton(int i) {
    return GestureDetector(
      onTap: () => setState(() => _currentAnswerPage = i),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        decoration: BoxDecoration(
          color: i == _currentAnswerPage ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${i + 1}',
          style: TextStyle(
            color: i == _currentAnswerPage ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 