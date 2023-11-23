import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:styled_text/styled_text.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.yellow,
          selectionColor: Colors.green,
          selectionHandleColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ConvertedHtml {
  ConvertedHtml({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

class _MyHomePageState extends State<MyHomePage> {
  String _res = 'upload scss please...';
  List _downLoadWaitList = [];
  List<XFile> _waitList = [];
  List<ConvertedHtml> _convertedList = [];

  String _openTag({
    required String tagName,
    required int depth,
    String className = '',
  }) {
    String indent = '  ' * depth;
    return switch (tagName) {
      'Link' => '$indent&lt;<tag>Link</tag> src="" <class>className</class><equal>=</equal><className>"$className"</className>/&gt;\n',
      'Image' => '$indent&lt;<tag>Image</tag> alt ="" width="" heigth=""<class>className</class><equal>=</equal><className>"$className"</className>/&gt;\n',
      _ => '$indent&lt;<tag>$tagName</tag> <class>className</class><equal>=</equal><className>"$className"</className>&gt;\n',
    };
  }

  String _closeTag({
    required String tagName,
    required int depth,
  }) {
    String indent = '  ' * depth;
    return switch (tagName) {
      'Link' || 'Image' => '',
      _ => '$indent&lt;/<tag>$tagName</tag>&gt;\n',
    };
  }

  _getTageName({required String className, required String contents}) {
    final classNameWithTagNamePattern = RegExp('\\.$className\\s*[\\{|,]\\n.*//([a-zA-Z]+)');
    final tagMatch = classNameWithTagNamePattern.firstMatch(contents);
    final tagName = tagMatch?.group(1) ?? 'div';
    return tagName;
  }

  Future<String> _convertScssToHtml(String contents) async {
    String result = '';

    final classNamePattern = RegExp(r'\.([a-zA-Z0-9_-]+)\s*[\{|,]');
    final closeTagPattern = RegExp(r'\}');

    List contentsByLine = contents.split('\n');

    List tagStak = [];
    bool findMediaTag = false;
    for (String line in contentsByLine) {
      final matchedClassName = classNamePattern.firstMatch(line);
      final matchCloseTag = closeTagPattern.firstMatch(line);

      if (line.contains('@media')) findMediaTag = true;
      if (findMediaTag) continue;

      if (matchedClassName != null) {
        String className = matchedClassName[1] ?? '';
        String tagName = _getTageName(className: className, contents: contents);
        result += _openTag(tagName: tagName, className: className, depth: tagStak.length);
        tagStak.add(tagName);
        if (line.contains(',')) {
          tagStak.removeLast();
          result += _closeTag(tagName: tagName, depth: tagStak.length);
        }
      } else if (matchCloseTag != null) {
        String tagName = tagStak.last;
        tagStak.removeLast();
        result += _closeTag(tagName: tagName, depth: tagStak.length);
      }
    }
    return result;
  }

  _onClickUpload() async {
    FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['scss'],
    );
    if (pickedFile != null) {
      pickedFile.files.forEach((flieData) {
        XFile file = XFile(flieData.path!);
        _waitList.add(file);
      });
      setState(() {});
    } else {
      //파일 불러오기 실패시
    }
  }

  _onClickConvert() async {
    if (_waitList.isNotEmpty) {
      _convertedList = await Future.wait(_waitList.map((file) async {
        String code = await _convertScssToHtml(await file.readAsString());
        return ConvertedHtml(code: code, name: file.name);
      }));
      setState(() {});
    }
  }

  _onClickDownload() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    for (var html in _convertedList) {
      final savedFile = File('$selectedDirectory/${html.name.split('/').last.split('.').first}.html');
      await savedFile.writeAsString(html.code.replaceAll(RegExp(r'<.*?>'), '').replaceAll('&lt;', '<').replaceAll('&gt;', '>'));
    }

    _downLoadWaitList.clear();
  }

  _onClickClear() {
    _res = '';
    _downLoadWaitList = [];
    _waitList = [];
    _convertedList = [];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ElevatedButton(onPressed: _onClickUpload, child: const Text('upload')),
                    ElevatedButton(onPressed: _onClickClear, child: const Text('clear')),
                    ElevatedButton(onPressed: _onClickConvert, child: const Text('convert')),
                    ElevatedButton(onPressed: _onClickDownload, child: const Text('download')),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: _convertedList.isEmpty
                      ? DropTarget(
                          onDragDone: (detail) {
                            setState(() {
                              for (var file in detail.files) {
                                if (file.name.split('.').last == 'scss') _waitList.add(file);
                              }
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(40),
                            margin: const EdgeInsets.symmetric(horizontal: 80),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: const Color.fromARGB(255, 40, 42, 54),
                            ),
                            child: _waitList.isEmpty
                                ? const Center(
                                    child: Text(
                                    'drag file here...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                    ),
                                  ))
                                : Wrap(
                                    children: [..._waitList.map((file) => FileCard(file: file))],
                                  ),
                          ),
                        )
                      : CarouselSlider(
                          options: CarouselOptions(
                            aspectRatio: 1,
                            disableCenter: true,
                            enableInfiniteScroll: false,
                          ),
                          items: _convertedList
                              .map((item) => Container(
                                    padding: const EdgeInsets.all(40),
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      color: const Color.fromARGB(255, 40, 42, 54),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Container(
                                        child: Center(child: CodeText(code: item.code)),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 32)
              ],
            ),
          )
        ],
      ),
    );
  }
}

class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.file});
  final XFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      width: 105,
      height: 105,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color.fromARGB(113, 201, 204, 220),
      ),
      child: Center(
        child: Text(
          file.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class CodeText extends StatelessWidget {
  const CodeText({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: StyledText(
        text: code,
        style: const TextStyle(
          height: 1.5,
          fontSize: 16,
          color: Colors.white,
        ),
        tags: {
          'tag': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 255, 121, 198))),
          'equal': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 255, 121, 198))),
          'class': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 80, 250, 123))),
          'className': StyledTextTag(style: const TextStyle(color: Color.fromARGB(255, 255, 244, 137))),
        },
      ),
    );
  }
}