import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wakepoint/models/predictions/location.dart';
import 'package:wakepoint/models/predictions/prediction.dart';
import 'package:wakepoint/utils/utils.dart';
import 'package:wakepoint/services/places_service.dart';

const String _logTag = "AutoCompleteTextField";
void logHere(String message) => log(message, tag: _logTag);

typedef ItemClick = void Function(Prediction prediction);

class AutoCompleteTextField extends StatefulWidget {
  final TextEditingController controller;
  final String apiKey;
  final InputDecoration decoration;
  final TextStyle textStyle;
  final ItemClick? onItemTap;
  final Function(Location)? getPredictionWithLatLng;
  final double? latitude;
  final double? longitude;
  final bool isCrossBtnShown;
  final int debounceTime;

  const AutoCompleteTextField({
    super.key,
    required this.controller,
    required this.apiKey,
    this.decoration = const InputDecoration(),
    this.textStyle = const TextStyle(),
    this.onItemTap,
    this.latitude,
    this.longitude,
    this.debounceTime = 600,
    this.isCrossBtnShown = true,
    this.getPredictionWithLatLng,
  });

  @override
  State<AutoCompleteTextField> createState() => _AutoCompleteTextFieldState();
}

class _AutoCompleteTextFieldState extends State<AutoCompleteTextField> {
  final _subject = PublishSubject<String>();
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  final PlacesService _placesService = PlacesService();

  CancelToken? _cancelToken;
  OverlayEntry? _overlayEntry;
  List<Prediction> _predictions = [];
  bool isCrossBtn = true;

  @override
  void initState() {
    super.initState();
    _subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(_onSearchChanged);
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      _removeOverlay();
      return;
    }

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final result = await _placesService.fetchPredictions(
      apiKey: widget.apiKey,
      query: query,
      lat: widget.latitude,
      lng: widget.longitude,
      cancelToken: _cancelToken,
    );

    if (result?.status == "ok" && result?.predictions != null) {
      _predictions = result!.predictions!;
      logHere('📊 Fetched ${_predictions.length} predictions');
      _showOverlay();
    } else {
      logHere("⚠️ No predictions found or request failed");
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _predictions.clear();
  }

  OverlayEntry _createOverlayEntry() {
    final renderObject = _fieldKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
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
                    child: Text(displayText, style: widget.textStyle),
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

  bool _showCrossIconWidget() {
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
