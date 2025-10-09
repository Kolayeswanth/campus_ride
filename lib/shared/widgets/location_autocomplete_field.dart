import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/nominatim_location_service.dart';
import '../../core/models/bus_route.dart';

/// Enhanced location autocomplete widget for accurate location selection
class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final bool isRequired;
  final LatLng? biasLocation;
  final String? filterState;
  final Function(LocationSuggestion)? onLocationSelected;
  final VoidCallback? onClearSelection;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.isRequired = false,
    this.biasLocation,
    this.filterState,
    this.onLocationSelected,
    this.onClearSelection,
  });

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  List<LocationSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  LocationSuggestion? _selectedLocation;
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (_suggestions.isNotEmpty && !_showSuggestions) {
        setState(() {
          _showSuggestions = true;
        });
        _showSuggestionsOverlay();
      }
    } else {
      // Delay hiding suggestions to allow for tap selection
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_focusNode.hasFocus && mounted) {
          setState(() {
            _showSuggestions = false;
          });
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    
    if (query.isEmpty) {
      _clearSuggestions();
      return;
    }

    if (query.length < 3) {
      _clearSuggestions();
      return;
    }

    // Debounce search requests
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchLocations(query);
    });
  }

  void _clearSuggestions() {
    setState(() {
      _suggestions.clear();
      _isSearching = false;
      _showSuggestions = false;
      _selectedLocation = null;
    });
    _removeOverlay();
    widget.onClearSelection?.call();
  }

  Future<void> _searchLocations(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final suggestions = await NominatimLocationService.searchLocations(query);

      if (!mounted) return;

      setState(() {
        _suggestions = suggestions;
        _isSearching = false;
        _showSuggestions = suggestions.isNotEmpty;
      });

      if (_showSuggestions && _focusNode.hasFocus) {
        _showSuggestionsOverlay();
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _suggestions.clear();
        _isSearching = false;
        _showSuggestions = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching locations: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectLocation(LocationSuggestion suggestion) {
    if (!mounted) return;
    
    // Remove overlay immediately to prevent flicker
    _removeOverlay();
    
    setState(() {
      _selectedLocation = suggestion;
      _showSuggestions = false;
      // Use display name for better user experience
      widget.controller.text = suggestion.displayName.isNotEmpty
          ? suggestion.displayName.split(',').first.trim()
          : suggestion.displayName;
    });

    // Unfocus after state update
    _focusNode.unfocus();
    
    // Call callback
    widget.onLocationSelected?.call(suggestion);
    
    // Debug log
    if (kDebugMode) {
      print('Location selected: ${suggestion.displayName} at LatLng(${suggestion.latitude}, ${suggestion.longitude})');
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getSuggestionsWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            shadowColor: Colors.black26,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getSuggestionsWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  Widget _buildSuggestionsList() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Searching...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Text(
              'No locations found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return _buildSuggestionTile(suggestion);
      },
    );
  }

  Widget _buildSuggestionTile(LocationSuggestion suggestion) {
    return InkWell(
      onTap: () => _selectLocation(suggestion),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.location_on,
                size: 18,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getLocationName(suggestion),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getLocationAddress(suggestion),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Place',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLocationName(LocationSuggestion suggestion) {
    final parts = suggestion.displayName.split(',');
    return parts.isNotEmpty ? parts.first.trim() : suggestion.displayName;
  }

  String _getLocationAddress(LocationSuggestion suggestion) {
    final parts = suggestion.displayName.split(',');
    if (parts.length > 1) {
      return parts.skip(1).map((s) => s.trim()).join(', ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText + (widget.isRequired ? ' *' : ''),
              hintText: widget.hintText,
              prefixIcon: Icon(widget.prefixIcon),
              suffixIcon: _buildSuffixIcon(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: widget.isRequired
                ? (value) {
                    if (value?.isEmpty ?? true) {
                      return '${widget.labelText} is required';
                    }
                    if (_selectedLocation == null) {
                      return 'Please select a location from suggestions';
                    }
                    return null;
                  }
                : null,
            onFieldSubmitted: (_) {
              _focusNode.unfocus();
            },
          ),
          if (_selectedLocation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${_selectedLocation!.displayName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedLocation = null;
                        widget.controller.clear();
                      });
                      widget.onClearSelection?.call();
                    },
                    icon: Icon(
                      Icons.close,
                      color: Colors.green.shade600,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_selectedLocation != null) {
      return Icon(
        Icons.check_circle,
        color: Colors.green.shade600,
      );
    }

    if (widget.controller.text.isNotEmpty) {
      return IconButton(
        onPressed: () {
          widget.controller.clear();
          _clearSuggestions();
        },
        icon: const Icon(Icons.clear),
        color: Colors.grey.shade600,
      );
    }

    return null;
  }

  /// Get the selected location
  LocationSuggestion? get selectedLocation => _selectedLocation;

  /// Programmatically set a location
  void setLocation(LocationSuggestion suggestion) {
    _selectLocation(suggestion);
  }

  /// Check if a valid location is selected
  bool get hasValidSelection => _selectedLocation != null;
}