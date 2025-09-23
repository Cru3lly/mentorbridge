import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

// 🌳 Tree Node Data Structure
class TreeNode {
  final String id;
  final String name;
  final String role;
  final String? email;
  final String? avatar;
  final String? className; // For mentees
  final String? roomNumber; // For house members
  final bool isVirtual; // True for mentees
  final int level; // Hierarchy depth (0 = root)
  final List<TreeNode> children;
  bool isExpanded;
  
  TreeNode({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.avatar,
    this.className,
    this.roomNumber,
    this.isVirtual = false,
    required this.level,
    this.children = const [],
    this.isExpanded = false,
  });

  // Create a copy with updated properties
  TreeNode copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? avatar,
    String? className,
    String? roomNumber,
    bool? isVirtual,
    int? level,
    List<TreeNode>? children,
    bool? isExpanded,
  }) {
    return TreeNode(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      className: className ?? this.className,
      roomNumber: roomNumber ?? this.roomNumber,
      isVirtual: isVirtual ?? this.isVirtual,
      level: level ?? this.level,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  // Get total subordinate count (recursive)
  int get totalSubordinateCount {
    int count = children.length;
    for (final child in children) {
      count += child.totalSubordinateCount;
    }
    return count;
  }

  // Check if this node has any children
  bool get hasChildren => children.isNotEmpty;

  @override
  String toString() {
    return 'TreeNode(id: $id, name: $name, role: $role, level: $level, children: ${children.length})';
  }
}

// 🎯 Tree Authorization System
class TreeViewPermissions {
  // Roles that can access User Tree page
  static const List<String> authorizedRoles = [
    'admin',
    'moderator', 
    'director',
    'middleSchoolCoordinator',
    'highSchoolCoordinator',
    'universityCoordinator',
    'housingCoordinator',
    'middleSchoolAssistantCoordinator',
    'highSchoolAssistantCoordinator',
    'universityAssistantCoordinator',
    'housingAssistantCoordinator',
    'middleSchoolMentor',
    'highSchoolMentor',
    'houseLeader',
    'studentHouseLeader',
  ];

  // Check if role can access tree view
  static bool canAccessTreeView(String role) {
    return authorizedRoles.contains(role);
  }

  // Get visible subordinate roles for each role
  static List<String> getVisibleSubordinateRoles(String role) {
    switch (role) {
      case 'admin':
      case 'moderator':
        return [
          'director', 'middleSchoolCoordinator', 'highSchoolCoordinator', 
          'universityCoordinator', 'housingCoordinator',
          'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator',
          'universityAssistantCoordinator', 'housingAssistantCoordinator',
          'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 
          'studentHouseLeader', 'houseMember', 'studentHouseMember', 
          'mentee', 'accountant'
        ];
      case 'director':
        return [
          'middleSchoolCoordinator', 'highSchoolCoordinator', 
          'universityCoordinator', 'housingCoordinator',
          'middleSchoolAssistantCoordinator', 'highSchoolAssistantCoordinator',
          'universityAssistantCoordinator', 'housingAssistantCoordinator',
          'middleSchoolMentor', 'highSchoolMentor', 'houseLeader', 
          'studentHouseLeader', 'houseMember', 'studentHouseMember', 
          'mentee', 'accountant'
        ];
      case 'middleSchoolCoordinator':
        return ['middleSchoolAssistantCoordinator', 'middleSchoolMentor', 'mentee'];
      case 'highSchoolCoordinator':
        return ['highSchoolAssistantCoordinator', 'highSchoolMentor', 'mentee'];
      case 'universityCoordinator':
        return ['universityAssistantCoordinator', 'studentHouseLeader', 'studentHouseMember'];
      case 'housingCoordinator':
        return ['housingAssistantCoordinator', 'houseLeader', 'houseMember'];
      case 'middleSchoolAssistantCoordinator':
        return ['middleSchoolMentor', 'mentee'];
      case 'highSchoolAssistantCoordinator':
        return ['highSchoolMentor', 'mentee'];
      case 'universityAssistantCoordinator':
        return ['studentHouseLeader', 'studentHouseMember'];
      case 'housingAssistantCoordinator':
        return ['houseLeader', 'houseMember'];
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
        return ['mentee'];
      case 'houseLeader':
        return ['houseMember'];
      case 'studentHouseLeader':
        return ['studentHouseMember'];
      default:
        return [];
    }
  }
}

// 🎨 Tree Node Position
class TreeNodePosition {
  final String nodeId;
  final Offset position;
  final Size size;
  
  const TreeNodePosition({
    required this.nodeId,
    required this.position,
    required this.size,
  });

  // Check if position contains a point (for tap detection)
  bool contains(Offset point) {
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height)
        .contains(point);
  }
}

// 🎨 Tree Connection Lines Painter
class TreeConnectionsPainter extends CustomPainter {
  final Map<String, TreeNodePosition> nodePositions;
  final Set<String> expandedNodes;
  final TreeNode? rootNode;
  final Animation<double>? animation;

  TreeConnectionsPainter({
    required this.nodePositions,
    required this.expandedNodes,
    required this.rootNode,
    this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (rootNode == null) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw connections recursively
    _drawNodeConnections(canvas, paint, shadowPaint, rootNode!);
  }

  void _drawNodeConnections(Canvas canvas, Paint paint, Paint shadowPaint, TreeNode node) {
    if (!expandedNodes.contains(node.id) || node.children.isEmpty) {
      return;
    }

    final parentPosition = nodePositions[node.id];
    if (parentPosition == null) return;

    final parentCenter = Offset(
      parentPosition.position.dx + parentPosition.size.width / 2,
      parentPosition.position.dy + parentPosition.size.height,
    );

    // Draw connections to all children
    for (final child in node.children) {
      final childPosition = nodePositions[child.id];
      if (childPosition == null) continue;

      final childCenter = Offset(
        childPosition.position.dx + childPosition.size.width / 2,
        childPosition.position.dy,
      );

      // Create smooth curved path
      final path = _createCurvedPath(parentCenter, childCenter);
      
      // Draw shadow first
      canvas.drawPath(path, shadowPaint);
      // Draw main line
      canvas.drawPath(path, paint);

      // Add connection dots
      _drawConnectionDots(canvas, parentCenter, childCenter);

      // Recursively draw child connections
      _drawNodeConnections(canvas, paint, shadowPaint, child);
    }
  }

  Path _createCurvedPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Calculate control points for smooth curve
    final controlPointOffset = (end.dy - start.dy) * 0.5;
    final controlPoint1 = Offset(start.dx, start.dy + controlPointOffset);
    final controlPoint2 = Offset(end.dx, end.dy - controlPointOffset);

    // Create cubic bezier curve
    path.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      end.dx, end.dy,
    );

    return path;
  }

  void _drawConnectionDots(Canvas canvas, Offset start, Offset end) {
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final shadowDotPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw dots at connection points
    canvas.drawCircle(start, 4, shadowDotPaint);
    canvas.drawCircle(start, 3, dotPaint);
    
    canvas.drawCircle(end, 4, shadowDotPaint);
    canvas.drawCircle(end, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is TreeConnectionsPainter) {
      return nodePositions != oldDelegate.nodePositions ||
             expandedNodes != oldDelegate.expandedNodes ||
             rootNode != oldDelegate.rootNode;
    }
    return true;
  }
}

class UniversalUserTreePage extends StatefulWidget {
  final String currentRole;
  final String userId;

  const UniversalUserTreePage({
    super.key,
    required this.currentRole,
    required this.userId,
  });

  @override
  State<UniversalUserTreePage> createState() => _UniversalUserTreePageState();
}

class _UniversalUserTreePageState extends State<UniversalUserTreePage> 
    with TickerProviderStateMixin {
  
  // 🎮 Interactive Controls
  late TransformationController _transformationController;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  // 🌳 Tree Data
  TreeNode? _rootNode;
  final Set<String> _expandedNodes = {};
  final Map<String, TreeNodePosition> _nodePositions = {};
  
  // 🚀 Performance Optimization
  Set<String> _visibleNodes = {}; // Only render nodes in viewport
  double _currentScale = 1.0;
  Offset _currentTranslation = Offset.zero;
  
  // 🔄 Loading State
  bool _isLoading = true;
  String? _error;
  
  // 🎨 Canvas Properties
  static const double _canvasWidth = 3000;
  static const double _canvasHeight = 3000;
  static const double _rootNodeWidth = 220;
  static const double _rootNodeHeight = 120;
  static const double _childNodeWidth = 180;
  static const double _childNodeHeight = 100;
  static const double _horizontalSpacing = 250;
  static const double _verticalSpacing = 160;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _transformationController = TransformationController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    
    // Listen to transformation changes for viewport culling
    _transformationController.addListener(_onTransformationChanged);
    
    // Check authorization and load data
    _initializeTreeView();
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  // 🚀 Handle transformation changes for viewport culling
  void _onTransformationChanged() {
    final transform = _transformationController.value;
    _currentScale = transform.getMaxScaleOnAxis();
    _currentTranslation = Offset(transform.getTranslation().x, transform.getTranslation().y);
    
    // Update visible nodes based on viewport
    _updateVisibleNodes();
  }
  
  // 🚀 Update visible nodes based on current viewport
  void _updateVisibleNodes() {
    if (_rootNode == null) return;
    
    final screenSize = MediaQuery.of(context).size;
    final viewportRect = Rect.fromLTWH(
      -_currentTranslation.dx / _currentScale,
      -_currentTranslation.dy / _currentScale,
      screenSize.width / _currentScale,
      screenSize.height / _currentScale,
    );
    
    // Add buffer area for smooth scrolling
    final bufferRect = viewportRect.inflate(200);
    
    final newVisibleNodes = <String>{};
    _collectVisibleNodes(_rootNode!, bufferRect, newVisibleNodes);
    
    // Only trigger rebuild if visible nodes changed
    if (!_setEquals(_visibleNodes, newVisibleNodes)) {
      setState(() {
        _visibleNodes = newVisibleNodes;
      });
    }
  }
  
  // 🚀 Collect nodes that are visible in the buffer rect
  void _collectVisibleNodes(TreeNode node, Rect bufferRect, Set<String> visibleNodes) {
    final position = _nodePositions[node.id];
    if (position != null) {
      final nodeRect = Rect.fromLTWH(
        position.position.dx,
        position.position.dy,
        position.size.width,
        position.size.height,
      );
      
      if (bufferRect.overlaps(nodeRect)) {
        visibleNodes.add(node.id);
      }
    }
    
    // Check children if expanded
    if (_expandedNodes.contains(node.id)) {
      for (final child in node.children) {
        _collectVisibleNodes(child, bufferRect, visibleNodes);
      }
    }
  }
  
  // 🚀 Helper to compare sets
  bool _setEquals<T>(Set<T> set1, Set<T> set2) {
    if (set1.length != set2.length) return false;
    return set1.containsAll(set2);
  }

  // 🎯 Initialize tree view with authorization check
  void _initializeTreeView() {
    if (!TreeViewPermissions.canAccessTreeView(widget.currentRole)) {
      setState(() {
        _error = 'Access Denied';
        _isLoading = false;
      });
      return;
    }
    
    // Load tree data
    _loadTreeData();
  }

  // 📊 Load tree data from Firebase
  Future<void> _loadTreeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // TODO: Implement Firebase data fetching
      // For now, create a mock tree structure
      await _createMockTreeData();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tree data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // 🎭 Create mock tree data for testing
  Future<void> _createMockTreeData() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Create root node (current user)
    _rootNode = TreeNode(
      id: widget.userId,
      name: 'You (Current User)',
      role: widget.currentRole,
      email: 'current@example.com',
      level: 0,
      isExpanded: true,
      children: _createMockChildren(widget.currentRole, 1),
    );
    
    // Add root to expanded nodes
    _expandedNodes.add(_rootNode!.id);
    
    // Calculate initial positions
    _calculateNodePositions();
    
    // Calculate initial visible nodes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateVisibleNodes();
    });
  }

  // 🎭 Create mock children based on role - FULL HIERARCHY
  List<TreeNode> _createMockChildren(String parentRole, int level) {
    final visibleRoles = TreeViewPermissions.getVisibleSubordinateRoles(parentRole);
    if (visibleRoles.isEmpty) return [];
    
    List<TreeNode> children = [];
    
    // Create COMPLETE hierarchy for each role
    switch (parentRole) {
      case 'director':
        children.addAll([
          TreeNode(
            id: 'coord_1', 
            name: 'Middle School Coordinator', 
            role: 'middleSchoolCoordinator', 
            level: level,
            children: _createMockChildren('middleSchoolCoordinator', level + 1),
          ),
          TreeNode(
            id: 'coord_2', 
            name: 'High School Coordinator', 
            role: 'highSchoolCoordinator', 
            level: level,
            children: _createMockChildren('highSchoolCoordinator', level + 1),
          ),
          TreeNode(
            id: 'coord_3', 
            name: 'University Coordinator', 
            role: 'universityCoordinator', 
            level: level,
            children: _createMockChildren('universityCoordinator', level + 1),
          ),
          TreeNode(
            id: 'coord_4', 
            name: 'Housing Coordinator', 
            role: 'housingCoordinator', 
            level: level,
            children: _createMockChildren('housingCoordinator', level + 1),
          ),
        ]);
        break;
        
      case 'middleSchoolCoordinator':
        children.addAll([
          TreeNode(
            id: 'ms_asst_1', 
            name: 'MS Assistant Coordinator 1', 
            role: 'middleSchoolAssistantCoordinator', 
            level: level,
            children: _createMockChildren('middleSchoolAssistantCoordinator', level + 1),
          ),
          TreeNode(
            id: 'ms_asst_2', 
            name: 'MS Assistant Coordinator 2', 
            role: 'middleSchoolAssistantCoordinator', 
            level: level,
            children: _createMockChildren('middleSchoolAssistantCoordinator', level + 1),
          ),
        ]);
        break;
        
      case 'highSchoolCoordinator':
        children.addAll([
          TreeNode(
            id: 'hs_asst_1', 
            name: 'HS Assistant Coordinator 1', 
            role: 'highSchoolAssistantCoordinator', 
            level: level,
            children: _createMockChildren('highSchoolAssistantCoordinator', level + 1),
          ),
          TreeNode(
            id: 'hs_asst_2', 
            name: 'HS Assistant Coordinator 2', 
            role: 'highSchoolAssistantCoordinator', 
            level: level,
            children: _createMockChildren('highSchoolAssistantCoordinator', level + 1),
          ),
        ]);
        break;
        
      case 'universityCoordinator':
        children.addAll([
          TreeNode(
            id: 'uni_asst_1', 
            name: 'University Assistant Coordinator', 
            role: 'universityAssistantCoordinator', 
            level: level,
            children: _createMockChildren('universityAssistantCoordinator', level + 1),
          ),
        ]);
        break;
        
      case 'housingCoordinator':
        children.addAll([
          TreeNode(
            id: 'housing_asst_1', 
            name: 'Housing Assistant Coordinator', 
            role: 'housingAssistantCoordinator', 
            level: level,
            children: _createMockChildren('housingAssistantCoordinator', level + 1),
          ),
        ]);
        break;
        
      case 'middleSchoolAssistantCoordinator':
        children.addAll([
          TreeNode(
            id: 'ms_mentor_1', 
            name: 'MS Mentor - Grade 6', 
            role: 'middleSchoolMentor', 
            level: level,
            children: _createMockChildren('middleSchoolMentor', level + 1),
          ),
          TreeNode(
            id: 'ms_mentor_2', 
            name: 'MS Mentor - Grade 7', 
            role: 'middleSchoolMentor', 
            level: level,
            children: _createMockChildren('middleSchoolMentor', level + 1),
          ),
          TreeNode(
            id: 'ms_mentor_3', 
            name: 'MS Mentor - Grade 8', 
            role: 'middleSchoolMentor', 
            level: level,
            children: _createMockChildren('middleSchoolMentor', level + 1),
          ),
        ]);
        break;
        
      case 'highSchoolAssistantCoordinator':
        children.addAll([
          TreeNode(
            id: 'hs_mentor_1', 
            name: 'HS Mentor - Grade 9', 
            role: 'highSchoolMentor', 
            level: level,
            children: _createMockChildren('highSchoolMentor', level + 1),
          ),
          TreeNode(
            id: 'hs_mentor_2', 
            name: 'HS Mentor - Grade 10', 
            role: 'highSchoolMentor', 
            level: level,
            children: _createMockChildren('highSchoolMentor', level + 1),
          ),
          TreeNode(
            id: 'hs_mentor_3', 
            name: 'HS Mentor - Grade 11', 
            role: 'highSchoolMentor', 
            level: level,
            children: _createMockChildren('highSchoolMentor', level + 1),
          ),
        ]);
        break;
        
      case 'universityAssistantCoordinator':
        children.addAll([
          TreeNode(
            id: 'student_house_leader_1', 
            name: 'Student House Leader A', 
            role: 'studentHouseLeader', 
            level: level,
            children: _createMockChildren('studentHouseLeader', level + 1),
          ),
          TreeNode(
            id: 'student_house_leader_2', 
            name: 'Student House Leader B', 
            role: 'studentHouseLeader', 
            level: level,
            children: _createMockChildren('studentHouseLeader', level + 1),
          ),
        ]);
        break;
        
      case 'housingAssistantCoordinator':
        children.addAll([
          TreeNode(
            id: 'house_leader_1', 
            name: 'House Leader - Building A', 
            role: 'houseLeader', 
            level: level,
            children: _createMockChildren('houseLeader', level + 1),
          ),
          TreeNode(
            id: 'house_leader_2', 
            name: 'House Leader - Building B', 
            role: 'houseLeader', 
            level: level,
            children: _createMockChildren('houseLeader', level + 1),
          ),
        ]);
        break;
        
      case 'middleSchoolMentor':
        children.addAll([
          TreeNode(id: 'ms_mentee_1', name: 'Ali Yılmaz', role: 'mentee', className: '6-A', isVirtual: true, level: level),
          TreeNode(id: 'ms_mentee_2', name: 'Ayşe Demir', role: 'mentee', className: '6-A', isVirtual: true, level: level),
          TreeNode(id: 'ms_mentee_3', name: 'Mehmet Kaya', role: 'mentee', className: '6-A', isVirtual: true, level: level),
          TreeNode(id: 'ms_mentee_4', name: 'Fatma Şahin', role: 'mentee', className: '6-A', isVirtual: true, level: level),
        ]);
        break;
        
      case 'highSchoolMentor':
        children.addAll([
          TreeNode(id: 'hs_mentee_1', name: 'Emre Özkan', role: 'mentee', className: '9-B', isVirtual: true, level: level),
          TreeNode(id: 'hs_mentee_2', name: 'Zeynep Aktaş', role: 'mentee', className: '9-B', isVirtual: true, level: level),
          TreeNode(id: 'hs_mentee_3', name: 'Burak Çelik', role: 'mentee', className: '9-B', isVirtual: true, level: level),
          TreeNode(id: 'hs_mentee_4', name: 'Selin Arslan', role: 'mentee', className: '9-B', isVirtual: true, level: level),
          TreeNode(id: 'hs_mentee_5', name: 'Oğuz Yıldız', role: 'mentee', className: '9-B', isVirtual: true, level: level),
        ]);
        break;
        
      case 'studentHouseLeader':
        children.addAll([
          TreeNode(id: 'student_member_1', name: 'Ahmet Karaca', role: 'studentHouseMember', roomNumber: 'A-101', level: level),
          TreeNode(id: 'student_member_2', name: 'Murat Doğan', role: 'studentHouseMember', roomNumber: 'A-102', level: level),
          TreeNode(id: 'student_member_3', name: 'Kemal Avcı', role: 'studentHouseMember', roomNumber: 'A-103', level: level),
          TreeNode(id: 'student_member_4', name: 'Hasan Polat', role: 'studentHouseMember', roomNumber: 'A-104', level: level),
        ]);
        break;
        
      case 'houseLeader':
        children.addAll([
          TreeNode(id: 'house_member_1', name: 'İbrahim Güler', role: 'houseMember', roomNumber: 'B-201', level: level),
          TreeNode(id: 'house_member_2', name: 'Mustafa Eren', role: 'houseMember', roomNumber: 'B-202', level: level),
          TreeNode(id: 'house_member_3', name: 'Yusuf Koç', role: 'houseMember', roomNumber: 'B-203', level: level),
          TreeNode(id: 'house_member_4', name: 'Abdullah Öz', role: 'houseMember', roomNumber: 'B-204', level: level),
        ]);
        break;
    }
    
    return children;
  }

  // 📐 Calculate node positions for freeform layout
  void _calculateNodePositions() {
    _nodePositions.clear();
    
    if (_rootNode == null) return;
    
    // Start with root at center-top of canvas
    final rootPosition = Offset(
      _canvasWidth / 2 - _rootNodeWidth / 2,
      200,
    );
    
    _nodePositions[_rootNode!.id] = TreeNodePosition(
      nodeId: _rootNode!.id,
      position: rootPosition,
      size: Size(_rootNodeWidth, _rootNodeHeight),
    );
    
    // Position children recursively
    _positionChildren(_rootNode!, rootPosition, 0);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _buildContent(),
        ),
      ),
    );
  }

  // 🎨 Build main content based on state
  Widget _buildContent() {
    if (_error != null) {
      return _buildErrorState();
    }
    
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    return _buildTreeView();
  }

  // ❌ Build error state
  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              color: Colors.red.shade300,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              _error == 'Access Denied' ? 'Access Denied' : 'Error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error == 'Access Denied' 
                  ? 'You don\'t have permission to view the User Tree.\n\nOnly management roles can access this feature.'
                  : _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 18),
                  SizedBox(width: 6),
                  Text('Go Back'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⏳ Build loading state
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Loading User Tree...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Building your organizational hierarchy',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // 🌳 Build tree view
  Widget _buildTreeView() {
    return Column(
      children: [
        // Header
        _buildHeader(),
        
        // Tree canvas
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.3,
            maxScale: 2.0,
            constrained: false,
                          child: SizedBox(
                width: _canvasWidth,
                height: _canvasHeight,
                child: Stack(
                  children: [
                    // Connection lines
                    AnimatedBuilder(
                      animation: _expandAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(_canvasWidth, _canvasHeight),
                          painter: TreeConnectionsPainter(
                            nodePositions: _nodePositions,
                            expandedNodes: _expandedNodes,
                            rootNode: _rootNode,
                            animation: _expandAnimation,
                          ),
                        );
                      },
                    ),
                    
                    // Tree nodes
                    ..._buildTreeNodes(),
                  ],
                ),
              ),
          ),
        ),
      ],
    );
  }

  // 📋 Build header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Tree',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Your organizational hierarchy',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Zoom controls
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final currentTransform = _transformationController.value;
                        final newScale = (currentTransform.getMaxScaleOnAxis() * 1.2).clamp(0.3, 2.0);
                        final newTransform = Matrix4.identity()..scale(newScale);
                        _transformationController.value = newTransform;
                      },
                      icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                      tooltip: 'Zoom In',
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final currentTransform = _transformationController.value;
                        final newScale = (currentTransform.getMaxScaleOnAxis() * 0.8).clamp(0.3, 2.0);
                        final newTransform = Matrix4.identity()..scale(newScale);
                        _transformationController.value = newTransform;
                      },
                      icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                      tooltip: 'Zoom Out',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Refresh button
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _loadTreeData();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                tooltip: 'Refresh Tree',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🌳 Build all tree nodes
  List<Widget> _buildTreeNodes() {
    List<Widget> nodes = [];
    
    if (_rootNode != null) {
      nodes.addAll(_buildNodesRecursively(_rootNode!));
    }
    
    return nodes;
  }

  // 🌳 Build nodes recursively with viewport culling
  List<Widget> _buildNodesRecursively(TreeNode node) {
    List<Widget> nodes = [];
    
    // Only render if visible (performance optimization)
    if (_visibleNodes.contains(node.id)) {
      final position = _nodePositions[node.id];
      if (position != null) {
        nodes.add(_buildNodeWidget(node, position));
      }
    }
    
    // Add children if expanded
    if (_expandedNodes.contains(node.id)) {
      for (final child in node.children) {
        nodes.addAll(_buildNodesRecursively(child));
      }
    }
    
    return nodes;
  }

  // 🎨 Build individual node widget
  Widget _buildNodeWidget(TreeNode node, TreeNodePosition position) {
    final isRoot = node.level == 0;
    final isExpanded = _expandedNodes.contains(node.id);
    
    return Positioned(
      left: position.position.dx,
      top: position.position.dy,
      child: GestureDetector(
        onTap: () => _toggleNode(node),
        onDoubleTap: () => _centerOnNode(position.position),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: position.size.width,
          height: position.size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getNodeColors(node, isRoot),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: isExpanded 
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          child: _buildNodeContent(node, isRoot, isExpanded),
        ),
      ),
    );
  }

  // 🎨 Get node colors based on role and type
  List<Color> _getNodeColors(TreeNode node, bool isRoot) {
    if (isRoot) {
      return [Colors.purple.shade400, Colors.purple.shade600];
    }
    
    // Virtual mentees - special purple/indigo gradient
    if (node.isVirtual && node.role == 'mentee') {
      return [
        Colors.purple.withOpacity(0.8),
        Colors.indigo.withOpacity(0.6),
      ];
    }
    
    // Other virtual users - green tones
    if (node.isVirtual) {
      return [Colors.green.shade300, Colors.green.shade500];
    }
    
    switch (node.role) {
      case 'director':
        return [Colors.red.shade300, Colors.red.shade500];
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator':
      case 'universityCoordinator':
      case 'housingCoordinator':
        return [Colors.blue.shade300, Colors.blue.shade500];
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator':
      case 'universityAssistantCoordinator':
      case 'housingAssistantCoordinator':
        return [Colors.cyan.shade300, Colors.cyan.shade500];
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
        return [Colors.orange.shade300, Colors.orange.shade500];
      case 'houseLeader':
      case 'studentHouseLeader':
        return [Colors.teal.shade300, Colors.teal.shade500];
      case 'houseMember':
      case 'studentHouseMember':
        return [Colors.indigo.shade300, Colors.indigo.shade500];
      default:
        return [Colors.grey.shade300, Colors.grey.shade500];
    }
  }

  // 🎨 Build node content
  Widget _buildNodeContent(TreeNode node, bool isRoot, bool isExpanded) {
    return Stack(
      children: [
        // Main content
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name with virtual styling
              Text(
                node.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isRoot ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  fontStyle: node.isVirtual ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              // Role with virtual indicator
              Row(
                children: [
                  if (node.isVirtual && node.role == 'mentee') ...[
                    Icon(
                      Icons.computer,
                      color: Colors.orange,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      node.isVirtual && node.role == 'mentee' 
                        ? 'Virtual ${_getRoleTitle(node.role)}'
                        : _getRoleTitle(node.role),
                      style: TextStyle(
                        color: node.isVirtual && node.role == 'mentee'
                          ? Colors.orange.withOpacity(0.9)
                          : Colors.white70,
                        fontSize: isRoot ? 12 : 10,
                        fontWeight: node.isVirtual ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // Additional info
              if (node.className != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Class: ${node.className}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                  ),
                ),
              ],
              
              if (!isRoot && !node.isVirtual) ...[
                const SizedBox(height: 2),
                Text(
                  '${node.children.length} subordinates',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Expansion indicator
        if (node.hasChildren)
          Positioned(
            right: 8,
            top: 8,
            child: AnimatedRotation(
              turns: isExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: isRoot ? 18 : 16,
              ),
            ),
          ),
          
        // Special indicators
        if (isRoot)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Sen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
        if (node.isVirtual)
          Positioned(
            left: 8,
            top: 8,
            child: Icon(
              Icons.school,
              color: Colors.white.withOpacity(0.7),
              size: 14,
            ),
          ),
      ],
    );
  }

  // 🎨 Get role title
  String _getRoleTitle(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'moderator': return 'Moderator';
      case 'director': return 'Director';
      case 'middleSchoolCoordinator': return 'Middle School Coordinator';
      case 'highSchoolCoordinator': return 'High School Coordinator';
      case 'universityCoordinator': return 'University Coordinator';
      case 'housingCoordinator': return 'Housing Coordinator';
      case 'middleSchoolAssistantCoordinator': return 'MS Assistant Coordinator';
      case 'highSchoolAssistantCoordinator': return 'HS Assistant Coordinator';
      case 'universityAssistantCoordinator': return 'University Assistant Coordinator';
      case 'housingAssistantCoordinator': return 'Housing Assistant Coordinator';
      case 'middleSchoolMentor': return 'Middle School Mentor';
      case 'highSchoolMentor': return 'High School Mentor';
      case 'houseLeader': return 'House Leader';
      case 'studentHouseLeader': return 'Student House Leader';
      case 'houseMember': return 'House Member';
      case 'studentHouseMember': return 'Student House Member';
      case 'mentee': return 'Mentee';
      case 'accountant': return 'Accountant';
      default: return role;
    }
  }

  // 🎮 Toggle node expansion with animation
  void _toggleNode(TreeNode node) {
    if (!node.hasChildren) {
      // Gentle feedback for leaf nodes
      HapticFeedback.selectionClick();
      return;
    }
    
    // Enhanced haptic feedback based on action
    final isExpanding = !_expandedNodes.contains(node.id);
    if (isExpanding) {
      HapticFeedback.lightImpact(); // Light for expand
    } else {
      HapticFeedback.mediumImpact(); // Medium for collapse
    }
    
    // Start expand animation
    _animationController.forward(from: 0);
    
    setState(() {
      if (_expandedNodes.contains(node.id)) {
        _expandedNodes.remove(node.id);
        // Also collapse all children
        _collapseAllChildren(node);
      } else {
        _expandedNodes.add(node.id);
      }
      
      // Recalculate positions and visible nodes
      _calculateNodePositions();
      
      // Update visible nodes after a brief delay for smooth animation
      Future.delayed(const Duration(milliseconds: 100), () {
        _updateVisibleNodes();
      });
    });
  }

  // 🎮 Collapse all children recursively
  void _collapseAllChildren(TreeNode node) {
    for (final child in node.children) {
      _expandedNodes.remove(child.id);
      _collapseAllChildren(child);
    }
  }

  // 🎮 Center camera on node with smooth animation
  void _centerOnNode(Offset nodePosition) {
    final screenSize = MediaQuery.of(context).size;
    final currentTransform = _transformationController.value;
    final targetTransform = Matrix4.identity()
      ..translate(
        screenSize.width / 2 - nodePosition.dx - _childNodeWidth / 2,
        screenSize.height / 2 - nodePosition.dy - _childNodeHeight / 2,
      )
      ..scale(1.2);
    
    // Animate camera movement
    final tween = Matrix4Tween(begin: currentTransform, end: targetTransform);
    final animation = tween.animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    
    _animationController.forward(from: 0).then((_) {
      animation.addListener(() {
        _transformationController.value = animation.value;
      });
    });
    
    HapticFeedback.mediumImpact();
  }

  // 🎨 Enhanced node positioning with better spacing
  void _positionChildren(TreeNode parent, Offset parentPosition, int level) {
    if (!_expandedNodes.contains(parent.id) || parent.children.isEmpty) {
      return;
    }
    
    final childCount = parent.children.length;
    
    // Dynamic spacing based on level and child count
    final horizontalSpacing = math.max(200, _horizontalSpacing - (level * 30));
    final verticalSpacing = _verticalSpacing + (level * 20);
    
    final totalWidth = (childCount - 1) * horizontalSpacing;
    final startX = parentPosition.dx + (_rootNodeWidth / 2) - (totalWidth / 2);
    final childY = parentPosition.dy + verticalSpacing;
    
    // Add some randomness for organic feel (but deterministic)
    final random = math.Random(parent.id.hashCode);
    
    for (int i = 0; i < childCount; i++) {
      final child = parent.children[i];
      
      // Base position
      final baseX = startX + (i * horizontalSpacing) - (_childNodeWidth / 2);
      
      // Add slight organic offset
      final organicOffset = (random.nextDouble() - 0.5) * 30;
      final childX = baseX + organicOffset;
      
      final childPosition = Offset(childX, childY);
      
      _nodePositions[child.id] = TreeNodePosition(
        nodeId: child.id,
        position: childPosition,
        size: Size(_childNodeWidth, _childNodeHeight),
      );
      
      // Recursively position grandchildren
      _positionChildren(child, childPosition, level + 1);
    }
  }


}
