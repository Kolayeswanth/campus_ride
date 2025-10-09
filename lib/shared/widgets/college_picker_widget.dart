import 'package:flutter/material.dart';
import '../../../core/models/college.dart';
import '../../../core/services/college_service.dart';

class CollegePickerWidget extends StatefulWidget {
  final College? selectedCollege;
  final Function(College) onCollegeSelected;
  final String? hintText;

  const CollegePickerWidget({
    super.key,
    this.selectedCollege,
    required this.onCollegeSelected,
    this.hintText,
  });

  @override
  State<CollegePickerWidget> createState() => _CollegePickerWidgetState();
}

class _CollegePickerWidgetState extends State<CollegePickerWidget> {
  final CollegeService _collegeService = CollegeService.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<College> _colleges = [];
  List<College> _filteredColleges = [];
  bool _isLoading = false;
  bool _isExpanded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadColleges();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isExpanded) {
      // Delay closing to allow for tap on college item
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() => _isExpanded = false);
        }
      });
    }
  }

  Future<void> _loadColleges() async {
    if (_colleges.isNotEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final colleges = await _collegeService.getAllColleges();
      setState(() {
        _colleges = colleges;
        _filteredColleges = colleges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Failed to load colleges: $e');
    }
  }

  void _filterColleges(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredColleges = _colleges;
      } else {
        _filteredColleges = _collegeService.searchColleges(query);
      }
    });
  }

  void _selectCollege(College college) {
    _searchController.text = college.name;
    setState(() {
      _isExpanded = false;
      _searchQuery = college.name;
    });
    _focusNode.unfocus();
    widget.onCollegeSelected(college);
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _focusNode.requestFocus();
      _loadColleges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main input field
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isExpanded || widget.selectedCollege != null 
                    ? const Color(0xFF4F46E5) 
                    : const Color(0xFFE5E7EB),
                width: _isExpanded || widget.selectedCollege != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (widget.selectedCollege != null || _isExpanded)
                        ? const Color(0xFF4F46E5).withOpacity(0.1)
                        : const Color(0xFF6B7280).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: (widget.selectedCollege != null || _isExpanded)
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF6B7280),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isExpanded
                      ? TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: _filterColleges,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search colleges...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: const TextStyle(
                            color: Color(0xFF1A1D29),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedCollege?.name ?? 
                              widget.hintText ?? 
                              'Select Your College',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: widget.selectedCollege != null
                                    ? const Color(0xFF1A1D29)
                                    : const Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.selectedCollege != null)
                              Text(
                                '${widget.selectedCollege!.city}, ${widget.selectedCollege!.state}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                ),
                Icon(
                  _isExpanded 
                      ? Icons.keyboard_arrow_up_rounded 
                      : Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: (widget.selectedCollege != null || _isExpanded)
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),

        // Dropdown list
        if (_isExpanded)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    ),
                  )
                : _filteredColleges.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _searchQuery.isEmpty 
                              ? 'No colleges available' 
                              : 'No colleges found for "$_searchQuery"',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredColleges.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: Color(0xFFF3F4F6),
                        ),
                        itemBuilder: (context, index) {
                          final college = _filteredColleges[index];
                          final isSelected = widget.selectedCollege?.id == college.id;
                          
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectCollege(college),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFF4F46E5).withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF4F46E5).withOpacity(0.1),
                                            const Color(0xFF7C3AED).withOpacity(0.1),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF4F46E5).withOpacity(0.2),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: Color(0xFF4F46E5),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            college.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected 
                                                  ? const Color(0xFF4F46E5)
                                                  : const Color(0xFF1A1D29),
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_rounded,
                                                size: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${college.city}, ${college.state}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF6B7280),
                                                    height: 1.2,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                        color: Color(0xFF4F46E5),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
      ],
    );
  }
}
