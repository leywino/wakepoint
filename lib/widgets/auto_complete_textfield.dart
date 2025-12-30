import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_location_code/open_location_code.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wakepoint/controller/place_search_provider.dart';

import 'package:wakepoint/models/place.dart';
import 'package:wakepoint/utils/utils.dart';

const String _logTag = "AutoCompleteTextField";
void logHere(String message) => log(message, tag: _logTag);

class AutoCompleteTextField extends StatefulWidget {
  final TextEditingController controller;
  final String apiKey;
  final InputDecoration decoration;
  final TextStyle textStyle;
  final PlacesSearchProvider searchProvider;

  /// Called when a place is selected
  final void Function(Place place)? onPlaceSelected;

  /// Called when user enters raw lat,lng or plus code
  final void Function(double lat, double lng)? onManualLatLngDetected;

  final double? latitude;
  final double? longitude;
  final bool isCrossBtnShown;
  final int debounceTime;

  const AutoCompleteTextField({
    super.key,
    required this.controller,
    required this.apiKey,
    required this.searchProvider,
    this.decoration = const InputDecoration(),
    this.textStyle = const TextStyle(),
    this.onPlaceSelected,
    this.onManualLatLngDetected,
    this.latitude,
    this.longitude,
    this.debounceTime = 600,
    this.isCrossBtnShown = true,
  });

  @override
  State<AutoCompleteTextField> createState() => _AutoCompleteTextFieldState();
}

class _AutoCompleteTextFieldState extends State<AutoCompleteTextField> {
  final _subject = PublishSubject<String>();
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  // final PlacesService _placesService = PlacesService();

  CancelToken? _cancelToken;
  OverlayEntry? _overlayEntry;

  bool _isLoading = false;
  List<Place> _places = [];

  @override
  void initState() {
    super.initState();
    _subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(_onSearchChanged);
  }

  // -----------------------------
  // INPUT HANDLERS
  // -----------------------------

  bool _handleLatLngInput(String query) {
    final cleaned = query.replaceAll(RegExp(r'[()\s]'), '');
    final parts = cleaned.split(',');

    if (parts.length != 2) return false;

    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);

    if (lat == null || lng == null) return false;

    logHere("Manual coordinates detected: $lat, $lng");
    widget.onManualLatLngDetected?.call(lat, lng);
    _removeOverlay();
    return true;
  }

  bool _handlePlusCodeInput(String query) {
    try {
      final plusCode = PlusCode.unverified(query);
      if (!plusCode.isValid) return false;

      final codeArea = plusCode.decode();
      final lat = codeArea.center.latitude;
      final lng = codeArea.center.longitude;

      logHere("Plus code decoded: $lat, $lng");
      widget.onManualLatLngDetected?.call(lat, lng);
      _removeOverlay();
      return true;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------
  // PLACES FETCH
  // -----------------------------

  Future<void> _handlePlacePrediction(String query) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final places = await widget.searchProvider.search(
      apiKey: widget.apiKey,
      query: query,
      lat: widget.latitude,
      lng: widget.longitude,
      cancelToken: _cancelToken,
    );

    if (places.isNotEmpty) {
      _places = places;
      logHere('Fetched ${_places.length} places');
      _showOverlay();
    } else {
      logHere("No places found");
      _removeOverlay();
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      _removeOverlay();
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    if (_handleLatLngInput(query) || _handlePlusCodeInput(query)) {
      setState(() => _isLoading = false);
      return;
    }

    await _handlePlacePrediction(query);
    setState(() => _isLoading = false);
  }

  // -----------------------------
  // OVERLAY
  // -----------------------------

  void _showOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _places.clear();
  }

  OverlayEntry _createOverlayEntry() {
    final renderObject = _fieldKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return OverlayEntry(builder: (_) => const SizedBox());
    }

    final size = renderObject.size;
    final offset = renderObject.localToGlobal(Offset.zero);

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
              physics: BouncingScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _places.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = _places[index];

                return InkWell(
                  onTap: () {
                    logHere('✅ Selected: ${place.name}');
                    widget.controller.text = place.name;
                    widget.onPlaceSelected?.call(place);
                    _removeOverlay();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      place.name,
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

  // -----------------------------
  // LIFECYCLE
  // -----------------------------

  void clearData() {
    widget.controller.clear();
    _removeOverlay();
    setState(() {});
  }

  @override
  void dispose() {
    _subject.close();
    _cancelToken?.cancel();
    _removeOverlay();
    super.dispose();
  }

  // -----------------------------
  // UI
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        key: _fieldKey,
        controller: widget.controller,
        decoration: widget.decoration.copyWith(
          suffixIcon:
              widget.isCrossBtnShown && widget.controller.text.isNotEmpty
                  ? (_isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: clearData,
                        ))
                  : null,
        ),
        style: widget.textStyle,
        onChanged: _subject.add,
      ),
    );
  }
}
