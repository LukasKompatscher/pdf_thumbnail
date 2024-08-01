import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

/// A typedef representing a callback function that takes an integer parameter
/// representing a page number and returns void.
typedef ThumbnailPageCallback = void Function(int page);

/// A typedef representing a function that takes an integer parameter
/// representing a page number and a boolean indicating whether it is the
/// current page, and returns a Widget.
// ignore: avoid_positional_boolean_parameters
typedef CurrentPageWidget = Widget Function(int page, bool isCurrentPage);

/// A widget that displays a thumbnail of a PDF file.
class PdfThumbnail extends StatefulWidget {
  /// Creates a [PdfThumbnail] widget from a file path.
  ///
  /// The [path] parameter specifies the path to the PDF file.
  /// The [key] parameter is an optional key to identify this widget.
  /// The [backgroundColor] the background color of the thumbnail.
  /// The [currentPageDecoration] the decoration for the current page.
  /// The [currentPageWidget] the widget to display for the current page.
  /// The [height] the height of the thumbnail.
  /// The [onPageClicked] is a callback function that is
  /// called when a page is clicked.
  /// The [currentPage] the current page number.
  /// The [loadingIndicator] the widget to display while loading the thumbnail.
  /// The [scrollToCurrentPage] whether to scroll to the current page.
  /// The [closeButton] the widget to display as a close button.
  factory PdfThumbnail.fromFile(
    String path, {
    Color? backgroundColor,
    BoxDecoration? currentPageDecoration,
    CurrentPageWidget? currentPageWidget,
    double? height,
    ThumbnailPageCallback? onPageClicked,
    required int currentPage,
    Widget? loadingIndicator,
    bool? scrollToCurrentPage,
    Widget? closeButton,
  }) {
    return PdfThumbnail._(
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
    );
  }

  /// Private constructor for [PdfThumbnail].
  const PdfThumbnail._({
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
  });

  /// The path to the PDF file.
  final String? path;

  /// The background color of the thumbnail.
  final Color? backgroundColor;

  /// The decoration for the current page.
  final BoxDecoration? currentPageDecoration;

  /// The widget to display for the current page.
  final CurrentPageWidget? currentPageWidget;

  /// The height of the thumbnail.
  final double height;

  /// A callback function that is called when a page is clicked.
  final ThumbnailPageCallback? onPageClicked;

  /// The current page number.
  final int currentPage;

  /// The widget to display while loading the thumbnail.
  final Widget? loadingIndicator;

  /// The widget to display as a close button.
  final Widget? closeButton;

  /// Whether to scroll to the current page.
  final bool scrollToCurrentPage;

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  late ScrollController controller;
  late ImageThumbnailCacher cacher;
  final Map<int, Future<Uint8List?>> _imageFutures = {};
  final Map<int, Uint8List?> _imageCache = {};
  late PdfImageRendererPdf _pdf;
  int _pageCount = 0;
  bool _isRendering = false;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    cacher = ImageThumbnailCacher();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      _pdf = PdfImageRendererPdf(path: widget.path!);
      await _pdf.open();
      _pageCount = await _pdf.getPageCount();
      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
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
      swipeToPage(widget.currentPage, _pageCount);
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
          child: _pageCount > 0
              ? ListView.builder(
                  controller: controller,
                  padding: EdgeInsets.symmetric(vertical: widget.height * 0.1),
                  scrollDirection: Axis.horizontal,
                  itemCount: _pageCount,
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
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
                )
              : widget.loadingIndicator!,
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

    if (_isRendering) {
      // Wait until the current rendering is finished
      // ignore: inference_failure_on_instance_creation
      await Future.delayed(const Duration(milliseconds: 100));
      return _loadImage(pageNumber, filePath);
    }

    _isRendering = true;

    try {
      await _pdf.openPage(pageIndex: pageNumber);
      final size = await _pdf.getPageSize(pageIndex: pageNumber);
      final img = await _pdf.renderPage(
        pageIndex: pageNumber,
        x: 0,
        y: 0,
        width: size.width,
        height: size.height,
        scale: 1,
      );
      await _pdf.closePage(pageIndex: pageNumber);

      _imageCache[pageNumber] = img;
      await cacher.write(filePath, pageNumber, img!);
      return img;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return null;
    } finally {
      _isRendering = false;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _pdf.close();
    super.dispose();
  }
}

/// A class that provides methods for reading and writing image thumbnails.
class ImageThumbnailCacher {
  /// Reads the image thumbnail data from the cache.
  ///
  /// Returns the image thumbnail data as a [Uint8List]
  /// if it exists in the cache, otherwise returns `null`.
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

  /// Writes the image thumbnail data to the cache.
  ///
  /// Returns `true` if the write operation is successful,
  /// otherwise returns `false`.
  ///
  /// The [id] parameter is the unique identifier of the image.
  ///
  /// The [page] parameter is the page number of the image.
  ///
  /// The [data] parameter is the image thumbnail data to be written.
  Future<bool> write(String id, int page, Uint8List data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Create the directory if it does not exist
      final file = File('${dir.path}/$id-$page.png');
      await file.create(recursive: true);
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
