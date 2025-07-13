import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wakepoint/models/predictions/location.dart';
import 'package:wakepoint/models/predictions/prediction.dart';
import 'package:wakepoint/models/predictions/predictions.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "OlaAutocomplete";
void logHere(String message) => log(message, tag: _logTag);

typedef OlaItemClick = void Function(Prediction prediction);
typedef OlaItemBuilder = Widget Function(
    BuildContext context, int index, Prediction prediction);

class OlaAutoCompleteTextField extends StatefulWidget {
  final TextEditingController controller;
  final String apiKey;
  final InputDecoration decoration;
  final TextStyle textStyle;
  final OlaItemClick? onItemTap;
  final Function(Location)? getPredictionWithLatLng;
  final OlaItemBuilder? itemBuilder;
  final double? latitude;
  final double? longitude;
  final bool isCrossBtnShown;
  final int debounceTime;

  const OlaAutoCompleteTextField({
    super.key,
    required this.controller,
    required this.apiKey,
    this.decoration = const InputDecoration(),
    this.textStyle = const TextStyle(),
    this.onItemTap,
    this.itemBuilder,
    this.latitude,
    this.longitude,
    this.debounceTime = 600,
    this.isCrossBtnShown = true,
    this.getPredictionWithLatLng,
  });

  @override
  State<OlaAutoCompleteTextField> createState() =>
      _OlaAutoCompleteTextFieldState();
}

class _OlaAutoCompleteTextFieldState extends State<OlaAutoCompleteTextField> {
  final _subject = PublishSubject<String>();
  final _layerLink = LayerLink();
  final _dio = Dio();
  OverlayEntry? _overlayEntry;
  CancelToken? _cancelToken;
  List<Prediction> _predictions = [];
  final GlobalKey _fieldKey = GlobalKey();
  bool isCrossBtn = true;

  @override
  void initState() {
    super.initState();
    _subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(_onSearchChanged);
  }

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      _removeOverlay();
      return;
    }

    String baseUrl = "https://api.olamaps.io/places/v1/autocomplete";
    String location = (widget.latitude != null && widget.longitude != null)
        ? "&location=${widget.latitude}%2C${widget.longitude}"
        : "";
    String types = "&types=locality";

    String url =
        "$baseUrl?input=${Uri.encodeComponent(query)}$location$types&api_key=${widget.apiKey}";

    logHere('🔍 Searching for: $query');
    logHere('🌐 URL: $url');

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final response = await _dio.get(url, cancelToken: _cancelToken);
      logHere('📥 Raw Response: ${response.data}');

      final data = Predictions.fromJson(response.data);
      logHere('✅ Parsed Predictions Status: ${data.status}');
      logHere('📊 Prediction Count: ${data.predictions?.length ?? 0}');

      if (data.status == "ok" && data.predictions != null) {
        _predictions = data.predictions!;
        logHere('Predictions: ${_predictions.length}');
        _showOverlay();
      }
    } catch (e, s) {
      logHere('❌ Error fetching predictions: $e');
      logHere('🔻 Stacktrace: $s');
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    if (_overlayEntry != null) {
      logHere('📤 Inserting overlay with ${_predictions.length} items');
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      logHere('⚠️ OverlayEntry was null or failed');
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _predictions.clear();
  }

  OverlayEntry _createOverlayEntry() {
    final renderObject = _fieldKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      logHere('❗ RenderBox not available');
      return OverlayEntry(builder: (_) => const SizedBox());
    }

    final renderBox = renderObject;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 5,
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(0, size.height + 5),
          showWhenUnlinked: false,
          child: Material(
            elevation: 4,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _predictions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                final fallbackText =
                    prediction.terms?.map((t) => t.value).join(', ') ?? '';
                final displayText = prediction.description?.isNotEmpty == true
                    ? prediction.description!
                    : fallbackText;

                return InkWell(
                  onTap: () {
                    logHere('✅ Selected: $displayText');
                    widget.controller.text = displayText;
                    widget.onItemTap?.call(prediction);

                    final location = prediction.geometry?.location;
                    if (location != null) {
                      widget.getPredictionWithLatLng?.call(location);
                    } else {
                      logHere(
                          '⚠️ Location is null for prediction: $displayText');
                    }

                    _removeOverlay();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      displayText,
                      style: widget.textStyle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void clearData() {
    widget.controller.clear();
    isCrossBtn = false;
    _removeOverlay();
    setState(() {});
  }

  _showCrossIconWidget() {
    return widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _subject.close();
    _cancelToken?.cancel();
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: _fieldKey,
              controller: widget.controller,
              decoration: widget.decoration.copyWith(
                suffixIcon: widget.isCrossBtnShown && _showCrossIconWidget()
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: clearData,
                      )
                    : null,
              ),
              style: widget.textStyle,
              onChanged: (string) {
                _subject.add(string);
                if (widget.isCrossBtnShown) {
                  isCrossBtn = string.isNotEmpty;
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
