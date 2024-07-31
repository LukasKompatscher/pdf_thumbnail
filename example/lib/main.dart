import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_thumbnail/pdf_thumbnail.dart';

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
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'PDF Thumbnail Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<File> pdfFile;

  var currentPage = 0;
  @override
  void initState() {
    pdfFile = DownloadService.downloadFile(pdfUrl, 'sample.pdf');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
      ),
      body: FutureBuilder<File>(
          future: pdfFile,
          builder: (context, snapshot) {
            return Center(
              child: snapshot.hasData
                  ? PdfThumbnail.fromFile(
                      snapshot.data!.path,
                      currentPage: currentPage,
                      backgroundColor: Colors.transparent,
                      height: 200,
                      currentPageDecoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      onPageClicked: (page) {
                        setState(() {
                          currentPage = page + 1;
                        });
                        if (kDebugMode) {
                          print('Page $page clicked');
                        }
                      },
                    )
                  : const CircularProgressIndicator(),
            );
          }),
    );
  }
}

const pdfUrl = 'https://icseindia.org/document/sample.pdf';

class DownloadService {
  static final _httpClient = HttpClient();

  static Future<File> downloadFile(String url, String filename) async {
    var request = await _httpClient.getUrl(Uri.parse(url));
    var response = await request.close();
    var bytes = await consolidateHttpClientResponseBytes(response);
    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = File('$dir/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }
}
