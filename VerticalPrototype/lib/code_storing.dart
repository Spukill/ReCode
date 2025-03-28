import 'package:flutter/material.dart';

class CodeStoringTab extends StatefulWidget {
  @override
  _CodeStoringTabState createState() => _CodeStoringTabState();
}

class _CodeStoringTabState extends State<CodeStoringTab> {
  List<Map<String, String>> codeSnippets = [];

  void _addOrEditSnippet({int? index}) {
    TextEditingController titleController = TextEditingController();
    TextEditingController codeController = TextEditingController();

    if (index != null) {
      titleController.text = codeSnippets[index]["title"] ?? "";
      codeController.text = codeSnippets[index]["code"] ?? "";
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? 'Add Note' : 'Edit Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(hintText: "Enter note title"),
              ),
              SizedBox(height: 10),
              TextField(
                controller: codeController,
                maxLines: 5,
                decoration: InputDecoration(hintText: "Enter note details..."),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.isNotEmpty && codeController.text.isNotEmpty) {
                  setState(() {
                    if (index == null) {
                      codeSnippets.add({
                        "title": titleController.text,
                        "code": codeController.text,
                      });
                    } else {
                      codeSnippets[index] = {
                        "title": titleController.text,
                        "code": codeController.text,
                      };
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(index == null ? 'Save' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  void _deleteSnippet(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete Note"),
          content: Text("Are you sure you want to delete this note?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  codeSnippets.removeAt(index);
                });
                Navigator.pop(context);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoteCard(int index) {
    return GestureDetector(
      onTap: () => _addOrEditSnippet(index: index),
      child: Card(
        color: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                codeSnippets[index]["title"] ?? "Untitled",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                codeSnippets[index]["code"] ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: Icon(Icons.more_horiz, color: Colors.white),
                  onPressed: () => _deleteSnippet(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Row(
          children: [
            Icon(Icons.search, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search notes",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              "C++ notes",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: codeSnippets.isEmpty
                  ? Center(child: Text('No notes yet.'))
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, //Two columns per row
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: codeSnippets.length,
                      itemBuilder: (context, index) => _buildNoteCard(index),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOrEditSnippet,
        icon: Icon(Icons.add),
        label: Text("Add Note"),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
