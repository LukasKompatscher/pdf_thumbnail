// Copyright (c) 2022, Very Good Ventures
// https://verygood.ventures
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

/// Callback when the user taps on a thumbnail
typedef ThumbnailPageCallback = void Function(int page);

/// Function that returns page number widget
typedef CurrentPageWidget = Widget Function(int page, bool isCurrentPage);

/// {@template pdf_thumbnail}
/// Thumbnail viewer for pdfs
/// {@endtemplate}
class PdfThumbnail extends StatefulWidget {
  /// Creates a [PdfThumbnail] from a file.
  factory PdfThumbnail.fromFile(
    String path, {
    Key? key,
    Color? backgroundColor,
    BoxDecoration? currentPageDecoration,
    CurrentPageWidget? currentPageWidget,
    double? height,
    ThumbnailPageCallback? onPageClicked,
    required int currentPage,
    Widget? loadingIndicator,
    bool? scrollToCurrentPage,
    Widget? closeButton,
    int? pageCount,
  }) {
    return PdfThumbnail._(
      key: key,
      path: path,
      backgroundColor: backgroundColor ?? Colors.black,
      height: height ?? 200,
      onPageClicked: onPageClicked,
      currentPage: currentPage,
      currentPageWidget:
          currentPageWidget ?? (page, isCurrent) => const SizedBox(),
      currentPageDecoration: currentPageDecoration ??
          BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: Colors.blue,
              width: 4,
            ),
          ),
      loadingIndicator: loadingIndicator ??
          const Center(
            child: CircularProgressIndicator(),
          ),
      scrollToCurrentPage: scrollToCurrentPage ?? false,
      closeButton: closeButton,
      pageCount: pageCount!,
    );
  }
  const PdfThumbnail._({
    super.key,
    this.path,
    this.backgroundColor,
    required this.height,
    this.onPageClicked,
    required this.currentPage,
    this.currentPageDecoration,
    this.loadingIndicator,
    this.currentPageWidget,
    this.scrollToCurrentPage = false,
    this.closeButton,
    required this.pageCount,
  });

  /// File path
  final String? path;

  /// Background color
  final Color? backgroundColor;

  /// Decoration for current page
  final BoxDecoration? currentPageDecoration;

  /// Simple function that returns widget that shows the page number.
  /// Widget will be in [Stack] so you can use [Positioned] or [Align]
  final CurrentPageWidget? currentPageWidget;

  /// Height
  final double height;

  /// Callback to run when a page is clicked
  final ThumbnailPageCallback? onPageClicked;

  /// Current page, index + 1
  final int currentPage;

  /// Loading indicator
  final Widget? loadingIndicator;

  /// Close button
  final Widget? closeButton;

  /// Whether page browser will scroll to the current page or not,
  /// false by default
  final bool scrollToCurrentPage;

  //Page Count,
  final int pageCount;

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  late ScrollController controller;
  late ImageThumbnailCacher cacher;
  final Map<int, Future<Uint8List?>> _imageFutures = {};
  final Map<int, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    cacher = ImageThumbnailCacher();
  }

  void swipeToPage(int page, int itemCount) {
    final contentSize = controller.position.viewportDimension +
        controller.position.maxScrollExtent;
    final index = page - 1;
    final target = contentSize * index / itemCount;
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(covariant PdfThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToCurrentPage &&
        widget.currentPage != oldWidget.currentPage) {
      swipeToPage(widget.currentPage, widget.pageCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.closeButton != null) widget.closeButton!,
        Container(
          height: widget.height,
          color: widget.backgroundColor,
          child: ListView.builder(
            controller: controller,
            padding: EdgeInsets.symmetric(vertical: widget.height * 0.1),
            scrollDirection: Axis.horizontal,
            itemCount: widget.pageCount,
            itemBuilder: (context, index) {
              final pageNumber = index;
              final isCurrentPage = pageNumber == widget.currentPage;

              if (!_imageFutures.containsKey(pageNumber)) {
                _imageFutures[pageNumber] =
                    _loadImage(pageNumber, widget.path!);
              }

              return FutureBuilder<Uint8List?>(
                future: _imageFutures[pageNumber],
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        width: 100,
                        height: widget.height,
                        color: Colors.grey.shade300,
                      ),
                    );
                  } else if (snapshot.hasData) {
                    final image = snapshot.data!;
                    return GestureDetector(
                      onTap: () {
                        widget.onPageClicked?.call(pageNumber);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              key: Key('thumbnail_$pageNumber'),
                              duration: const Duration(milliseconds: 100),
                              decoration: isCurrentPage
                                  ? widget.currentPageDecoration!
                                  : const BoxDecoration(
                                      color: Colors.white,
                                    ),
                              child: Image.memory(image),
                            ),
                            widget.currentPageWidget!(
                              pageNumber,
                              isCurrentPage,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _loadImage(int pageNumber, String filePath) async {
    if (_imageCache.containsKey(pageNumber)) {
      return _imageCache[pageNumber];
    }
    final cachedImage = await cacher.read(filePath, pageNumber);
    if (cachedImage != null) {
      _imageCache[pageNumber] = cachedImage;
      return cachedImage;
    }
    try {
      final imageBytes = await compute(
          _createThumbnail, {'filePath': filePath, 'pageNumber': pageNumber});
      await cacher.write(filePath, pageNumber, imageBytes);
      _imageCache[pageNumber] = imageBytes;
      return imageBytes;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    }
  }

  Future<Uint8List> _createThumbnail(Map<String, dynamic> args) async {
    final filePath = args['filePath'];
    final pageNumber = args['pageNumber'];
    final document = await PdfDocument.openFile(filePath);
    final page = document.pages[pageNumber];
    final pageImage = await page.render(
      width: page.width.toInt(),
      height: page.height.toInt(),
    );
    final image = await pageImage!.createImage();
    final pngBytes = await image.toByteData(format: ImageByteFormat.png);
    return Uint8List.view(pngBytes!.buffer);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// A class that provides methods for reading and writing image thumbnails.
class ImageThumbnailCacher {
  /// Reads the thumbnail image data from the cache.
  ///
  /// Returns the thumbnail image data as a [Uint8List] if it exists in the cache,
  /// otherwise returns `null`.
  ///
  /// The [id] parameter is the unique identifier of the image.
  ///
  /// The [page] parameter is the page number of the image.
  Future<Uint8List?> read(String id, int page) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$id-$page.png');
      if (file.existsSync()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    return null;
  }

  /// Writes the thumbnail image data to the cache.
  ///
  /// Returns `true` if the write operation is successful, otherwise returns `false`.
  ///
  /// The [id] parameter is the unique identifier of the image.
  ///
  /// The [page] parameter is the page number of the image.
  ///
  /// The [data] parameter is the thumbnail image data to be written.
  Future<bool> write(String id, int page, Uint8List data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$id-$page.png');
      await file.writeAsBytes(data);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return false;
    }
  }
}
